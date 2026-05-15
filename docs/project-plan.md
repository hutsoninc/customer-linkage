# Customer Linkage — Project Plan

**Created:** 2026-04-28  
**Status:** In Progress (Phase 0 complete, Phase 1 underway)

---

## Goals

1. **Increase linkage** — Formally link EQUIP contacts to John Deere Registry (IKC/CKC) so our DBS number appears in CSC across all JD sales tools (JDQuote2, JDMint, Sales Center, Rewards, Warranty Portal, etc.) and downstream data (UCC filings, equipment history) becomes navigable by customer.
2. **Clean and validate customer information** — Standardize EQUIP contact data to Registry conventions, remove stale records, and resolve data quality issues that prevent tight matching.
3. **Merge duplicates** — Merge Salesforce Prospects into Customers where a sale has been made and the records diverged. Secondarily, merge confirmed duplicate contacts within EQUIP and clean up duplicate entity IDs in Deere's Registry.
4. **Unlock downstream integrations** — Use Registry linkage as the foundation to connect with Customer Lead Generator (CLG), Operations Center org IDs, Expert Connect, and UCC/EDA filing data — enabling use cases such as lead filtering, lost sale alerting, and inbound call enrichment.

---

## Constraints

- **No dedicated manual reviewer** — Potential matches from the Customer Linkage Tool require human judgment. Design all phases to maximize tight matches (auto-approved) and defer or route potential matches to account managers.
- **Partner coordination required for EQUIP merges** — Must work with Anvil to handle merges in Salesforce and ensure data is syncing properly.
- **EQUIP merges are off-hours operations** — The Customer/Contact Merge program touches a large number of tables.
- **Upload limits** — Customer Linkage Tool accepts max 6MB / ~60,000 rows per file. Multiple uploads required.
- **Salesforce entity ID precedence** — `H_Equip_contact_Ckc_Id__c` (synced from EQUIP formal linkage) overwrites `Anvil__CustomerCompEntityID__c` (from quote workflow) when populated. Creating formal EQUIP linkages will auto-correct stale Anvil entity IDs through the normal sync.

---

## Current State (as of 2026-04-29)

| Segment | Count | Notes |
|---|---|---|
| EQUIP active accounts (ArMaster) | ~524,971 | |
| Formally linked via Registry cross_ref | ~58,328 | Corrected (blocks 6a–6i) — original 58,282 used case-sensitive join |
| SF and cross_ref agree — clean baseline | 56,491 | Corrected — original 55,796 |
| SF and cross_ref disagree — needs review | 149 | Corrected — original 144 |
| EQUIP has CKC ID, no cross_ref entry | 49 | Corrected — original 590 was inflated by case-sensitive join false positives |
| SF customers: Anvil-only entity ID (no formal EQUIP link) | 12,970 | |
| SF prospects: Anvil entity ID from quotes | 23,973 | |
| EQUIP active accounts, fully unlinked | ~466,000 | |
| Confirmed EQUIP duplicate contacts | 599 | Corrected — original 603 |
| SF Prospect accounts total | 50,705 | |

See `research-findings.md` for full data analysis and query results.  
See `data-model.md` for table relationships and field semantics.

---

## Order of Operations

---

### Phase 0 — Data Quality Reporting Baseline
**Effort:** Medium | **Risk:** Low | **Dependency:** None  
**Status:** Complete (2026-05-15)  
**Goal:** Establish a weekly snapshot pipeline and Power BI report to track data quality trends, surface cleanup targets, and provide a measurable before/after baseline for Phase 2.

#### What was built

- **Notebook** — `notebooks/dq-snapshot.ipynb` — primary artifact running in production as a scheduled weekly job. Executes all DQ metric logic across six sections (Linkage Quality, Registry Parity, Completeness, Field Quality, Staleness, Match Readiness) using a tiered CTE structure, then assembles and writes results. Defines all tables created by this phase:
  - `data_quality_snapshot` — weekly-append fact table; aggregated counts by metric, contact type, sales decile, staleness bucket, branch, and creation cohort
  - `contact_issues` — per-contact issue flags for drill-down; updated each run
  - Metric and static dimension tables (written on `WRITE_DIM_TABLES` flag)
