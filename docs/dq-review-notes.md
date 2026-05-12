# Data Quality Review Notes

**Started:** 2026-05-11  
**Source:** Power BI DQ report built on `data_quality_snapshot` table  
**Purpose:** Track findings and follow-up actions from metric-by-metric review of the first snapshot.

Status key: `[ ]` not reviewed · `[x]` reviewed, no action · `[!]` reviewed, action needed · `[?]` reviewed, question outstanding

---

## 1. Linkage Quality

| Status | Metric | Finding | Follow-up |
|---|---|---|---|
| `[!]` | `linked_count` — % linked by type (B/I/C) | Informational only — not an issue metric; including it in issue rate numerator muddies the calculation. Denominator is higher than completeness metrics — ~2 extra contacts unaccounted for | Investigate why `contact_linkage` denominator exceeds `contact_enriched` count; likely a fan-out from the LEFT JOIN to `customer_cross_ref` producing duplicate rows for contacts with multiple cross-ref entries |
| `[!]` | `unlinked_count` — unlinked by type | Values look correct relative to linked count; this one IS an issue metric. Shares the same inflated denominator issue. | Same investigation as `linked_count` |
| `[x]` | `ckc_id_no_cross_ref` — has Ckc_Id but no cross_ref | Looks correct | |
| `[x]` | `type_mismatch_linkage` — C at entity level / B·I at contact level | Logic was inverted — was flagging correct linkages as mismatches. Corrected: C with `contact_id = 0 / NULL` is now a mismatch; B/I with `contact_id != 0` is now a mismatch. Awaiting re-run to verify actual rate. | See Action Item #14 — verify denominator consistency across linkage metrics |
| `[ ]` | `duplicate_entity_id` — entity IDs with 2+ linked contacts | | |
| `[!]` | `orphan_cross_ref` — cross_ref entries with no active EQUIP contact | Count inflated — query is not filtering to Hutson linkages only | Add `cross_ref_description = 'HUTSON INC Dealer XREF'` filter to both the numerator and denominator; exclude EDA and other cross-ref types |

**Notes:**

---

## 2. Registry Parity

### Field-level parity (match / mismatch / EQUIP-only / Registry-only / both-null)

| Status | Field | Finding | Follow-up |
|---|---|---|---|
| `[!]` | `company_name` (B) | Denominator only 144 — B-only scope is too narrow; C contacts (business contacts linked to a company entity) also carry company names and should be included in the comparison | See Action Item #8 — evaluate expanding business field parity to include C contacts |
| `[!]` | `first_name` (I, C) | Missing from report — rolling into blank metric bucket | Same fix |
| `[!]` | `last_name` (I, C) | Missing from report — rolling into blank metric bucket | Same fix |
| `[!]` | `email` | Missing from report — rolling into blank metric bucket | Same fix |
| `[!]` | `business_phone` | `equip_only` outcome at ~93% — very high; parity logic needs re-examination | See Action Item #13 — verify phone concatenation format matches EQUIP storage |
| `[!]` | `private_phone` | Missing from report — rolling into blank metric bucket | Same fix |
| `[!]` | `mobile_phone` | Missing from report — rolling into blank metric bucket | Same fix |
| `[!]` | `street` | Missing from report — rolling into blank metric bucket | Same fix |
| `[!]` | `city` | Missing from report — rolling into blank metric bucket | Same fix |
| `[!]` | `state` | Missing from report — rolling into blank metric bucket | Same fix |
| `[!]` | `zip` | High mismatch rate — likely inflated by Registry storing ZIP+4 (e.g., `42101-1234`) vs. EQUIP 5-digit only | See Action Items #11 and #12 — truncate comparison to 5 digits and update `zip_not_5digits` to accept ZIP+4 |
| `[!]` | `country` | Missing from report — rolling into blank metric bucket | Same fix |

### Priority parity metrics

