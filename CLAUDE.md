# Customer Linkage Project

Formal linkage between EQUIP (dealer DBS) contacts and John Deere's Customer Registry (IKC/CKC). DBS number appears in CSC membership column across JD sales tools. Secondary goals: EQUIP data quality, SF Prospect merges, EQUIP deduplication.

## Key Docs

| File | Purpose |
|---|---|
| `docs/data-model.md` | ERD, table relationships, field semantics |
| `docs/data-quality-plan.md` | Data quality reporting plan — metrics, snapshot architecture, Power BI structure, open questions |
| `docs/dq-review-notes.md` | Metric-by-metric review notes and follow-up actions from Power BI DQ report |
| `docs/dataset-equip-contact.md` | Equip.contact column reference + upload template mapping |
| `docs/linkage-progress.md` | Batch log — update after every accepted upload |
| `docs/project-plan.md` | Phase order of operations, open questions |
| `docs/query-conventions.md` | Full SQL patterns with examples (UPPER join, country, employee exclusion, B/I/C logic) |
| `docs/research-findings.md` | All query blocks, results, findings |
| `docs/source-materials-summary.md` | Consolidated Deere reference documents |

## Directory Structure

```
queries/
  research/        block-1a through block-6i (exploratory)
  phase-1/         production queries (block-5e, block-7a/b/c/d)
  data-quality/    data quality snapshots (run on demand or scheduled)
    dq-completeness.sql          field fill rates across all contacts
    dq-field-quality.sql         free-text field anomalies (length, case, garbage)
    dq-field-quality-coded-fields.sql  coded field validity (state, country, B/I/C, etc.)
    dq-linkage-quality.sql       linkage health — mismatches, sentinels, stale CKC IDs
    dq-match-readiness.sql       unlinked contacts scored for match readiness
    dq-registry-parity.sql       EQUIP vs Registry divergence (linked contacts only)
    dq-staleness.sql             contacts with stale or missing last-activity dates
  tracking.sql     linkage progress query — run after each batch
results/           CSV query results (gitignored, regenerable)
uploads/           import files for Customer Linkage Tool
scripts/
  fabric_query.py             run T-SQL against Fabric
  reconcile_tight_matches.py  compare tight match results vs Salesforce
  split_reconciliation.py     split reconciliation into agree/disagree Path A files
  parse_input_files.py        extract text from PDF/PPTX/DOCX
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

## Data Model (5 tables, 3 systems)

| Table | System | Key Columns |
|---|---|---|
| `Equip.contact` | EQUIP | `contact_code` PK, `Business_Individual` B/I/C, `Ckc_Id`, `Cmp_Ckc_Id` |
| `Equip.ArMaster` | EQUIP | `ACC_NO` PK (= Salesforce `Anvil__AccountNumber__c`), `contact_code` FK (nullable) — financial master: balances, credit, aging |
| `Equip.ArMaster_Customer` | EQUIP | `contact_code` FK NOT NULL, `BILL_TO_ACC` → ArMaster.ACC_NO, `Customer_No` alt ref, `TERRITORY` branch — 1:1 with contact |
| `Equip.WKMECHFL` | EQUIP | `Code` = contact_code (technicians) — exclude from uploads |
| `Equip.VhSalman` | EQUIP | `CODE` = contact_code (salespersons) — exclude from uploads |
| `DDP.customer_cross_ref` | Registry | `cross_ref_number` (ALL CAPS = contact_code), `entity_id`, `contact_id`, `cross_ref_created_ts` |
| `DDP.customer_profile` | Registry | `entity_id`, `contact_id`, `out_of_busn_ind`, `descd_ind` |
| `Salesforce.Account` | Salesforce | `Anvil__AccountNumber__c` (= ArMaster.ACC_NO), `Anvil__CustomerCompEntityID__c`, `H_Equip_contact_Ckc_Id__c` |

**Ckc_Id semantics:** B/I → own Entity ID. C → parent Business Entity ID; `Cmp_Ckc_Id` = own Contact ID.  
**SF precedence:** `H_Equip_contact_Ckc_Id__c` (EQUIP formal) overwrites `Anvil__CustomerCompEntityID__c` (quote workflow).

## Progress Tracking

- **Baseline:** 58,336 linkages as of 2026-04-29
- Run `queries/tracking.sql` after each batch; log results in `docs/linkage-progress.md`
- ~40–100 background linkages/day from normal EQUIP workflow — not project-attributed

<!-- pbi-cli:start -->
# Power BI CLI (pbi-cli)

When working with Power BI, DAX, semantic models, or data modeling,
invoke the relevant pbi-cli skill before responding:

**Semantic Model (requires `pbi connect`):**
- **power-bi-dax** -- DAX queries, measures, calculations
- **power-bi-modeling** -- tables, columns, measures, relationships
- **power-bi-deployment** -- TMDL export/import, transactions, diff
- **power-bi-docs** -- model documentation, data dictionary
- **power-bi-partitions** -- partitions, M expressions, data sources
- **power-bi-security** -- RLS roles, perspectives, access control
- **power-bi-diagnostics** -- troubleshooting, tracing, setup

**Report Layer (no connection needed):**
- **power-bi-report** -- scaffold, validate, preview PBIR reports
- **power-bi-visuals** -- add, bind, update, bulk-manage visuals
- **power-bi-pages** -- pages, bookmarks, visibility, drillthrough
- **power-bi-themes** -- themes, conditional formatting, styling
- **power-bi-filters** -- page and visual filters (TopN, date, categorical)
- **power-bi-custom-visuals** -- vibe-code .pbiviz custom visuals 
(TS scaffold, tsc loop, package, import)

Critical: Multi-line DAX (VAR/RETURN) cannot be passed via `-e`.
Use `--file` or stdin piping instead. See power-bi-dax skill.
<!-- pbi-cli:end -->