- **Power BI report** — 8-page report (Executive Summary, Linkage Quality, Completeness, Field Quality, Registry Parity, Account Staleness, Match Readiness, Trends) sliceable by all aggregation dimensions
- **First snapshot reviewed** — `docs/dq-review-notes.md` — metric-by-metric findings; query bugs fixed and re-run before marking complete

See `docs/data-quality-plan.md` for full metric definitions, architecture, and aggregation dimension logic.

---

### Phase 1 — Path A Quick Win Linkages
**Effort:** Low | **Risk:** Low | **Dependency:** None  
**Goal:** Formalize linkages where the entity ID is already known — no matching or cleanup required.

#### Step 1.0 — Establish Progress Tracking Baseline
- **Baseline captured:** 58,336 linkages as of 2026-04-29 (project start)
- Tracking query: `queries/tracking.sql` — run any time to see total vs. project-attributed linkages
- After each batch is accepted, record it in `docs/linkage-progress.md` (batch log + progress snapshot)
- Note: ~40–100 linkages/day are created by other sources (EQUIP normal workflow) — these show in the total but are not project-attributed. Project linkages are isolated by `cross_ref_created_ts >= '2026-04-29'` filtered to known batch dates.

#### Step 1.1 — Link the 586 Informal EQUIP Records
These contacts have a valid CKC ID in EQUIP and Salesforce, confirmed consistent between both systems, but no formal `customer_cross_ref` entry exists.

- Write extraction query: pull `contact_code` + `Ckc_Id` for all contacts where `Ckc_Id IS NOT NULL` and no cross_ref entry exists
- Format output to `Create_Bulk_Linkages_Template.csv` (`DBS Number`, `Entity Id`, `Contact Id`)
- Upload via Customer Linkage Tool → Create DBS Linkage
- Verify results in cross_ref after overnight sync

#### Step 1.2 — Validate and Link Anvil-Only Customers (12,970)
These Salesforce customers have an entity ID from the quote workflow but no formal EQUIP linkage. Use the Customer Linkage Tool's Path B matching to independently validate the Salesforce entity IDs before formally linking.

**Why Path B for validation:** Deere's matching algorithm confirms the entity ID using name + address + phones/email — a stronger signal than just checking the ID exists in `customer_profile`. Divergences (tight match to a *different* entity ID) surface records where Salesforce quietly has a stale or wrong entity ID.

**Steps:**
- Write query to pull EQUIP contact code + contact data (name, address, phones, email) for the 12,970 records → format to `DBS_Registry_UploadTemplate.csv`
- Upload to Customer Linkage Tool → Path B (Match DBS Customer List)
- Download the **Tight Match Report** (per-record export with matched entity IDs)
- Run comparison query: tight match entity ID vs. Salesforce `Anvil__CustomerCompEntityID__c`

**Four outcomes and actions:**

| Outcome | Interpretation | Action |
|---|---|---|
| Tight match, **same** entity ID | Strong confirmation — Deere agrees | Accept linkage in the Tight Match tab |
| Tight match, **different** entity ID | Anvil ID likely stale or wrong | Investigate before linking — flag for manual review |
| Potential match | Ambiguous; EQUIP data may be imprecise | Check if Anvil ID is among candidates; route to manual review |
| No match | EQUIP data too dirty to match, or customer not in Registry | Validate entity ID against `customer_profile` (exists + not deceased/OOB); link via Path A if valid, else flag |

**Expected outcome:** ~13,500+ additional formal linkages; stale/wrong Salesforce entity IDs identified as a side effect.

---

### Phase 2 — EQUIP Data Cleanup
**Effort:** Medium | **Risk:** Low | **Dependency:** None (can run parallel to Phase 1)  
**Goal:** Improve data quality so Path B uploads produce tight matches instead of potential matches.

#### Step 2.1 — Inactivate Stale Accounts
- Use the EQUIP Inactivate Customer Records program
- Filter: no activity since a defined cutoff date (e.g., 5 years)
- Set Inactive Reason appropriately (Out of Business, Deceased, etc.)
- Inactivated records are excluded from the Customer Linkage Contact Data Extract automatically