| Status | Metric | Finding | Follow-up |
|---|---|---|---|
| `[!]` | `phys_addr_certified_mismatch` — Registry USPS-certified, EQUIP differs | ~100% issue rate — exact-string equality between EQUIP and USPS-certified Registry address will almost never match without copying Registry data into EQUIP | See Action Item #10 — evaluate dropping this metric entirely |
| `[!]` | `address_confirmed_undeliverable` — Registry flagged undeliverable | 39 / 13,015 — denominator unexpectedly low (~13K vs ~58K linked contacts) | See Action Item #16 — investigate whether the denominator is unintentionally scoped to contacts with a non-null physical address or some other sub-population |
| `[!]` | `registry_oob_equip_active` — Registry OOB, EQUIP still active (B) | ~110 numerator — unclear what population this represents | Confirm numerator = B contacts where Registry `out_of_busn_ind = 'Y'` AND EQUIP active, and denominator = all linked B contacts |
| `[!]` | `registry_deceased_equip_active` — Registry deceased, EQUIP still active (I, C) | 410 / 28,849 — verify denominator is linked I/C contacts only, not all Registry deceased or all inactive contacts | See Action Item #15 — confirm denominator scope |
| `[!]` | `equip_inactive_reason_mismatch` — inactive reason conflicts with Registry flag | 11 / 34 — unclear what these two populations are | Confirm numerator = inactive EQUIP contacts where `Inactive_Reason` conflicts with Registry flag, denominator = all linked inactive contacts; verify `Inactive_Reason` field name is correct in the query |

**Notes:** Blank/unknown metric name appearing in Power BI under parity — 645K numerator / 1.8M denominator. None of the field-level parity metrics (company_name, first_name, email, phone, address, etc.) are visible in the report — strongly suggests all of them are rolling into this blank bucket. Root cause is almost certainly the `field_name + '_' + parity_result` concatenation in Section 2 producing NULL when either side is NULL (T-SQL string + NULL = NULL). Fix: wrap both sides with `ISNULL(..., '')` or use `CONCAT()` instead of `+`. The 645K / 1.8M volume is consistent with 12 fields × 5 parity outcomes × all linked contacts.

---

## 3. Completeness

| Status | Metric | Finding | Follow-up |
|---|---|---|---|
| `[x]` | `missing_first_name` (I, C) | Looks correct | |
| `[x]` | `missing_last_name` (I, C) | Looks correct | |
| `[x]` | `missing_company_name` (B) | Looks correct | |
| `[x]` | `missing_street` | Looks correct | |
| `[x]` | `missing_city` | Looks correct | |
| `[x]` | `missing_state` | Looks correct | |
| `[x]` | `missing_zip` | Looks correct | |
| `[x]` | `missing_country` | Looks correct | |
| `[x]` | `missing_email` | Looks correct | |
| `[x]` | `missing_all_phones` | Looks correct | |
| `[x]` | `no_contact_info` — no phone AND no email | Looks correct | |

**Notes:** Report values look correct. Still need to do a code review pass on each metric's query logic — see action item #5.

---

## 4. Field Quality

**Section-level note:** Mixed denominators across field quality metrics — some use total active contacts, others use only contacts where the field has a value. For example, `email_invalid_format` shows 333/561K (total contacts) but only ~75K contacts have an email, making the issue rate misleadingly small. Metrics that check format or pattern validity should denominate against contacts with a value in that field, not the full population. Need to audit every metric in this section and align denominator scope — likely requires adding `WHERE <field> IS NOT NULL` to the inner subquery for any check that only applies to populated fields.

### 4a–4c Name / Company Issues

| Status | Metric | Finding | Follow-up |
|---|---|---|---|
| `[!]` | `placeholder_name` | Valid list is too narrow — only covers literal "FIRSTNAME", "FIRST NAME", "FNAME", etc. | See Action Item #19 — add NONE, UNKNOWN, N/A, NA, NOT APPLICABLE to the pattern list |
| `[ ]` | `name_all_same_char` | | |
| `[ ]` | `name_numeric_only` | | |
| `[ ]` | `status_text_in_name` | | |
| `[ ]` | `status_text_in_company` | | |
| `[ ]` | `status_text_in_street` | | |
| `[ ]` | `dba_in_company_name` | | |
| `[ ]` | `test_record` | | |
| `[ ]` | `contact_type_field_mismatch` — B has name but no company, or I/C has company but no name | | |
| `[ ]` | `prefix_in_name` | | |
| `[ ]` | `suffix_in_surname` | | |
| `[ ]` | `combined_names_in_name` | | |
| `[ ]` | `familiar_name_pattern` — e.g., "Billy (Joe)" | | |

### 4d Email

| Status | Metric | Finding | Follow-up |
|---|---|---|---|
| `[ ]` | `email_invalid_format` | | |
| `[ ]` | `email_placeholder` | | |

### 4e Phone

