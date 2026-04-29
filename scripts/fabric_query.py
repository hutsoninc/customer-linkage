"""
fabric_query.py — Run T-SQL queries against the Fabric SQL Analytics endpoint.

Usage:
    python fabric_query.py "SELECT COUNT(*) FROM Equip.contact"
    python fabric_query.py --file my_query.sql
    python fabric_query.py "SELECT ..." --block 6a        # saves to input/test-results/block-6a-results.tsv
    python fabric_query.py "SELECT ..." --out results.tsv
    echo "SELECT 1" | python fabric_query.py

Config (set in .env at the project root):
    FABRIC_SERVER    e.g. abc123.sql.fabric.microsoft.com
    FABRIC_DATABASE  e.g. MyLakehouse

Authentication uses your existing Azure CLI session (az login).
"""

import os
import sys
import struct
import argparse
import csv
import io
from datetime import datetime
from pathlib import Path


ROOT = Path(__file__).parent.parent
ENV_FILE = ROOT / ".env"
RESULTS_DIR = ROOT / "results"


def load_env():
    if ENV_FILE.exists():
        for line in ENV_FILE.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip())


def get_connection():
    import pyodbc
    from azure.identity import DefaultAzureCredential

    server = os.environ.get("FABRIC_SERVER")
    database = os.environ.get("FABRIC_DATABASE")

    if not server or not database:
        sys.exit(
            "Error: FABRIC_SERVER and FABRIC_DATABASE must be set in .env or environment.\n"
            f"Expected .env at: {ENV_FILE}\n"
            "Example:\n  FABRIC_SERVER=abc123.sql.fabric.microsoft.com\n  FABRIC_DATABASE=MyLakehouse"
        )

    credential = DefaultAzureCredential()
    token = credential.get_token("https://database.windows.net/.default")
    token_bytes = token.token.encode("UTF-16-LE")
    token_struct = struct.pack(f"<I{len(token_bytes)}s", len(token_bytes), token_bytes)

    conn_str = (
        f"DRIVER={{ODBC Driver 18 for SQL Server}};"
        f"SERVER={server},1433;"
        f"DATABASE={database};"
        f"Encrypt=yes;TrustServerCertificate=no;"
    )

    return pyodbc.connect(conn_str, attrs_before={1256: token_struct})


def run_query(query: str, out_path: Path | None = None, null_as_empty: bool = False):
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute(query)

    if cursor.description is None:
        msg = "Query executed successfully (no rows returned)."
        print(msg, file=sys.stderr)
        return

    columns = [col[0] for col in cursor.description]
    rows = cursor.fetchall()

    null_str = "" if null_as_empty else "NULL"
    # Use CSV for named output files, TSV for stdout / block results
    is_csv = out_path is not None and out_path.suffix.lower() == ".csv"
    delimiter = "," if is_csv else "\t"

    buf = io.StringIO()
    writer = csv.writer(buf, delimiter=delimiter, lineterminator="\n")
    writer.writerow(columns)
    for row in rows:
        writer.writerow([null_str if v is None else str(v) for v in row])

    output = buf.getvalue()

    if out_path:
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(output, encoding="utf-8")
        print(f"Saved {len(rows)} row(s) to {out_path}", file=sys.stderr)
    else:
        sys.stdout.write(output)
        print(f"\n-- {len(rows)} row(s)", file=sys.stderr)


def main():
    load_env()

    parser = argparse.ArgumentParser(description="Run T-SQL against Fabric SQL Analytics endpoint")
    parser.add_argument("query", nargs="?", help="SQL query string")
    parser.add_argument("--file", "-f", help="Path to a .sql file")
    parser.add_argument("--out", "-o", help="Output file path")
    parser.add_argument(
        "--block", "-b",
        help="Block name (e.g. 6a) — saves to results/block-<name>-results.tsv"
    )
    parser.add_argument(
        "--null-as-empty", action="store_true",
        help="Output empty string instead of NULL for null values (use for upload files)"
    )
    parser.add_argument(
        "--timestamp", action="store_true",
        help="Append YYYYMMDD-HHMMSS to the output filename (e.g. phase1b-20260429-143022.csv)"
    )
    args = parser.parse_args()

    if args.file:
        query = Path(args.file).read_text(encoding="utf-8")
    elif args.query:
        query = args.query
    elif not sys.stdin.isatty():
        query = sys.stdin.read()
    else:
        parser.print_help()
        sys.exit(1)

    if args.block:
        out_path = RESULTS_DIR / f"block-{args.block}-results.csv"
    elif args.out:
        out_path = Path(args.out)
    else:
        out_path = None

    if out_path and args.timestamp:
        ts = datetime.now().strftime("%Y%m%d-%H%M%S")
        suffix = f"-{ts}"
        ext = out_path.suffix
        max_stem = 50 - len(suffix) - len(ext)
        stem = out_path.stem[:max_stem]
        out_path = out_path.with_name(f"{stem}{suffix}{ext}")

    run_query(query, out_path, null_as_empty=args.null_as_empty)


if __name__ == "__main__":
    main()
