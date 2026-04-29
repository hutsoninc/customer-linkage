"""
split_reconciliation.py — Split a reconciliation CSV into agree/disagree Path A upload files.

Reads the output of reconcile_tight_matches.py and produces two Path A (Create DBS Linkage)
formatted CSVs: one for AGREE records (tight match = Salesforce), one for DISAGREE.
Employee contacts (from WKMECHFL / VhSalman) are excluded via an optional --exclude-employees flag
that queries Fabric, or you can supply a pre-built exclusion list as a text file.

Usage:
    python scripts/split_reconciliation.py uploads/phase1b-reconciliation.csv
    python scripts/split_reconciliation.py uploads/phase1b-reconciliation.csv --exclude-employees
    python scripts/split_reconciliation.py uploads/phase1b-reconciliation.csv --exclude-file results/employees.txt
"""

import sys
import os
import struct
import argparse
import csv
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).parent.parent
ENV_FILE = ROOT / ".env"
UPLOADS_DIR = ROOT / "uploads"

EMPLOYEE_QUERY = """
SELECT DISTINCT c.contact_code
FROM Equip.contact c
WHERE EXISTS (SELECT 1 FROM Equip.WKMECHFL m WHERE m.Code = c.contact_code)
   OR EXISTS (SELECT 1 FROM Equip.VhSalman s WHERE s.CODE = c.contact_code)
"""


def load_env():
    if ENV_FILE.exists():
        for line in ENV_FILE.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip())


def fetch_employee_codes():
    import pyodbc
    from azure.identity import DefaultAzureCredential
    server = os.environ.get("FABRIC_SERVER")
    database = os.environ.get("FABRIC_DATABASE")
    credential = DefaultAzureCredential()
    token = credential.get_token("https://database.windows.net/.default")
    token_bytes = token.token.encode("UTF-16-LE")
    token_struct = struct.pack(f"<I{len(token_bytes)}s", len(token_bytes), token_bytes)
    conn_str = (
        f"DRIVER={{ODBC Driver 18 for SQL Server}};"
        f"SERVER={server},1433;DATABASE={database};"
        f"Encrypt=yes;TrustServerCertificate=no;"
    )
    conn = pyodbc.connect(conn_str, attrs_before={1256: token_struct})
    cursor = conn.cursor()
    cursor.execute(EMPLOYEE_QUERY)
    return {row[0].upper() for row in cursor.fetchall()}


def write_path_a(rows, stem, ts):
    max_stem = 50 - len(f"-{ts}") - len(".csv")
    stem = stem[:max_stem]
    path = UPLOADS_DIR / f"{stem}-{ts}.csv"
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["DBS Number", "Entity Id", "Contact Id"])
        for r in rows:
            contact_id = r["Tight Match Contact ID"] if r["Tight Match Contact ID"] != "0" else ""
            w.writerow([r["DBS Customer Number"], r["Tight Match Entity ID"], contact_id])
    return path


def main():
    load_env()

    parser = argparse.ArgumentParser(description="Split reconciliation CSV into agree/disagree Path A files")
    parser.add_argument("reconciliation_csv", help="Output from reconcile_tight_matches.py")
    parser.add_argument("--exclude-employees", action="store_true", help="Query Fabric to exclude employee contacts")
    parser.add_argument("--exclude-file", help="Text file with one employee contact_code per line")
    args = parser.parse_args()

    rows = list(csv.DictReader(open(args.reconciliation_csv, encoding="utf-8")))
    print(f"Loaded {len(rows)} rows from {args.reconciliation_csv}", file=sys.stderr)

    excluded = set()
    if args.exclude_employees:
        print("Fetching employee codes from Fabric...", file=sys.stderr)
        excluded = fetch_employee_codes()
        print(f"  {len(excluded)} employee codes loaded", file=sys.stderr)
    elif args.exclude_file:
        excluded = {line.strip().upper() for line in open(args.exclude_file) if line.strip()}
        print(f"  {len(excluded)} exclusion codes loaded from {args.exclude_file}", file=sys.stderr)

    agree    = [r for r in rows if r["Status"] == "AGREE"    and r["DBS Customer Number"].upper() not in excluded]
    disagree = [r for r in rows if r["Status"] == "DISAGREE" and r["DBS Customer Number"].upper() not in excluded]

    if excluded:
        skipped = len([r for r in rows if r["DBS Customer Number"].upper() in excluded])
        print(f"  Excluded {skipped} employee record(s)", file=sys.stderr)

    ts = datetime.now().strftime("%Y%m%d-%H%M%S")
    agree_path    = write_path_a(agree,    "agree",    ts)
    disagree_path = write_path_a(disagree, "disagree", ts)

    print(f"AGREE:    {len(agree):5d} rows → {agree_path}", file=sys.stderr)
    print(f"DISAGREE: {len(disagree):5d} rows → {disagree_path}", file=sys.stderr)


if __name__ == "__main__":
    main()
