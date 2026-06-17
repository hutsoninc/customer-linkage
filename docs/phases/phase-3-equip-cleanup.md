# Phase 3 — EQUIP Data Cleanup + JDSO Parity

**Status:** 🔄 In Progress  
**Effort:** Medium | **Risk:** Low | **Dependency:** Can run parallel to Phase 4

**Goal:** Improve contact data quality so that Phase 4 bulk uploads produce tight matches rather than potential matches or no matches. Also validate field parity between EQUIP and JDSO before any bulk updates to avoid propagating stale data from one system to the other.

---

## Step 3.0 — Validate EQUIP/JDSO Field Parity (prerequisite)

**Status:** 🔄 In Progress — parity notebook live as of 2026-06-10

The EQUIP ↔ JDSO integration is bidirectional. If a bulk update is applied via JDSO/Dataverse, JDSO's version of each field overwrites EQUIP — including cases where EQUIP has the correct value. Running cleanup without knowing the current mismatch state risks propagating bad data in the wrong direction.

**`notebooks/jdso-parity.ipynb`** runs weekly, comparing active EQUIP contacts against their JDSO/Dataverse counterparts field-by-field and writing mismatch detail to Fabric. This is the parity baseline.

**Gate:** Use parity findings to decide whether to apply each cleanup pass directly in EQUIP or via JDSO/Dataverse before running Steps 3.1–3.8.

---

## Step 3.1 — Inactivate Stale Accounts

Use the EQUIP Inactivate Customer Records program. Filter on no activity since a defined cutoff date (e.g., 5+ years). Inactivated records are automatically excluded from the Customer Linkage Contact Data Extract.

**Open decision:** What is the inactivation cutoff date? Vicky (JD, 2026-05-29) advised prioritizing recent purchasers and active accounts rather than chasing deactivated records. A defined cutoff is required before this step runs.

---

## Step 3.2 — Standardize Coded Fields

Run Contact Mass Update for **State**, **Country**, and **Prefix**. The Old Value dropdown surfaces all non-compliant values. Convert each until the Old Value list is empty. These fields are used by Registry's tight-match algorithm.

**Already done (partial):** Country corrections completed 2026-05-19 (376 records corrected from USA, CANANDA, U.S.A., etc.).

---

## Step 3.3 — Fix Misplaced Data

Export contact data and audit:
- "OUT OF BUSINESS" or "DECEASED" stuffed into Company Name or address fields
- Combined names ("John & Mary") in First Name — should be separate individual records
- "C/O Bill" or similar in address fields
- Data that belongs in Doing Business As, Familiar Name, Generation, or Suffix fields
- **"Accounts Payable" as company name** — AR contacts where the invoice billing name is "Accounts Payable" rather than the actual business name; these will never match in the Registry

**Open question:** "Accounts Payable" company name contacts — query to get count, manually research actual business names, or exclude permanently as unresolvable?

---

## Step 3.4 — Business vs. Contact Linkage Decision

For Business-with-Contact (C-type) records: decide whether to link at the **business entity** level or the **individual contact** level.

Per Vicky (2026-05-29): C-at-entity-level is acceptable. The real concern is I-type contacts linked to a business entity. C-type at entity level may be the simpler and correct choice for most cases.

**Open decision:** Confirm the C-type linkage approach before Phase 4 uploads begin. This controls how the Customer Linkage Contact Data Extract is configured.

---

## Step 3.5 — Phone Number Cleanup

Identify and null out across all three phone fields:
- All zeros (`0000000000`)
- Sequential placeholders (`1234567890`, `1111111111`, etc.)
- Wrong length (not 10 or 11 digits for US after stripping formatting)
- Non-numeric characters

DQ report (Section 4e) provides the baseline counts per pattern. Run targeted queries from `contact_issues` table to get the affected contact list.

---

## Step 3.6 — Email Address Cleanup

Identify and null out:
- Missing `@` or domain
- Known placeholder patterns (`noemail@`, `test@test`, `none@none`, `noreply@`, etc.)
- Internal employee emails left on customer records

**Open question:** Is structural regex validation sufficient, or is deliverability validation (ZeroBounce, NeverBounce) worth the cost given email's weight in tight match scoring?

---

## Step 3.7 — Cross-Reference with Registry for Data Variance

For already-linked contacts, join `Equip.contact` to `DDP.customer_profile` on entity ID and compare key fields: address, phone, email. Surface significant divergences. Use Registry as a signal for where our data may be out of date — but not as a bulk source of truth. JD Financial records cannot be edited directly.

---

## Step 3.8 — Track Cleanup Progress

Capture before/after counts for each cleanup pass using the DQ report (`data_quality_snapshot` and `contact_issues` tables). Run the same validation queries before and after each pass and record the delta in `docs/update-log.md`.

**Open question:** Does cleanup reporting need to be presentable to management/staff, or is internal tracking sufficient?

---

## Open Decisions Summary

| Decision | Impact |
|---|---|
| Inactivation cutoff date | Step 3.1 cannot run without it |
| C-type linkage level | Must be set before Phase 4 uploads |
| Employee linkage scope | Affects upload batches and DQ metric denominators |
| "Accounts Payable" handling | Needs resolution before Phase 4 uploads |
| Email validation approach (regex vs. API) | Cost/quality tradeoff for Phase 4 match rates |
