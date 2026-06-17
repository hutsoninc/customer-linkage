# Phase 4 — Bulk Linkage Upload

**Status:** ⏳ Not Started  
**Effort:** High | **Risk:** Low-Medium | **Dependency:** Phase 3 underway (can begin before Phase 3 is complete)

**Goal:** Link the remaining unlinked accounts through Deere's Customer Linkage Tool (Path B matching), prioritizing high-value accounts and accepting only tight matches that also pass our internal validation checks. This is the primary phase for closing the Project Halo gap (need ~53,000 additional linkages to reach 25%).

---

## Step 4.1 — Define Upload Batches

Prioritize batches by account value to maximize early impact and tight match rate:

- **Batch 1:** Top accounts by revenue (start with 500–1,000 to calibrate tight match rate before scaling)
- **Subsequent batches:** By territory, then by contact type (Individual first, then Business Contact, then Business)
- Keep each file under 60,000 rows / 6MB (Customer Linkage Tool limit)

---

## Step 4.2 — Export via Customer Linkage Contact Data Extract

- Filter: active contacts only, not previously linked (`Ckc_Id` is null / no cross_ref entry)
- Apply the C-type linkage decision from Phase 3 (Step 3.4)
- Employee exclusion: LEFT JOIN `Equip.WKMECHFL` + `Equip.VhSalman`, filter IS NULL on both
- Save as UTF-8 CSV
- Template query: `queries/phase-1/block-7a.sql` — contains the correct B/I/C name-field logic, upload template column order, country code pattern, and employee exclusions. Adapt `WHERE` clause for each population batch.

---

## Step 4.3 — Upload, Validate, and Accept

- Upload via Customer Linkage Tool → Match DBS Customer List
- Monitor processing (~1 min per 500 records); email notification on completion
- **Tight Match tab:** Run `scripts/reconcile_tight_matches.py` to compare matched entity IDs against Salesforce `Anvil__CustomerCompEntityID__c` — produces AGREE / DISAGREE / SF_MISSING CSV. Review before accepting any batch. Do not bulk-accept without running reconciliation.
- **Potential Match tab:** Defer — route to account managers (see Phase 5 manual review track)

---

## Step 4.4 — Measure and Adjust

After each batch:
- Note tight match rate, error rate, and potential match rate
- If tight match rate is low, identify patterns in unmatched records and address data quality before next batch
- Record accepted batch in `docs/update-log.md`
- Re-run `queries/tracking.sql` to update progress snapshot

---

## Pre-Upload Checklist

Before accepting any tight match batch, verify:
- [ ] Reconciliation script run — AGREE/DISAGREE split reviewed
- [ ] Entity IDs checked for deceased (`descd_ind = 'Y'`) / out-of-business (`out_of_busn_ind = 'Y'`) status in `DDP.customer_profile`
- [ ] Contact type alignment spot-checked (EQUIP I matched to Registry Individual, not Business)
- [ ] C-type linkage level decision applied correctly in the extract

---

## CAM / Store-Targeted Batches (manual review path)

For potential matches and low-confidence records, route in targeted batches by territory rather than centralizing review:
- Pull unlinked EQUIP accounts filtered by branch or assigned CAM
- Run through Path B to get tight matches and potential matches
- Send tight match results to the responsible CAM: confirm the match looks right, then accept in the tool
- Route potential matches the same way — CAMs know their customers and can resolve faster than centralized review
- Package results in an Excel the reviewer can work from without needing system access

**Open question:** What review delivery format works best for CAMs — email with Excel, a Salesforce report, a simple form?

---

## Open Decisions Required Before Phase Begins

| Decision | Where Decided |
|---|---|
| Inactivation cutoff date | Phase 3 Step 3.1 |
| C-type linkage level (entity vs. contact) | Phase 3 Step 3.4 |
| Employee linkage scope | Action Item #27 in dq-review-notes.md |
| "Accounts Payable" company name handling | Phase 3 Step 3.3 |
| Target linkage percentage / scope | Business decision — 25% minimum (Project Halo), stretch goal TBD |
| Manual review ownership (potential matches) | Needs an owner at Hutson |
