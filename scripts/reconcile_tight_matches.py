"""
reconcile_tight_matches.py — Compare Phase 1.2 tight match results against Salesforce entity IDs.

For each tight match returned by the Customer Linkage Tool, checks whether the matched entity ID
agrees with the Anvil entity ID already stored in Salesforce (Anvil__CustomerCompEntityID__c).

Outcomes:
  AGREE       - Tight match entity ID matches Salesforce → safe to accept linkage
  DISAGREE    - Tight match entity ID differs from Salesforce → investigate before linking
  SF_MISSING  - DBS number not found in Salesforce query (should not happen for this population)

Usage:
    python scripts/reconcile_tight_matches.py results/Tight*.xlsx
    python scripts/reconcile_tight_matches.py results/Tight*.xlsx --out uploads/phase1b-reconciliation.csv
"""

import sys
import os
import struct
import argparse
import csv
import io
from pathlib import Path

try:
    import openpyxl
except ImportError:
    sys.exit("openpyxl is required: pip install openpyxl")

ROOT = Path(__file__).parent.parent
ENV_FILE = ROOT / ".env"
RESULTS_DIR = ROOT / "results"

SF_QUERY = """
SELECT
    c.contact_code                          AS dbs_number,
    sf.Anvil__CustomerCompEntityID__c       AS sf_entity_id
FROM Salesforce.Account sf
JOIN Equip.ArMaster ar
    ON ar.ACC_NO = sf.Anvil__AccountNumber__c
JOIN Equip.contact c
    ON c.contact_code = ar.contact_code
WHERE sf.RecordTypeId = '0124W000001aGwlQAE'
  AND sf.Anvil__CustomerCompEntityID__c IS NOT NULL
  AND sf.H_Equip_contact_Ckc_Id__c IS NULL
  AND ISNULL(c.Inactive_Indicator, 'A') <> 'I'
"""


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


def load_tight_matches(xlsx_paths):
    """Read one or more tight match Excel files, return list of (dbs, entity_id, contact_id)."""
    rows = []
    for path in xlsx_paths:
        wb = openpyxl.load_workbook(path)
        ws = wb.active
        for row in ws.iter_rows(min_row=2, values_only=True):
            dbs, entity_id, contact_id = row[0], str(row[1]), str(row[2])
            rows.append((dbs, entity_id, contact_id))
    return rows


def fetch_sf_entity_ids(conn):
    """Query Fabric for SF entity IDs for the Phase 1.2 population."""
    cursor = conn.cursor()
    cursor.execute(SF_QUERY)
    # Store as dict: contact_code (upper) → sf_entity_id
    return {row[0].upper(): str(row[1]) for row in cursor.fetchall()}


def reconcile(tight_matches, sf_map):
    results = []
    for dbs, tm_entity, tm_contact in tight_matches:
        sf_entity = sf_map.get(dbs.upper())
        if sf_entity is None:
            status = "SF_MISSING"
        elif tm_entity == sf_entity:
            status = "AGREE"
        else:
            status = "DISAGREE"
        results.append({
            "DBS Customer Number": dbs,
            "Tight Match Entity ID": tm_entity,
            "Tight Match Contact ID": tm_contact,
            "SF Anvil Entity ID": sf_entity or "",
            "Status": status,
        })
    return results


def write_output(results, out_path=None):
    fieldnames = [
        "DBS Customer Number",
        "Tight Match Entity ID",
        "Tight Match Contact ID",
        "SF Anvil Entity ID",
        "Status",
    ]
    buf = io.StringIO()
    writer = csv.DictWriter(buf, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(results)
    output = buf.getvalue()

    if out_path:
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(output, encoding="utf-8")
        print(f"Saved {len(results)} row(s) to {out_path}", file=sys.stderr)
    else:
        sys.stdout.write(output)

    # Always print summary to stderr
    from collections import Counter
    counts = Counter(r["Status"] for r in results)
    print(f"\nSummary:", file=sys.stderr)
    for status in ("AGREE", "DISAGREE", "SF_MISSING"):
        print(f"  {status}: {counts.get(status, 0)}", file=sys.stderr)


def main():
    load_env()

    parser = argparse.ArgumentParser(description="Reconcile tight match results vs Salesforce entity IDs")
    parser.add_argument("files", nargs="+", help="Tight Match Excel file(s) from Customer Linkage Tool")
    parser.add_argument("--out", "-o", help="Output CSV path (default: stdout)")
    args = parser.parse_args()

    xlsx_paths = [Path(f) for f in args.files]
    for p in xlsx_paths:
        if not p.exists():
            sys.exit(f"File not found: {p}")

    print(f"Loading tight match files...", file=sys.stderr)
    tight_matches = load_tight_matches(xlsx_paths)
    print(f"  {len(tight_matches)} tight matches across {len(xlsx_paths)} file(s)", file=sys.stderr)

    print(f"Querying Salesforce entity IDs from Fabric...", file=sys.stderr)
    conn = get_connection()
    sf_map = fetch_sf_entity_ids(conn)
    print(f"  {len(sf_map)} SF records loaded", file=sys.stderr)

    results = reconcile(tight_matches, sf_map)

    out_path = Path(args.out) if args.out else None
    write_output(results, out_path)


if __name__ == "__main__":
    main()