| Status | Metric | Finding | Follow-up |
|---|---|---|---|
| `[ ]` | `biz_phone_sequential` | | |
| `[ ]` | `biz_phone_repeated_digit` | | |
| `[ ]` | `biz_phone_wrong_length` | | |
| `[ ]` | `priv_phone_sequential` | | |
| `[ ]` | `priv_phone_repeated_digit` | | |
| `[ ]` | `priv_phone_wrong_length` | | |
| `[ ]` | `mob_phone_sequential` | | |
| `[ ]` | `mob_phone_repeated_digit` | | |
| `[ ]` | `mob_phone_wrong_length` | | |

### 4f Address Format

| Status | Metric | Finding | Follow-up |
|---|---|---|---|
| `[ ]` | `placeholder_street` | | |
| `[ ]` | `placeholder_city` | | |
| `[ ]` | `placeholder_state` | | |
| `[ ]` | `state_not_2char` | | |
| `[ ]` | `country_not_2char` | | |
| `[ ]` | `zip_not_5digits` | | |

### 4g Coded Fields (Prefix / Generation / Suffix)

| Status | Metric | Finding | Follow-up |
|---|---|---|---|
| `[!]` | `title_unrecognized` | Not yet reviewed | Confirm denominator is scoped to non-null title only; run distinct values query to identify unrecognized titles and determine which should be added to the valid list |
| `[!]` | `generation_unrecognized` | Not yet reviewed | Same as suffix — confirm denominator scope and review distinct unrecognized values before deciding on list additions |
| `[!]` | `suffix_unrecognized` | 71/73 unrecognized — only 73 contacts have a suffix value at all | (1) Confirm denominator is scoped to non-null Suffix only; (2) Run `SELECT DISTINCT Suffix, COUNT(*) FROM Equip.contact WHERE Suffix IS NOT NULL GROUP BY Suffix ORDER BY COUNT(*) DESC` to review the 71 unrecognized values and determine which should be added to the valid list |

### 4h Contact Code Integrity

| Status | Metric | Finding | Follow-up |
|---|---|---|---|
| `[x]` | `invalid_branch` — contact assigned to closed/invalid branch code | 17% issue rate — expected, looks correct | |
| `[ ]` | `contact_code_duplicate_normalized` | | |
| `[ ]` | `contact_code_has_whitespace` | | |
| `[ ]` | `contact_code_non_alphanumeric` | | |

**Notes:**

---

## 5. Account Staleness

| Status | Bucket | Finding | Follow-up |
|---|---|---|---|
| `[!]` | `No Account` — contact has no ArMaster record | ~100% issue rate (69,192 / 69,224) — informational, not an issue metric | Mixed denominators across all staleness buckets — same aggregation problem as match readiness; investigate window function partition |
| `[!]` | `Never Transacted` — has ArMaster, no transaction history | Informational, not an issue metric | Verify query is scoped to contacts with an account only — should exclude No Account contacts; confirm the join to last_tx correctly returns NULL only for contacts where an ArMaster record exists but no transaction rows are found |
| `[!]` | `0-1yr` | Informational | Mixed denominator values |
| `[!]` | `1-2yr` | Informational | Mixed denominator values |
| `[!]` | `2-3yr` | Informational | Mixed denominator values |
| `[!]` | `3-4yr` | Informational | Mixed denominator values |
| `[!]` | `4-5yr` | Informational | Mixed denominator values |
| `[!]` | `5+yr` — primary inactivation candidates | Informational | Mixed denominator values |

**Staleness × Decile matrix observations:**

**Notes:**

---

## 6. Match Readiness

| Status | Tier | Finding | Follow-up |
|---|---|---|---|
| `[!]` | Tier 1 — Strong (name + full address) | Informational, not an issue metric | Denominators differ across tiers — expected all four to share the same base (total unlinked contacts). Investigate whether the window function partition or Power BI aggregation is causing the split. |
| `[!]` | Tier 2 — Partial (name + partial address or contact info) | Informational, not an issue metric | Same denominator issue |
| `[!]` | Tier 3 — Name Only | Informational, not an issue metric | Same denominator issue |
| `[!]` | Tier 4 — No Name | Informational, not an issue metric | Same denominator issue |

**Notes:**

---

## Open Action Items

Consolidated list of follow-up tasks surfaced during review. Add rows as you go.

