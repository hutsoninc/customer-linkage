# Phase 0 — Data Quality Reporting Baseline

**Status:** ✅ Complete (2026-05-15)  
**Effort:** Medium | **Risk:** Low | **Dependency:** None

**Goal:** Establish a weekly snapshot pipeline and Power BI report to track data quality trends, surface cleanup targets, and provide a measurable before/after baseline for all cleanup phases.

---

## What Was Built

- **`notebooks/dq-snapshot.ipynb`** — scheduled weekly job in Fabric. Executes 140+ metric checks across six sections using a tiered CTE structure. Writes to:
  - `data_quality_snapshot` — weekly-append fact table; aggregated counts by metric, contact type, sales decile, staleness bucket, branch, and creation cohort
  - `contact_issues` — per-contact issue flags for drill-down; refreshed each run
  - Metric and static dimension tables (written on `WRITE_DIM_TABLES` flag)

- **Power BI report** — 8-page report: Executive Summary, Linkage Quality, Completeness, Field Quality, Registry Parity, Account Staleness, Match Readiness, Trends. Sliceable by contact type, sales decile, staleness bucket, and creation cohort.

- **`notebooks/jdso-parity.ipynb`** — separate weekly job added 2026-06-10. Compares active EQUIP contacts against their linked JDSO/Dataverse counterparts field-by-field. Writes daily snapshot, current mismatch detail, and run log to Fabric.

- **`docs/dq-review-notes.md`** — metric-by-metric review of the first snapshot; query bugs fixed and re-run before marking complete.

---

## Report Sections

| Section | What It Measures |
|---|---|
| Linkage Quality | Linked/unlinked counts, type mismatches, orphan cross-ref entries, duplicate entity IDs |
| Registry Parity | Field-by-field comparison (name, address, phone, email) between EQUIP and JD Registry for linked contacts |
| Completeness | Missing name, address, email, phone across all contact types |
| Field Quality | Placeholder values, invalid phones/emails, format issues, misplaced data in name/address fields |
| Account Staleness | Last transaction date buckets; inactivation candidates (5+ years no activity) |
| Match Readiness | Tier classification (Tier 1–4) for unlinked contacts by data completeness — predicts tight match likelihood |

---

## Open Items from DQ Review

See `docs/dq-review-notes.md` for the full list of 31 action items. Key outstanding items:

- Action #13 — `business_phone` parity logic needs verification (93% equip-only rate may be a concatenation format issue)
- Action #14 — varying denominators across linkage metrics need investigation
- Action #23 — filter internal/house accounts from parity queries
- Action #27 — employee linkage scope decision (filter out or link technician/salesperson records)
- Action #28 — account deactivation approach decision
- Action #29 — Ops Center org ID linkage path (Nevin Kroeker / JD DDL)
- Action #31 — card number in notes check (PCI sensitivity — high priority if positives found)