#### Step 2.2 — Standardize Coded Fields
- Run Contact Mass Update for **State**, **Country**, and **Prefix**
- The Old Value dropdown will surface all non-compliant values (e.g., "Illinois" instead of "IL")
- Convert each until the Old Value list is empty
- These fields are used by Registry's tight-match algorithm

#### Step 2.3 — Fix Misplaced Data
- Export Contact data to Excel (or query Fabric) to audit misplaced values:
  - "OUT OF BUSINESS" or "DECEASED" stuffed into Company Name or address fields
  - Combined names ("John & Mary") in First Name — these should be separate individual records
  - "C/O Bill" or similar in address fields
  - Data that belongs in Doing Business As, Familiar Name, Generation, or Suffix fields
- Correct in EQUIP or flag for batch update

#### Step 2.4 — Business vs. Contact Linkage Decision
- For Business with Contact (C-type) records: decide whether to link at the **business entity** level or the **individual contact** level
- If linking to business: use "Exclude Business Contact Name for Businesses with Contacts" checkbox in the Customer Linkage Contact Data Extract — strips name fields so Registry matches to the business record, not a contact
- Document the decision — it affects how the extract is generated for all C-type contacts

#### Step 2.5 — Phone Number Cleanup
- Identify structurally invalid phone numbers in `BusinessPhone`, `PrivatePhone`, `MobilePhone`:
  - All zeros (`0000000000`)
  - Sequential placeholders (`1234567890`, `1111111111`, etc.)
  - Wrong length (not 10 digits for US after stripping formatting)
  - Non-numeric characters that survived the stripped fields
- Options: write validation queries to surface counts by pattern; bulk-null confirmed bad values via Contact Mass Update or SQL; consider a simple Python formatter pass
- Do **not** re-validate numbers Deere has already verified — see Step 2.7 for cross-referencing Registry data before deciding scope

#### Step 2.6 — Email Address Cleanup
- Identify structurally invalid email addresses in `email_address`:
  - Missing `@` or domain
  - Placeholder values (`test@test.com`, `noemail@noemail.com`, `none@none.com`, etc.)
  - Internal employee emails left on customer records
- Structural validation (regex) can be done in a query without an external API
- For deliverability validation (DNS/SMTP checks), an API such as ZeroBounce or NeverBounce could be used — weigh cost vs. value given email is used for potential match scoring in the linkage tool
- Flag invalid emails; bulk-null confirmed bad values

#### Step 2.7 — Cross-Reference with Deere's customer_profile for Contact Data Variance
- For already-linked contacts, join `Equip.contact` to `DDP.customer_profile` on entity ID and compare key fields: address, phone, email
- Surface records where EQUIP and Registry diverge significantly — these are candidates for DBS Data Share (CSC 2.0) or manual correction in whichever system is authoritative
- Deere's Registry data is not guaranteed clean either (receives data from many sources: UCC filings, FSA/SIC, quote workflows, Digital User Accounts). JD Financial data overwrites Registry and cannot be edited directly. Treat Registry as a signal, not a source of truth
- **Goal:** identify patterns (e.g., EQUIP has outdated addresses that Registry has corrected) rather than bulk-overwriting either side

#### Step 2.8 — Cleanup Reporting and Progress Tracking
- Establish baseline validation queries **before** any cleanup runs, so before/after counts are meaningful:
  - Invalid phone counts by type (all-zero, placeholder, wrong length)
  - Invalid email counts by pattern
  - Non-standard State, Country, Prefix value counts (already surfaced by Contact Mass Update dropdown)
  - EQUIP vs. Registry variance counts for linked contacts
- After each cleanup pass, re-run the same validation queries and record the delta — this is the "changed/affected records" metric
- Consider a simple dashboard query or TSV snapshot approach: run a fixed set of validation queries and save results to `results/cleanup-baseline-YYYYMMDD.tsv` before and after each major pass
- Open question: what format/audience does reporting need to serve? Internal tracking only, or presentable to management/staff? Decides whether a query snapshot is sufficient or a more structured report is needed (see Open Questions)

---