| # | Category | Action | Priority | Status |
|---|---|---|---|---|
| 1 | Report | Build a metric dimension table in Power BI using the labels and definitions in the Metric Dimension Reference section below — gives every metric a clean display name and tooltip/description in the report | Medium | `[x]` |
| 3 | Match Readiness / Staleness | Mixed denominators across tiers and staleness buckets — all buckets within a category should share the same base so they sum to 100%. Likely the same root cause: window function partition in the snapshot query, or Power BI double-counting pre-aggregated denominators when rolling up across dimension slices. Investigate both sections together. | Medium | `[x]` |
| 7 | Data Model | Build a per-contact issue mapping table (`dq_contact_issues`) that is created/overwritten with each snapshot run. Schema: `snapshot_date`, `metric_name`, `contact_code`. One row per contact per active issue. Joinable to `Equip.contact` on `contact_code` to get full account details. Enables filtering by issue in Power BI to see exactly which contacts are affected — the aggregated snapshot table only stores counts; this provides the drill-through detail layer. | High | `[ ]` |
| 6 | Report / Linkage Snapshot | Add total active contact count as a headline metric in the DQ report. Consider consolidating the existing linkage snapshot report into this one. Before doing so, correct the linkage snapshot: (1) switch from EQUIP `Ckc_Id`-based linked count to `customer_cross_ref`-based count to match the DQ snapshot approach, and (2) confirm the snapshot is counting contacts, not accounts — Deere tracks linkage at the contact level | High | `[ ]` |
| 5 | All Categories | Do a code review pass on every metric's query logic in `dq-snapshot.sql` — report values may look plausible but the underlying SQL conditions should be verified individually (correct field, correct scope, correct null handling, correct denominator population) | Low | `[ ]` |
| 4 | Staleness | Verify `Never Transacted` is scoped to contacts with an ArMaster record only — the `last_tx` LEFT JOIN returns NULL for both no-account contacts and contacts with an account but no transactions; confirm the bucket assignment logic separates these two cases correctly | Medium | `[x]` |
| 2 | Metric Dim | Add an `is_issue` flag to the metric dimension table to distinguish true issue metrics (numerator = problem count, drives issue rate) from informational metrics (e.g., `linked_count` — not a problem, but muddies a global issue rate if included). Power BI issue rate measure should filter to `is_issue = true` before dividing numerator by denominator. | Medium | `[x]` |
| 9 | Registry Parity | Verify outcome totals equal denominator for every parity field. For each field and dimension slice, the sum of all five outcomes (match + mismatch + equip_only + registry_only + both_null) should equal the denominator. Query the snapshot table grouping by `metric_name` prefix and dim columns, sum numerators across all five outcome suffixes, and confirm the total matches the stored denominator. Flag any field where they diverge — indicates a contact is being double-counted or dropped. Apply the same total-must-equal-denominator check to other metric categories as well. | Medium | `[x]` |
| 8 | Registry Parity | Expand business field parity scope to include C contact types. `company_name` currently filters to `Business_Individual = 'B'` only — denominator was only 144, suggesting most business contacts (C type) are excluded. C contacts are linked to a business entity and also carry company names. Evaluate whether `company_name` and other fields shared by businesses and their contacts (`street`, `city`, `state`, `zip`, `country`) should include `Business_Individual IN ('B', 'C')` in their scope filter. | Medium | `[ ]` |
| 10 | Registry Parity | Evaluate dropping `phys_addr_certified_mismatch` — near-100% issue rate. Exact-string equality between EQUIP and a USPS-certified Registry address will almost never match without copying Registry data directly into EQUIP. Low actionability as a mismatch metric. Consider replacing with an informational flag ("has USPS-certified Registry address") rather than a parity check. | Low | `[ ]` |
| 11 | Registry Parity | Fix `zip_*` parity comparison to compare only the first 5 digits — Registry stores ZIP+4 (e.g., `42101-1234`) while EQUIP typically stores 5-digit zip only. Exact equality artificially inflates the mismatch rate. Change the parity logic to compare `LEFT(pcode, 5)` vs `LEFT(reg_pcode, 5)` (T-SQL) or `SUBSTRING(pcode, 1, 5)` (PySpark). | Medium | `[ ]` |
| 12 | Field Quality | Update `zip_not_5digits` metric to accept 5-digit OR 9-digit (ZIP+4) as valid — currently flags all ZIP+4 values as invalid. A 9-digit zip matching `NNNNN-NNNN` or `NNNNNNNNN` is a valid format and should not be counted as an issue. Related to Action Item #11. | Low | `[ ]` |
| 13 | Registry Parity | Re-examine `business_phone` parity — `equip_only` outcome at ~93% is very high. Verify the concatenation logic that combines Registry `work_area_cd` + `work_phone_num` produces the same format as EQUIP's `BusinessPhone` (10-digit, no separators). Possible issues: area code stored with separators, leading zeros dropped, or Registry returning empty string vs NULL for one component. | Medium | `[ ]` |
| 14 | Linkage Quality | Investigate varying denominators across linkage metrics — `type_mismatch_linkage`, `duplicate_entity_id`, `orphan_cross_ref`, and `ckc_id_no_cross_ref` show denominators ranging from 58,778 to 58,831. Each metric likely uses a slightly different base population (e.g., all active contacts vs. linked-only vs. cross_ref entries). Document the intended denominator for each and confirm queries are using the correct scope. | Medium | `[ ]` |
| 15 | Registry Parity | Verify denominator for `registry_deceased_equip_active` — observed 410 / 28,849. Confirm denominator is all linked active I/C contacts, not all Registry-marked-deceased contacts regardless of linkage or all inactive contacts. If the 28,849 figure is correct it represents linked I/C contacts which is plausible — confirm the query filter matches that intent. | Medium | `[ ]` |
| 16 | Registry Parity | Investigate `address_confirmed_undeliverable` denominator — observed 39 / 13,015. With ~58K linked contacts the denominator should be ~58K unless the metric intentionally scopes to a sub-population (e.g., contacts with a non-null physical address). Review the query and confirm the denominator is the intended base population; correct if it is unintentionally filtering. | Medium | `[ ]` |
| 17 | Field Quality | Expand valid-value lists for `suffix_unrecognized`, `title_unrecognized`, and `generation_unrecognized` — all three show high error rates at low total volume, suggesting the seed lists are too narrow rather than genuine data issues. Run `SELECT DISTINCT <field>, COUNT(*) FROM Equip.contact WHERE <field> IS NOT NULL GROUP BY <field> ORDER BY 2 DESC` for each field, review the distinct unrecognized values, and add legitimate values to the valid list in the snapshot code before treating these as actionable. | Medium | `[ ]` |
| 18 | Field Quality | Add a new `placeholder_company_name` metric for B contacts — check for values like `N/A`, `NA`, `NONE`, `UNKNOWN`, `NOT APPLICABLE`, `BLANK` in the `company_name` field. Mirror the existing `placeholder_name` pattern check but scoped to company name only. | Medium | `[ ]` |
| 19 | Field Quality | Expand `placeholder_name` check to include generic null-substitute strings — add `NONE`, `UNKNOWN`, `N/A`, `NA`, `NOT APPLICABLE` to the current pattern list that already covers `FIRSTNAME`, `FIRST NAME`, `FNAME`, `LASTNAME`, `LAST NAME`, `LNAME`. These are equally clear placeholder entries that should be treated as effectively missing. | Medium | `[ ]` |

