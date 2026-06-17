# Phase 2 — Quick Win Linkages

**Status:** ✅ Complete (~2026-06-10)  
**Effort:** Low | **Risk:** Low | **Dependency:** None

**Goal:** Formalize linkages where the Registry entity ID is already known — no matching or data cleanup required.

---

## What Was Done

All sub-steps in this phase targeted accounts where the entity ID was already known from some prior source. The work was Path A (Create DBS Linkage) uploads — no matching algorithm involved.

| Step | Source | Records Linked | Date |
|---|---|---|---|
| 2.1 — Informal EQUIP records | Contacts with `Ckc_Id` in EQUIP but no `cross_ref` entry | 4 (test batch) | 2026-04-29 |
| 2.2 — Anvil-only SF customers | SF customers with quote-workflow entity ID, validated via Path B tight match | 7,263 | 2026-05-27 |
| 2.3 — Quote-to-sale gap (MTD May) | Sold-to accounts identified via quoted prospect entity ID | 39 | 2026-05-26 |
| 2.3 — Quote-to-sale gap (full run) | Same logic applied to full history | 7,408 | 2026-06-01 |
| 2.4 — Warranty registrations | Entity IDs from warranty registrations 2021–2026, deduplicated by year | 4,958 | 2026-06-03 |
| 2.5 — SF customers in JD Registry not in EQUIP | SF accounts with registry entity ID but no EQUIP linkage; validated via tight match | 413 | 2026-06-09 |

**Total Phase 2 linkages: ~20,000+**

---

## Progress Tracking

- Baseline captured at project start: 58,328 linkages (2026-04-29)
- Tracking query: `queries/tracking.sql` — isolates project-attributed linkages by `cross_ref_created_ts >= '2026-04-29'` filtered to known batch dates
- ~40–100 linkages/day created by normal EQUIP workflow — these show in total but are not project-attributed

---

## Remaining Open Items

- **DISAGREE tight matches from Step 2.2 (1,289 records):** Of the 8,446 Phase 1.2 tight matches, 7,157 agreed with Salesforce's entity ID and were accepted. The remaining 1,289 returned a different entity ID than Salesforce has — likely stale Salesforce values, but not confirmed. Options: accept all and let formal linkage overwrite stale SF IDs via overnight sync, accept only AGREE records, or spot-check a sample first. Full list in `uploads/phase1b-reconciliation.csv`.
- **Serial number lookup (originally Step 1.4):** Deferred — identifying the Fabric table with serial number → entity ID mapping, assessing serial number quality in our machine population, and then using confirmed registry owner entity IDs as Path A candidates. Lower priority given how much ground was covered by other steps.
- **Employee linkage scope:** Decision needed on whether to include or filter technician/salesperson records from all linkage metrics and upload batches (Action Item #27 in `dq-review-notes.md`).

---

## Key Queries

| Query | Purpose |
|---|---|
| `queries/phase-1/block-7a.sql` | Anvil-only SF customers — Path B upload format |
| `queries/phase-1/block-7e.sql` | Quote-to-sale gap — Path B upload format |
| `queries/tracking.sql` | Linkage progress tracking |
| `scripts/reconcile_tight_matches.py` | Compare tight match results against Salesforce entity IDs |