### Phase 3 — Path B Bulk Upload (Unlinked Contacts)
**Effort:** High | **Risk:** Low-Medium | **Dependency:** Phase 2 complete  
**Goal:** Link unlinked EQUIP accounts through the Customer Linkage Tool's match process, prioritizing high-value accounts and accepting only tight matches that also pass our internal validation checks. This is not a bulk dump of all ~466,000 unlinked records — accounts with poor data quality or ambiguous matches are deferred until data is corrected.

#### Step 3.1 — Define Upload Batches
Prioritize batches by value to maximize early impact:
- **Batch 1:** Top N customers by sales (use available sales history queries — start with 500–1,000 to calibrate tight match rate)
- **Subsequent batches:** By territory, then by account type (Individual, then Business Contact, then Business)
- Keep each file under 60,000 rows / 6MB

#### Step 3.2 — Export via Customer Linkage Contact Data Extract
- Filter: active contacts only, not previously linked (`Ckc_Id` is null / no cross_ref entry)
- Apply business vs. contact decision from Step 2.4
- Save as UTF-8 CSV

#### Step 3.3 — Upload and Process
- Upload via Customer Linkage Tool → Match DBS Customer List
- Monitor processing (~1 min per 500 records); email notification on completion
- **Tight Match tab:** Run reconciliation script to compare Deere's matched entity IDs against our Salesforce data and apply internal validation checks before accepting — do not accept all without review
- **Review tab (Potential Matches):** Skip for now — defer to Phase 5

#### Step 3.4 — Measure and Adjust
After each batch:
- Note tight match rate, error rate, and potential match rate
- If tight match rate is low, identify patterns in unmatched records and address in EQUIP data before the next batch
- Repeat until all priority accounts are covered

---

### Phase 4 — Salesforce Prospect → Customer Merges
**Effort:** Medium | **Risk:** Low (Salesforce-internal) | **Dependency:** Phase 1 complete, Phase 3 underway  
**Goal:** Merge Salesforce Prospect records into their corresponding Customer records to eliminate duplicates and consolidate quote/opportunity history.

#### Step 4.1 — Match Prospects to Linked Customers by Entity ID
Once Phase 1 and Phase 3 establish more formal linkages, entity IDs on Prospects can be matched to entity IDs on now-linked Customers.

- Write query: find Salesforce Prospects where `Anvil__CustomerCompEntityID__c` matches `H_Equip_contact_Ckc_Id__c` on a Customer record
- These are the highest-confidence merge candidates — same entity ID, one is a prospect, one is a customer
- Execute SF Prospect → Customer merge for confirmed pairs

#### Step 4.2 — Address the Process Gap (Ongoing)
The root cause of 23,973 prospects: salespeople quote a prospect, make the sale, create an EQUIP account, but never close the loop (update entity ID in EQUIP, merge prospect in SF).

- Define a documented process for post-sale conversion: update EQUIP contact with entity ID → merge SF Prospect into Customer
- Consider building a report or alert to surface Prospects with entity IDs that match a Customer account, prompting the merge

#### Step 4.3 — Delete Orphaned Online Sales Lead Prospects
Online sales leads create a Request in Salesforce and a linked Prospect account. If no quote was ever created against that Prospect, the record is effectively orphaned — it has no transactional history to preserve and often lacks enough data to match or merge to an existing Customer account.

**Why clean these up:** These prospects add noise to the account list and cannot be productively acted on through the normal Phase 4.1 merge path. When migrating to SMO, they should not be carried in as Prospects — the intended model is to create Prospects only when actively quoting or ready to convert, not at lead-creation time.

**Steps:**
- Write query: SF Prospect accounts created from an online sales lead source, where no quote (`Anvil__Quote__c` or equivalent) has ever been created against the Prospect
- For each qualifying Prospect, copy contact fields (name, phone, email, address) to the linked Request record so the contact information is retained in the lead history
- Delete the Prospect accounts
- Confirm the linked Requests are intact post-deletion

**Risk note:** Deletion is irreversible — run the query as a dry-run count first and spot-check a sample before executing. Confirm with Anvil whether any SF automation fires on Prospect deletion that could affect the linked Request.