---

---

## Metric Dimension Reference

Authoritative label and definition for every `metric_name` value in `data_quality_snapshot`. Intended as the source of truth for Power BI display names, tooltips, and a future dim table.

Columns: **metric_name** (snapshot value) · **Label** (clean Power BI display name) · **Definition** (what the rate means) · **Logic Notes** (how the check works; known caveats)

---

### Linkage Quality

| metric_name | Label | Definition | Logic Notes |
|---|---|---|---|
| `linked_count` | Linked Contacts | Count of active contacts with a matching `customer_cross_ref` entry | Sentinel entity ID 999999998 excluded |
| `unlinked_count` | Unlinked Contacts | Count of active contacts with no `cross_ref` match | Complement of `linked_count`; denominator = all active contacts |
| `ckc_id_no_cross_ref` | Ckc_Id Without Cross-Ref | Contacts that have a `Ckc_Id` value in EQUIP but no matching Registry linkage | Residual from Phase 1.1; denominator = contacts where `Ckc_Id IS NOT NULL` |
| `type_mismatch_linkage` | Linkage Type Mismatch | Linked contacts where the linkage level (entity vs. contact) doesn't match the contact type (B/I vs. C) | C should have non-zero `contact_id` (linked as business contact); B/I should have `contact_id = 0` or null (entity-only linkage). Logic was previously inverted and has been corrected. |
| `duplicate_entity_id` | Duplicate Entity IDs | Entity IDs in the Registry that are linked to 2+ distinct EQUIP contacts | Phase 6 cleanup targets; denominator = distinct entity IDs among linked contacts |
| `orphan_cross_ref` | Orphan Cross-Ref Entries | `cross_ref` entries whose `cross_ref_number` has no matching active EQUIP contact | Must filter to `cross_ref_description = 'HUTSON INC Dealer XREF'` only — current query includes all cross-ref types and inflates the count |

