# Customer Linkage

Tools and queries for formally linking EQUIP dealer contacts to John Deere's Customer Registry (IKC/CKC). A formal linkage causes the DBS number to appear in the CSC membership column across JD sales tools (JDQuote2, JDMint, Sales Center, Rewards, Warranty Portal) and enables correct entity routing in quotes and downstream data flows.

## Prerequisites

- Python 3.11+
- [ODBC Driver 18 for SQL Server](https://learn.microsoft.com/en-us/sql/connect/odbc/download-odbc-driver-for-sql-server)
- Azure CLI (`az login` must be current before running any query scripts)

```bash
pip install -r requirements.txt
```

## Configuration

Create a `.env` file in the project root (already in `.gitignore`):

```
FABRIC_SERVER=<your-server>.sql.fabric.microsoft.com
FABRIC_DATABASE=<your-lakehouse-name>
```

## Running Queries

```bash
# Research query → results/block-7d-results.csv
python scripts/fabric_query.py --file queries/phase-1/block-7d.sql --block 7d

# Inline query
python scripts/fabric_query.py "SELECT COUNT(*) FROM Equip.contact"

# Upload file — always use --null-as-empty and --timestamp
python scripts/fabric_query.py --file queries/phase-1/block-7a.sql --out uploads/phase1b.csv --null-as-empty --timestamp
```

`--timestamp` appends `YYYYMMDD-HHMMSS` to the filename and auto-truncates the stem so the total filename stays within the Customer Linkage Tool's 50-character limit.

## Scripts

| Script | Purpose |
|---|---|
| `scripts/fabric_query.py` | Run T-SQL against the Fabric SQL Analytics endpoint |
| `scripts/reconcile_tight_matches.py` | Compare tight match Excel results vs. Salesforce entity IDs |
| `scripts/split_reconciliation.py` | Split reconciliation output into AGREE/DISAGREE Path A upload files |
| `scripts/parse_input_files.py` | Extract text from PDF, PPTX, and DOCX source materials |

### Reconcile tight matches

```bash
python scripts/reconcile_tight_matches.py results/Tight\ Match-phase1b.xlsx --out uploads/phase1b-reconciliation.csv
```

Outputs a CSV with columns `DBS Customer Number`, `Tight Match Entity ID`, `Tight Match Contact ID`, `SF Anvil Entity ID`, `Status` (AGREE / DISAGREE / SF_MISSING).

### Split into upload files

```bash
python scripts/split_reconciliation.py uploads/phase1b-reconciliation.csv --exclude-employees
```

Produces `uploads/agree-YYYYMMDD-HHMMSS.csv` and `uploads/disagree-YYYYMMDD-HHMMSS.csv` formatted for the Customer Linkage Tool's Path A (Create DBS Linkage). `--exclude-employees` queries Fabric to remove service technicians and salespersons from the output.

## Directory Structure

```
queries/
  research/        Exploratory blocks (block-1a through block-6i)
  phase-1/         Production queries (block-5e, block-7a/b/c/d)
  tracking.sql     Current linkage totals — run after each accepted batch
results/           CSV query results (gitignored — regenerable from queries)
uploads/           Import files for the Customer Linkage Tool (gitignored)
scripts/           Python utilities (see above)
docs/              Project documentation
source-materials/  Reference documents and templates from Deere
```

## Key Docs

| File | Purpose |
|---|---|
| `docs/project-plan.md` | Phase order of operations and open decisions |
| `docs/query-conventions.md` | Standing SQL rules with full examples |
| `docs/linkage-progress.md` | Batch log — updated after each accepted upload |
| `docs/research-findings.md` | All query blocks, results, and analysis notes |
| `docs/data-model.md` | ERD and field semantics for the five key tables |
| `docs/dataset-equip-contact.md` | `Equip.contact` column reference and upload template mapping |

## Critical Query Rules

Full patterns in `docs/query-conventions.md`. Short form:

1. **cross_ref join** — always `UPPER()` both sides (`cross_ref_number` is ALL CAPS; Fabric collation is case-sensitive)
2. **Employee exclusion** — LEFT JOIN `Equip.WKMECHFL` + `Equip.VhSalman`, filter `IS NULL` on both
3. **Country code** — `ISNULL(NULLIF(LTRIM(RTRIM(c.country)), ''), 'US')` — handles empty string and NULL
4. **Inactive filter** — `ISNULL(c.Inactive_Indicator, 'A') <> 'I'`
5. **Sentinel entity ID** — exclude `Ckc_Id = 999999998`
6. **Deceased / OOB** — join `DDP.customer_profile` on `entity_id` + `contact_id = 0`; check `descd_ind` and `out_of_busn_ind` before accepting tight match batches

## Progress Tracking

Baseline: **58,336 linkages** as of 2026-04-29.

```bash
python scripts/fabric_query.py --file queries/tracking.sql
```

Log each accepted batch in `docs/linkage-progress.md`. Background EQUIP workflow creates ~40–100 linkages/day that are not project-attributed.