---

### Phase 5 — Manual Review Backlog
**Effort:** Low-Medium | **Risk:** Low | **Dependency:** Parallel / ongoing  
**Goal:** Resolve records that require human judgment and can't be handled in bulk.

#### Step 5.1 — Resolve the 144 SF/Cross-ref Disagreements
- Pull full list (extend block 3c query to return all 144, not just TOP 50)
- For each: determine which entity ID is correct — the EQUIP/SF one or the cross_ref one
- Correct in the appropriate system; re-run block 3b to confirm resolution

#### Step 5.2 — Route Potential Matches from Phase 3
- Do not attempt a centralized review session (no dedicated reviewer)
- Route in small batches to account managers as part of their regular customer touchpoints
- "Do you recognize this customer? Is this the same person?" framed as a quick confirmation
- Accept lower final linkage percentage on potential matches and revisit as bandwidth allows

---

### Phase 6 — EQUIP Customer → Customer Deduplication
**Effort:** High | **Risk:** High | **Dependency:** Phases 1–3 complete  
**Goal:** Merge duplicate EQUIP customer records. The 599 contacts identified by contact-code-level matching (same Registry entity linked to 2+ EQUIP contact codes) are a confirmed subset — full deduplication across all active accounts will surface additional duplicates beyond what the contact-code method catches.

#### Step 6.1 — Investigate Mixed-Type Cases First
- Run block 2g query (written but not yet executed): inspect the 49 C+I mixed-type duplicates
- Determine: are these the same person in two roles, or data entry errors?
- Also review B+C cases (9 entities) — likely legitimate relationships, not duplicates

#### Step 6.2 — Coordinate with Partners
Before any merges:
- Notify CustomerTRAX, Foresight, Sedona — they must merge data in their systems in sync
- Update any In-Progress Work Orders to the surviving customer number
- Schedule merges during off-hours

#### Step 6.3 — Merge by Priority
Using the EQUIP Customer/Contact Merge program:
1. **I+I pairs (372 entities)** — Clearest duplicates, same individual entered twice
2. **C+C pairs (123 entities)** — Same business contact entered twice
3. **I+I+I and C+C+C (15 entities)** — Three-way duplicates
4. **Mixed types (post-investigation)** — C+I and others based on Step 6.1 findings
5. **Complex cases** — B+C+C, C+C+C+C+C — handle individually

Use "Delete After Merging" on the losing contact. Merge Contact Codes immediately after to consolidate transactional history.

---

### Phase 7 — Operations Center Org Reconciliation
**Effort:** TBD | **Risk:** TBD | **Dependency:** Phases 1–4 complete  
**Goal:** Build a complete map between our EQUIP accounts, Deere's Registry entity IDs, and Operations Center Organization IDs.

Operations Center uses Organization IDs which link to Registry Entity IDs via port IDs. Organizations can have multiple contacts, each with their own Entity ID. Establishing this mapping unlocks Operations Center data (machine telematics, field operations, agronomic records) navigable by our customer account.

- Revisit once Registry linkage (Phases 1–3) is mature and coverage is high
- Requires separate research into available datasets and the Org ID → Entity ID mapping
- The full account map (EQUIP account → Registry entity → Org ID) is a foundational dataset for downstream analytics and future integrations
- Treat as a distinct workstream

---

### Phase 8 — Expert Connect Enrichment
**Effort:** TBD | **Risk:** Low | **Dependency:** Phases 1–3 complete  
**Goal:** Use Registry linkage to automatically enrich Expert Connect with customer name and contact information, eliminating the need for representatives to manually add it when a call comes in.

Expert Connect currently shows phone numbers for the majority of inbound contacts but no name or account context. Representatives must manually look up or enter this information during or after the call.

- With Registry linkage in place, the entity ID provides the bridge from phone number → Registry record → EQUIP account
- Requires research into the Expert Connect data model and available integration points (API, flat file sync, or push from another system)
- Outcome: inbound callers are identified automatically; account information is visible before the rep picks up

---

