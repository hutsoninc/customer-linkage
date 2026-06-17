# Phase 5 — Salesforce Cleanup

**Status:** 🔄 In Progress  
**Effort:** Medium | **Risk:** Low (Salesforce-internal) | **Dependency:** Phase 2 complete; Phase 4 underway

**Goal:** Eliminate Salesforce Prospect accounts that should either be merged into an existing Customer account or removed from the system entirely. Automate the ongoing process so future sales convert correctly without manual intervention.

> **Migration context:** This phase is also preparation for a likely future migration from Salesforce to John Deere's SMO platform (Dynamics 365 CRM + Customer Insights and Journeys), anticipated 2027–2028. Prospect records are a priority concern — they exist only in Salesforce and not in EQUIP, so their value must be evaluated before any migration. SF-only data like account assignments and activity history also needs to be reviewed and structured for portability. The cleaner Salesforce is going in, the better the foundation in the next system.

---

## Step 5.1 — Prospect → Customer Merges (Path A: entity ID match)

**Status:** ✅ Substantially complete

Match Salesforce Prospects to linked Customer accounts by entity ID. These are the highest-confidence merge candidates — same entity ID, one is a Prospect, one is a Customer.

**Completed runs:**

| Date | Run | Processed | Merged | Notes |
|---|---|---|---|---|
| 2026-06-06 | Run 1 | 8,808 | 6,979 | 1,829 blocked or flagged — prospect held data needed on the customer or EQUIP side before merging |
| 2026-06-08 | Run 2 | 12,522 | 7,603 | |

**Tooling in place:**
- Queries to pull all account fields for matched prospect/customer pairs
- Per-field merge rules (keep prospect vs. customer value, or block merge entirely)
- Automated merge script with results logged to Fabric — one row per pair with outcome
- Pre-merge snapshot of each merged prospect stored for recovery

**Remaining flagged pairs — ~4,000+ total:**

| Category | Count | Notes |
|---|---|---|
| Customer / Prospect pairs (duplicate matching rules) | ~3,300 | Majority require manual review |
| Other flagged pairs | ~700+ | Prospect held data needing reconciliation before merge |

Most of these were flagged because the prospect held data that needed to be moved to the customer record first — a phone number, address, or other field not present on the customer side — or because the pair matched on duplicate rules but requires a human to confirm before merging.

A small number may be eligible for a re-run of the automated merge script, but most have already been processed once and the remaining cases are genuinely ambiguous.

**Enrichment-then-reprocess path (future, feeds Phase 11):** Once enrichment work is underway, it may be possible to automate resolution of many flagged pairs. For example: pull contact data from both the prospect and customer records, use APIs to validate competing values (e.g., two phone numbers where one has a typo), enrich the customer record with the validated data, then reprocess the pair through the merge script. This reduces the manual review burden significantly and avoids one-by-one adjudication for cases that are data quality issues rather than genuine ambiguity.

---

## Step 5.2 — Process Gap Automation (ongoing)

The root cause of the Prospect backlog: salespeople quote a Prospect, make the sale, create an EQUIP account, but the Prospect is never merged into the Customer account in Salesforce.

**Approach (confirmed):** Rather than changing the invoicing process, build automations to:
- Regularly identify new Prospect → Customer merge candidates based on entity ID matching
- Execute merges automatically for pairs that pass the field-rule logic
- Surface flagged/blocked pairs to an **account cleanup team** for manual resolution
- The team handles only what cannot be resolved in code — everything else is automated

This keeps the backlog from growing again and routes exceptions rather than requiring a process change for salespeople.

---

## Step 5.3 — Orphaned Online Sales Lead Prospects

**Status:** ⏳ Not started — ~14,000 candidate records identified

Online sales leads create a Request in Salesforce and a linked Prospect account. If no quote was ever created against that Prospect, the record is effectively orphaned — no transactional history to preserve.

**~35,000–38,000 total Prospects remain in the system.** At least ~14,000 are from online sales lead sources with no associated quote and may be candidates for cleanup.

**Steps:**
1. Write query: SF Prospect accounts from an online sales lead source with no quote ever created
2. For each qualifying Prospect, copy contact fields (name, phone, email, address) to the linked Request record
3. Delete the Prospect accounts
4. Confirm linked Requests are intact post-deletion

**Risk note:** Deletion is irreversible — dry-run count first, spot-check a sample. Confirm with Anvil whether any SF automation fires on Prospect deletion that could affect the linked Request.

---

## Step 5.4 — SF/Cross-ref Entity ID Disagreements

~150 accounts where Salesforce and the Registry have different entity IDs. For each: determine which entity ID is correct and update the appropriate system. Re-run the disagreement query to confirm resolution.

**Open question:** Who at Hutson can own this manual review?

---

## Open Items

| Item | Status |
|---|---|
| ~1,829 blocked merge pairs needing manual data reconciliation | Open — no owner assigned |
| Orphaned online lead Prospects (~14,000) | Not started |
| SF/cross-ref disagreements (~150) | Not started |
| Process gap automation build | Not started |
| Account cleanup team definition (who handles escalated pairs) | Decision needed |