---

### Registry Parity

Parity metrics are split into one row per outcome. Each `metric_name` follows the pattern `<field>_<outcome>`.

**Outcomes:** `match` · `mismatch` · `equip_only` (EQUIP has value, Registry null) · `registry_only` (Registry has value, EQUIP null) · `both_null`

| metric_name prefix | Label | Definition | Logic Notes |
|---|---|---|---|
| `company_name_*` | Company Name Parity | EQUIP `company_name` vs. Registry `nm1_txt` | B contacts only; case-insensitive compare |
| `first_name_*` | First Name Parity | EQUIP `name` vs. Registry `first_nm` | I, C contacts only |
| `last_name_*` | Last Name Parity | EQUIP `surname` vs. Registry `last_nm` | I, C contacts only |
| `email_*` | Email Parity | EQUIP `email_address` vs. Registry `email_addr_txt` | Case-insensitive; all contact types |
| `business_phone_*` | Business Phone Parity | EQUIP `BusinessPhone` vs. Registry `work_area_cd` + `work_phone_num` | Registry area + number concatenated to compare with EQUIP 10-digit string |
| `private_phone_*` | Home Phone Parity | EQUIP `PrivatePhone` vs. Registry `home_area_cd` + `home_phone_num` | Same concatenation logic |
| `mobile_phone_*` | Mobile Phone Parity | EQUIP `MobilePhone` vs. Registry `mobile_area_cd` + `mobile_phone_num` | Same concatenation logic |
| `street_*` | Street Parity | EQUIP `street` vs. Registry `phys_street1_txt` | Case-insensitive |
| `city_*` | City Parity | EQUIP `city` vs. Registry `phys_city` | Case-insensitive |
| `state_*` | State Parity | EQUIP `state` vs. Registry `phys_state_prov_cd` | Case-insensitive |
| `zip_*` | Zip Code Parity | EQUIP `pcode` vs. Registry `phys_postal_cd` | Case-insensitive |
| `country_*` | Country Parity | EQUIP `country` (defaulted to `US`) vs. Registry `phys_iso2_cntry_cd` | US default applied to EQUIP side only for this comparison |

**Priority parity metrics:**

| metric_name | Label | Definition | Logic Notes |
|---|---|---|---|
| `phys_addr_certified_mismatch` | Certified Address Mismatch | Linked contacts where Registry has a USPS-certified address that differs from EQUIP | Denominator = linked contacts with `phys_postal_certified = 'CERTIFIED'`; high-confidence signal that EQUIP is out of date |
| `address_confirmed_undeliverable` | Confirmed Undeliverable Address | Linked contacts where Registry has flagged the physical or mailing address as undeliverable | `phys_undeliverable_ind = 'Y'` OR `mail_undeliverable_ind = 'Y'`; denominator = all linked contacts |
| `registry_oob_equip_active` | Registry OOB, EQUIP Active | B contacts that Registry marks as out of business but EQUIP still shows as active | Candidate for EQUIP inactivation review |
| `registry_deceased_equip_active` | Registry Deceased, EQUIP Active | I/C contacts that Registry marks as deceased but EQUIP still shows as active | Candidate for EQUIP inactivation review |
| `equip_inactive_reason_mismatch` | Inactive Reason Mismatch | Inactive EQUIP contacts where the `Inactive_Reason` conflicts with the Registry status flag | e.g., reason = "Out of Business" but Registry `out_of_busn_ind <> 'Y'` |

---

### Completeness

| metric_name | Label | Definition | Logic Notes |
|---|---|---|---|
| `missing_first_name` | Missing First Name | I/C contacts with null/blank `name` field | Pre-normalized via `NULLIF(LTRIM(RTRIM(...)), '')` |
| `missing_last_name` | Missing Last Name | I/C contacts with null/blank `surname` field | Same normalization |
| `missing_company_name` | Missing Company Name | B contacts with null/blank `company_name` | Same normalization |
| `missing_street` | Missing Street | Contacts with null/blank `street` | All contact types |
| `missing_city` | Missing City | Contacts with null/blank `city` | All contact types |
| `missing_state` | Missing State | Contacts with null/blank `state` | All contact types |
| `missing_zip` | Missing Zip Code | Contacts with null/blank `pcode` | All contact types |
| `missing_country` | Missing Country | Contacts with null/blank `country` | No US default applied here — raw null check |
| `missing_email` | Missing Email | Contacts with null/blank `email_address` | All contact types |
| `missing_all_phones` | Missing All Phones | Contacts with all three phone fields null/blank | `BusinessPhone` AND `PrivatePhone` AND `MobilePhone` all null |
| `no_contact_info` | No Contact Info | Contacts with no phone and no email | Hardest to match in the linkage tool; subset of `missing_all_phones` |