### Phase 9 — EDA Buyer ID Mapping and Lost Sale Alerts
**Effort:** TBD | **Risk:** Low | **Dependency:** Phases 1–3 complete  
**Goal:** Leverage Deere's EDA buyer ID → entity ID mapping to connect UCC filing data to our customer accounts, enabling lost sale detection.

Deere has provided an EDA buyer ID to entity ID mapping. UCC (Uniform Commercial Code) filings record equipment financing and are filed when a customer purchases equipment through a lender. If a UCC filing appears for a customer linked to our account but the sale did not go through us, that is a lost sale.

- With sufficient Registry linkage coverage, we can join: EQUIP account → Registry entity ID → EDA buyer ID → UCC filing
- Compare UCC filings against our own sales history to identify equipment purchases made elsewhere
- Surface these as alerts to the Regional Customer Account Manager (RCAM) responsible for that account — a real-time lost sale report
- Prioritize by account value (sales decile from DQ report) to focus RCAM attention on high-value accounts first
- Requires confirming the EDA buyer ID dataset is accessible in Fabric and understanding refresh cadence of UCC filing data

---

## Summary Timeline

```
Phase 0   DQ reporting baseline       Complete — weekly snapshot pipeline + Power BI report
Phase 1   Path A quick wins           Low effort, start immediately
Phase 2   EQUIP data cleanup          Run parallel to Phase 1
Phase 3   Path B bulk upload          Main project effort, after Phase 2
Phase 4   SF Prospect merges          After Phase 1, ongoing during Phase 3
Phase 5   Manual review backlog       Ongoing parallel track
Phase 6   EQUIP dedup                 After Phases 1–3, high coordination cost
Phase 7   Operations Center           Separate track, after Phases 1–4
Phase 8   Expert Connect enrichment   After Phases 1–3, integration research required
Phase 9   EDA / UCC lost sale alerts  After Phases 1–3, depends on EDA dataset access
```

---

## Open Questions

- [ ] **Phase 1.2 — Check tight match entity IDs for deceased / out-of-business status before accepting:**
  The 8,446 Phase 1.2 tight match entity IDs were sourced from Salesforce's `Anvil__CustomerCompEntityID__c`. Some of these entities may have been marked deceased (`descd_ind = 'Y'`) or out of business (`out_of_busn_ind = 'Y'`) in `DDP.customer_profile` since the Salesforce field was populated. The Registry still contains the record and the tight match will succeed, but linking to a deceased/OOB entity may be incorrect. Run `queries/phase-1/block-7d.sql` to identify any problematic entity IDs before accepting the AGREE/DISAGREE batches and decide whether to exclude them.
- [ ] **Entity type alignment — should EQUIP contact type match the Registry entity type returned by tight match?**
  When the tight match report returns an entity ID, it also returns a Contact ID (0 = entity-level match; non-zero = business contact match). The question is whether the Registry type should align with the EQUIP `Business_Individual` type:
  - EQUIP B (Business) → expect entity-level match (Contact ID = 0) to a Business in Registry
  - EQUIP I (Individual) → expect entity-level match (Contact ID = 0) to an Individual in Registry
  - EQUIP C (Business Contact) → expect contact-level match (Contact ID ≠ 0), but could we accept entity-level (Contact ID = 0)?
  Misalignments (e.g., an EQUIP Individual tight-matched to a Business entity) may indicate a wrong match or data quality issues on either side. Run exploratory queries to measure the overlap/variance across the full tight match population. A one-time test on a known-good sample would establish whether tight matches reliably align by type. See `research-findings.md` for initial surface-area analysis.
- [ ] **Phase 1.2 — How to handle 1,289 DISAGREE tight matches (reconciliation finding):**
  Of the 8,446 Phase 1.2 tight matches, 7,157 agree with Salesforce's `Anvil__CustomerCompEntityID__c` and are safe to bulk accept. The remaining 1,289 returned a *different* entity ID than Salesforce has. Since tight matches are high-confidence (standardized name + address), the Salesforce value is likely stale or wrong — but this has not been confirmed. Options: (a) accept all 8,446 tight matches, letting the formal EQUIP linkage overwrite the stale SF entity ID via the overnight sync; (b) accept only the 7,157 AGREE records now, and defer the 1,289 for investigation; (c) spot-check a sample of DISAGREE records in CSC before deciding. See `uploads/phase1b-reconciliation.csv` for the full list.
