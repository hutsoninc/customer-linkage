# Customer Linkage — Progress Log

**Project start:** 2026-04-29  
**Baseline linkages (before project start):** 58,336  
**Tracking query:** `queries/tracking.sql`

Run `python scripts/fabric_query.py --file queries/tracking.sql --block tracking` at any time to get the current state.

---

## Batch Log

Record each upload after linkages are accepted. "Accepted" = clicked Create Linkage in the tool or confirmed via Path A upload result.

| Date | Phase | Description | Submitted | Accepted / Linked | Notes |
|---|---|---|---|---|---|
| 2026-04-29 | 1.1 test | Phase 1.1 Path A test — 4 records | 4 | 2 created, 2 merged entity | WILSONSOAK71156, WILSONVAN423230 linked to merged entities; YAGLEJAC9453 and YOUNBUC709311 created successfully |
| 2026-04-29 | Manual | 2 manual linkages via EQUIP Contact Maintenance | 2 | 2 | Created manually before project tooling was in place |

---

## Progress Snapshots

Record the output of `tracking.sql` after each major batch is accepted. Paste the two result sets here with a date header.

### 2026-04-29 — Project Start Baseline

| Period | Linkage Count |
|---|---|
| BASELINE (before 2026-04-29) | 58,336 |
| PROJECT (2026-04-29 onward) | — |
| TOTAL (all time) | 58,336 |

*Note: The +1 linkage created on 2026-04-29 visible in cross_ref is from early testing. Daily background activity (~40–100 linkages/day) is ongoing from sources other than this project and is included in total counts but is not project-attributed.*

---

## Pending Batches (not yet accepted)

| File | Phase | Records | Status |
|---|---|---|---|
| `uploads/phase1b-agree-20260429-152040.csv` | 1.2 | 7,150 | Ready — awaiting accept decision |
| `uploads/phase1b-disagree-20260429-152040.csv` | 1.2 | 1,286 | Pending review |
| `uploads/phase1b-errors-corrected-20260429-150026.csv` | 1.2 errors | 489 | Uploaded; tight match results pending |

---

## Targets

| Milestone | Expected Linkages | Status |
|---|---|---|
| Phase 1.1 — 49 informal EQUIP links | ~30 clean + ~19 merged-entity | Not yet uploaded (full batch) |
| Phase 1.2 — AGREE tight matches | ~7,150 | Pending accept |
| Phase 1.2 — DISAGREE tight matches | ~1,286 | Under review |
| Phase 1.2 — Error corrections | ~489 submitted; ~273 tight matched | Pending |
| Phase 3 — ~466k unlinked accounts | TBD (dependent on Phase 2 cleanup) | Not started |