---

### Field Quality

#### Name / Company

| metric_name | Label | Definition | Logic Notes |
|---|---|---|---|
| `placeholder_name` | Placeholder Name | I/C contacts where first or last name is a known placeholder value | e.g., "FIRSTNAME", "FIRST NAME", "FNAME" |
| `name_all_same_char` | Repeated-Character Name | Name field consists of a single character repeated (e.g., "XXXXX", ".....") | Applied to first/last for I/C; company for B |
| `name_numeric_only` | Numeric-Only Name | Name field contains only digits | Applied to first/last for I/C; company for B |
| `status_text_in_name` | Status Text in Name | I/C first or last name contains alert/status keywords | Patterns: DECEASED, OUT OF BUSINESS, DO NOT USE, INACTIVE, CLOSED, FARM PLAN |
| `status_text_in_company` | Status Text in Company Name | B company name contains alert/status keywords | Adds `OOB` (standalone) to the pattern list |
| `status_text_in_street` | Status Text in Street | Street field contains alert/status keywords | Subset of patterns — OOB and FARM PLAN excluded |
| `dba_in_company_name` | DBA Pattern in Company Name | B company name contains "DBA", "D/B/A", or "DOING BUSINESS AS" | Data belongs in the `Doing_Business_As` field |
| `test_record` | Test / Dummy Record | Name or company matches known test-record values | e.g., TEST, TESTING, TEMP, DUMMY, SAMPLE |
| `contact_type_field_mismatch` | Contact Type Field Mismatch | B has name but no company, or I/C has company but no name | Likely miscoded `Business_Individual` value |
| `prefix_in_name` | Prefix in First Name | I/C first name starts with a title prefix (Mr., Mrs., Dr., etc.) | Data belongs in the `title` field |
| `suffix_in_surname` | Suffix in Last Name | I/C last name ends with a generation or credential suffix | e.g., JR, SR, II, MD, PHD; data belongs in `Generation` or `Suffix` field |
| `combined_names_in_name` | Combined Names in First Name | I/C first name contains "&", "AND", "/", or "OR" | Likely two people in one record; should be separate contacts |
| `familiar_name_pattern` | Familiar Name in Parentheses | I/C first name contains a parenthetical, e.g., "Billy (Joe)" | Common data entry pattern; not structurally invalid but worth reviewing |

#### Email

| metric_name | Label | Definition | Logic Notes |
|---|---|---|---|
| `email_invalid_format` | Invalid Email Format | Email doesn't match `%@%.%` pattern | Catches missing `@` or missing domain dot |
| `email_placeholder` | Placeholder Email | Email matches a known placeholder domain pattern | e.g., noemail@, test@test, none@none, noreply@ |

#### Phone (applied identically to all three phone fields)

| metric_name | Label | Definition | Logic Notes |
|---|---|---|---|
| `biz_phone_sequential` | Business Phone — Sequential | `BusinessPhone = '1234567890'` | Known placeholder pattern |
| `biz_phone_repeated_digit` | Business Phone — Repeated Digit | 10-digit phone where all digits are the same | e.g., 0000000000, 5555555555 |
| `biz_phone_wrong_length` | Business Phone — Wrong Length | Phone length is not 10 or 11 digits | 11-digit is valid if it starts with `1` (country code) |
| `priv_phone_sequential` | Home Phone — Sequential | Same check on `PrivatePhone` | |
| `priv_phone_repeated_digit` | Home Phone — Repeated Digit | Same check on `PrivatePhone` | |
| `priv_phone_wrong_length` | Home Phone — Wrong Length | Same check on `PrivatePhone` | |
| `mob_phone_sequential` | Mobile Phone — Sequential | Same check on `MobilePhone` | |
| `mob_phone_repeated_digit` | Mobile Phone — Repeated Digit | Same check on `MobilePhone` | |
| `mob_phone_wrong_length` | Mobile Phone — Wrong Length | Same check on `MobilePhone` | |

#### Address Format

