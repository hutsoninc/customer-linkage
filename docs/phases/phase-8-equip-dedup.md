# Phase 8 — EQUIP Customer Deduplication

**Status:** ⏳ Not Started  
**Effort:** High | **Risk:** High | **Dependency:** Phases 2 and 4 complete (linkage coverage mature); partner coordination required

**Goal:** Merge duplicate customer records in EQUIP where the same customer was entered twice and both records got linked to the same Registry entity. The 599 confirmed duplicates identified so far are a subset — full deduplication across all active accounts will surface more.

---

## Why This Phase Is Last Among Foundation Work

EQUIP merges touch a large number of tables. They require partner systems (CustomerTRAX, Foresight, Sedona) to merge data in sync, in-progress work orders to be updated before the merge, and off-hours scheduling. The coordination cost is the highest of any phase. Doing this after linkage coverage is mature means we have the clearest picture of which records are true duplicates before committing to irreversible merges.

---

## Step 8.1 — Investigate Mixed-Type Cases First

Run the C+I mixed-type inspection query (block 2g — written but not yet executed). Determine:
- Are these the same person in two roles, or data entry errors?
- Review B+C cases (9 entities) — likely legitimate relationships, not duplicates

This step gates the merge plan for Steps 8.3+.

---

## Step 8.2 — Coordinate with Software Partners

Before any merges:
- Notify **CustomerTRAX**, **Foresight**, and **Sedona** — they must merge their data in sync with EQUIP
- Confirm none have notified them of the project yet (open question)
- Update any in-progress work orders to the surviving customer number
- Schedule merges during off-hours (the merge program touches a large number of tables)

---

## Step 8.3 — Merge by Priority

Using the EQUIP Customer/Contact Merge program. Use "Delete After Merging" on the losing contact. Merge Contact Codes immediately after to consolidate transactional history.

Priority order:

| Priority | Type | Confirmed Count | Notes |
|---|---|---|---|
| 1 | I+I (Individual + Individual) | 372 entities | Clearest duplicates — same person entered twice |
| 2 | C+C (Business Contact + Business Contact) | 123 entities | Same business contact entered twice |
| 3 | I+I+I and C+C+C (three-way) | 15 entities | |
| 4 | Mixed types (post-investigation) | ~49 C+I entities | After Step 8.1 investigation |
| 5 | Complex cases | B+C+C, C+C+C+C+C | Handle individually |

---

## Confirmed Duplicate Detection Method

Current confirmed count (599) was identified by finding multiple EQUIP `contact_code` values linked to the same Registry entity ID via `customer_cross_ref`. This is a reliable signal of a duplicate — the Registry only assigns one entity per real-world customer.

Full deduplication (beyond the 599 confirmed via cross_ref) will require additional matching approaches (name + address similarity, phone/email matching) and will surface more candidates once linkage coverage from Phase 4 is higher.

---

## Open Questions

- Has CustomerTRAX / Foresight / Sedona been notified about this project? (prerequisite for scheduling)
- After reviewing mixed-type cases (Step 8.1), what is the policy for C+I pairs — are they treated as duplicates or legitimate separate relationships?
- What is the process for handling work orders that reference the losing customer number?