- [ ] **Phase 1.1 — How to handle 6 C-type records where contact-level linkage will be lost (block-7b finding):**
  Of the 49 Phase 1.1 records, 6 will not link at the contact level:
  - 5 records (AHWLLC4793368, HEDINGERKEITH71, JLDLAGUËH7E5N86, ROSSVIEWHIGHS68, WILSONSOAK71156): entity ID no longer exists in Registry (merged); tool follows merge chain but drops the contact, linking to the surviving business entity instead.
  - 1 record (CARNAHANC6541): entity exists but the specific contact does not.
  Options: (a) upload all 49 and accept entity-level links for these 6, then spot-check in CSC; (b) hold the 6 for manual investigation before uploading; (c) upload the clean 30 now and defer the 19 stale-entity records.
  Additionally, the 19 stale `Ckc_Id` values in EQUIP should be updated after linkage to reflect the current merged entity IDs. **Note:** The Customer Linkage Tool does NOT update EQUIP — after upload, EQUIP still shows the old entity/contact IDs (confirmed: WILSONSOAK71156 still shows entity `349494940` / contact `328618610` instead of the merged `321788532` / `0`). These must be corrected separately — see the open question below.
- [ ] **Cleanup reporting format and audience (Step 2.8):** Is a query snapshot (TSV before/after) sufficient for internal tracking, or does reporting need to be presentable to management or staff? Answer determines whether to build a structured report or keep it as ad-hoc validation queries.
- [ ] **Phone/email validation scope (Steps 2.5–2.6):** For phone numbers, is structural validation (pattern matching in SQL) sufficient, or do we need deliverability/carrier validation? For email, is structural regex enough, or is an external API (ZeroBounce, NeverBounce) worth the cost given its impact on tight match scoring?
- [ ] **Registry data as correction source (Step 2.7):** For linked contacts where Registry has a cleaner/more current value than EQUIP, what is the policy for updating EQUIP? Manual review per record, DBS Data Share in bulk, or leave as-is and accept divergence? Note: JD Financial records cannot be edited directly.
- [ ] What is the inactivation cutoff date for stale accounts? (Step 2.1)
- [ ] Link at business entity level or contact level for C-type contacts? (Step 2.4)
- [ ] Who at the dealership can own the manual review for the 144 disagreements and potential match batches? (Phase 5)
- [ ] Have CustomerTRAX, Foresight, Sedona been notified of the project? (Phase 6 prerequisite)
- [ ] What is the desired target linkage percentage — is there a business goal (e.g., top 80% of accounts by revenue, or all active accounts)? (Phase 3 scope)
- [x] **EQUIP entity ID write-back — RESOLVED (2026-04-30):** Write-back IS confirmed — EQUIP updated overnight after the Phase 1.1 test upload. Entity ID was corrected to the surviving merged entity. Contact ID (328618610) was preserved in EQUIP even though the tool returned 0 for "Merged Contact ID that was linked" — behavior is to not zero out an existing contact ID during write-back. If the contact itself were merged to a different ID in the Registry, the contact ID field may update to that new value. Phase 1.2 records (null `Ckc_Id`) should populate automatically after upload and overnight sync — run `queries/phase-1/block-7c.sql` to confirm coverage.
- [ ] Block 4c/4d (sentinel ID check) and block 2g (C+I mixed-type inspection) still need to be run.

---

## Reference Files

| File | Description |
|---|---|
| `research-findings.md` | Full data research, all test block queries and results |
| `data-model.md` | Entity relationship diagram and field semantics |
| `input/Available Datasets.md` | Dataset descriptions and key columns |
| `input/test-results/` | All query result TSV files (blocks 1a–4b) |
| `input/Create_Bulk_Linkages_Template.csv` | Template for Path A (Create DBS Linkage) uploads |
| `input/DBS_Registry_UploadTemplate.csv` | Template for Path B (Match DBS Customer List) uploads |
| `input/Delete_Bulk_Linkages_Template.csv` | Template for removing linkages |