| metric_name | Label | Definition | Logic Notes |
|---|---|---|---|
| `placeholder_street` | Placeholder Street | Street matches a known placeholder value | e.g., N/A, NONE, UNKNOWN, NO ADDRESS |
| `placeholder_city` | Placeholder City | City matches a known placeholder value | e.g., N/A, NONE, UNKNOWN |
| `placeholder_state` | Placeholder State | State matches a known placeholder value | e.g., N/A, XX, ZZ |
| `state_not_2char` | State Not 2 Characters | State field is non-null but not exactly 2 characters | Catches written-out state names; denominator = non-null state |
| `country_not_2char` | Country Not 2 Characters | Country field is non-null but not exactly 2 characters | Catches "UNITED STATES", "USA", etc. |
| `zip_not_5digits` | Zip Not 5 Digits | US zip code doesn't match 5-digit or 5+4 format | US-only (country defaulted to US); denominator = non-null zip on US contacts |

#### Coded Fields

| metric_name | Label | Definition | Logic Notes |
|---|---|---|---|
| `title_unrecognized` | Unrecognized Prefix (title) | `title` field contains a value not in the known valid prefix list | Seed list: Mr, Mrs, Ms, Dr, Rev, Prof, Capt, etc. Expand after Registry distinct-value query |
| `generation_unrecognized` | Unrecognized Generation | `Generation` field contains a value not in the known valid list | Valid: Jr, Jr., Junior, Sr, Sr., Senior, II, III, IV, V |
| `suffix_unrecognized` | Unrecognized Suffix | `Suffix` field contains a value not in the known valid credential list | Seed list: MD, DO, DDS, JD, CPA, RN, etc. Wide net — review results before bulk action |

#### Contact Code Integrity

| metric_name | Label | Definition | Logic Notes |
|---|---|---|---|
| `invalid_branch` | Invalid Branch Code | Contact assigned to a known closed or invalid `TERRITORY` code | Hard-coded list of 10 closed branches until dim table is available |
| `contact_code_duplicate_normalized` | Duplicate Contact Code (Normalized) | `contact_code` resolves to the same value as another active contact after uppercasing and trimming | Catches case/whitespace variants that share a `cross_ref` key |
| `contact_code_has_whitespace` | Contact Code Has Whitespace | `contact_code` contains leading, trailing, or embedded whitespace | Can cause cross_ref join failures |
| `contact_code_non_alphanumeric` | Contact Code Has Non-Alphanumeric Characters | `contact_code` contains characters outside A–Z and 0–9 | Superset of whitespace check — both are tracked separately to distinguish failure types |

---

### Staleness

The `metric_name` in the snapshot IS the staleness bucket value. All active non-employee contacts fall into exactly one bucket.

| metric_name | Label | Definition | Logic Notes |
|---|---|---|---|
| `No Account` | No Account | Contact has no `ArMaster_Customer` record | May be data entry orphans, unfinished records, or structurally expected for some contact types. Investigate by B/I/C breakdown. |
| `Never Transacted` | Never Transacted | Contact has an `ArMaster` record but no transaction history in the revenue dataset | Different from No Account — account exists but was never used |
| `0-1yr` | Active — Last Year | Last transaction within the past 12 months | Healthy active customer baseline |
| `1-2yr` | Lapsing — 1–2 Years | Last transaction 1–2 years ago | Worth monitoring |
| `2-3yr` | Lapsing — 2–3 Years | Last transaction 2–3 years ago | |
| `3-4yr` | At Risk — 3–4 Years | Last transaction 3–4 years ago | |
| `4-5yr` | At Risk — 4–5 Years | Last transaction 4–5 years ago | Approaching inactivation threshold |
| `5+yr` | Stale — 5+ Years | Last transaction more than 5 years ago | Primary inactivation candidates (Phase 2.1) |

---

### Match Readiness

Scope: unlinked active contacts only.

| metric_name | Label | Definition | Logic Notes |
|---|---|---|---|
| `tier_1_strong` | Tier 1 — Strong Match Candidate | Has usable name AND a full or zip-anchored address | Street + city + state, OR street + zip. Tight match likely. |
| `tier_2_partial` | Tier 2 — Partial Match Candidate | Has usable name AND partial address or at least one contact method | Potential match possible; outcome depends on Registry data quality |
| `tier_3_name_only` | Tier 3 — Name Only | Has usable name but no address and no contact info | Unlikely to match without data enrichment |
| `tier_4_no_name` | Tier 4 — No Name | Missing the primary name field(s) for the contact type | Cannot attempt a match regardless of other fields |

---

## Review Session Log

| Date | Metrics Reviewed | Key Takeaways |
|---|---|---|
| 2026-05-11 | Starting review | — |
