# Customer Linkage Project

Formal linkage between EQUIP (dealer DBS) contacts and John Deere's Customer Registry (CKC). DBS number appears in CSC membership column across JD sales tools. Secondary goals: EQUIP data quality, SF Prospect merges, EQUIP deduplication.

## Key Docs

| File | Purpose |
|---|---|
| `docs/data-model.md` | ERD, table relationships, field semantics |
| `docs/data-quality-plan.md` | Data quality reporting plan — metrics, snapshot architecture, Power BI structure, open questions |
| `docs/dq-review-notes.md` | Metric-by-metric review notes and follow-up actions from Power BI DQ report |
| `docs/dataset-equip-contact.md` | Equip.contact column reference + upload template mapping |
| `docs/update-log.md` | Update log — bulk data changes and linkage uploads with dates and records affected |
| `docs/project-plan.md` | Phase order of operations, open questions |
| `docs/query-conventions.md` | Full SQL patterns with examples (UPPER join, country, employee exclusion, B/I/C logic) |
| `docs/research-findings.md` | All query blocks, results, findings |
| `docs/source-materials-summary.md` | Consolidated Deere reference documents |

## Directory Structure

```
queries/
  research/        exploratory queries
  phase-1/         production queries
  data-quality/    data quality snapshots
  tracking.sql     linkage progress query
results/           CSV query results (gitignored, regenerable)
uploads/           import files for Customer Linkage Tool
scripts/
  fabric_query.py             run T-SQL against Fabric
```

## Running Queries

```bash
# Research result → results/block-7e-results.csv
python scripts/fabric_query.py --file queries/phase-1/block-7e.sql --block 7e

# Inline query
python scripts/fabric_query.py "SELECT COUNT(*) FROM Equip.contact"

# Upload file — always use --null-as-empty and --timestamp
# --timestamp appends YYYYMMDD-HHMMSS; auto-truncates stem to keep filename ≤50 chars
python scripts/fabric_query.py --file queries/phase-1/block-7a.sql --out uploads/phase1b.csv --null-as-empty --timestamp
```

## CRITICAL Query Rules

Full patterns with examples in `docs/query-conventions.md`. Summary:

1. **cross_ref join** — always `UPPER()` both sides (`cross_ref_number` is ALL CAPS, collation is case-sensitive)
2. **Employee exclusion** — LEFT JOIN `Equip.WKMECHFL` + `Equip.VhSalman`, filter `IS NULL` on both
3. **Country code** — `ISNULL(NULLIF(LTRIM(RTRIM(c.country)), ''), 'US')` (handles empty string AND null)
4. **Inactive filter** — `ISNULL(c.Inactive_Indicator, 'A') <> 'I'`
5. **Sentinel entity ID** — exclude `Ckc_Id = 999999998`
6. **customer_profile filter** — always add `AND cp.cross_ref_description = 'HUTSON INC Dealer XREF'` to every `DDP.customer_profile` join (new as of 2026-05-01; EDA rows cause fan-out without this)
