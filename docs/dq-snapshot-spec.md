# DQ Snapshot Combined Query Spec

**File to create:** `queries/data-quality/dq-snapshot.sql`  
**Purpose:** Single T-SQL query that produces all `data_quality_snapshot` rows across all 6 metric categories in one execution. Replaces running the individual DQ files separately.  
**Schedule:** Weekly append to `data_quality_snapshot` table in Fabric.

---

## Output Schema

| Column | Description |
|---|---|
| `snapshot_date` | `CAST(GETDATE() AS date)` — date the query ran |
| `metric_category` | `linkage`, `parity`, `completeness`, `field_quality`, `staleness`, `match_readiness` |
| `metric_name` | Specific metric within the category |
| `contact_type` | `B`, `I`, `C`, or `ALL` (entity-level metrics only) |
| `sales_decile` | `D1`–`D10`, `Unranked`, or `ALL` (entity-level metrics only) |
| `staleness_bucket` | `No Account`, `Never Transacted`, `0-1yr`, `1-2yr`, `2-3yr`, `3-4yr`, `4-5yr`, `5+yr`, or `ALL` |
| `branch` | `TERRITORY` from `Equip.ArMaster_Customer` — 3-char branch code, or `NULL` for contacts with no account or no territory set |
| `creation_cohort` | `Pre-2015` (≤2015), `2016-2020`, `2021-2025`, `2026+`, `Unknown` (null date), or `ALL` |
| `numerator` | Count of records with the issue / in the bucket |
| `denominator` | Total active records in scope for that metric × dimension slice |

---

## Dimension Slicing Decision: Option A

Every metric (except the hard exceptions below) is GROUP BY'd across the full dimension set:

```
contact_type × sales_decile × staleness_bucket × creation_cohort
```

This pre-aggregates all combinations at snapshot time so each dimension works independently as a Power BI slicer without needing cross-products at query time.

**Estimated row count:** ~30 metrics × 3 contact types × 11 decile values × 8 staleness buckets × N branch codes × 5 cohorts. Branch adds a multiplier once populated — monitor snapshot table size after first run.

### Exceptions

| Exception | Reason |
|---|---|
| `staleness` section: `staleness_bucket` column = `'ALL'` | `metric_name` IS the staleness bucket; populating the column too would be circular |
| `duplicate_entity_id`, `orphan_cross_ref`: all dims = `'ALL'` | Entity- and Registry-side metrics; no contact-level dimensions available |
| `branch` = NULL for contacts with no account or no TERRITORY set | Stored as NULL in snapshot; label as `'Unassigned'` in Power BI display layer |

### Known Closed / Invalid Branch Codes

Hard-coded until the branch dimension table is available. Contacts assigned to these `TERRITORY` codes are flagged as `4h_invalid_branch` in Section 4 (field quality).

| Code | Location |
|---|---|
| `07` | Cypress IL |
| `13` | Washington IN |
| `52` | Grand Ledge MI |
| `55` | Rosebush MI |
| `61` | Mason MI |
| `63` | Highland MI |
| `64` | Mason E-Commerce MI |
| `67` | Rives Junction MI |
| `70` | Ellsworth MI |
| `71` | Alpena MI |

---

## CTE Architecture

### Tier 1 — Revenue / Dimension Foundation

Expensive CTEs computed once at the top; drive decile and staleness enrichment for every downstream section. Lifted directly from `dq-staleness.sql`.

| CTE | What it does |
|---|---|
| `date_range` / `dr` | Rolling 60-month window bounds (StartDate / EndDate) |
| `account_revenue` | R60 revenue per `Customer_No` across all departments: complete goods (VhStock + VhStockAccess), parts (Invoice module_type `I`), service (Invoice module_type `W`), rental (Rental_History) |
| `revenue_ranked` | `NTILE(10) OVER (ORDER BY TotalRevenue DESC)` — zero-revenue accounts excluded (→ `Unranked`) |
| `last_tx` | `MAX(tx_date)` per `Customer_No` across all departments (same 4-way UNION as account_revenue but for dates, no revenue filter) |

### Tier 2 — Master Contact Base

| CTE | What it does |
|---|---|
| `active_contacts` | All active non-employee contacts with **all field values** needed by any downstream section. Single source of truth; replaces the 4 separate `active_contacts` CTEs across the individual files. Applies: `Inactive_Indicator` filter, `WKMECHFL` + `VhSalman` exclusions. Joins: `ArMaster_Customer` (LEFT JOIN) for `acc_no` and `branch`. See field list below. |
| `contact_enriched` | Joins `active_contacts` → `last_tx` → `revenue_ranked`. Adds `staleness_bucket`, `sales_decile`, `creation_cohort` to every contact. **All metric sections reference this CTE, not `active_contacts` directly.** |

#### `active_contacts` field list

| Field | Source | Notes |
|---|---|---|
| `contact_code` | `Equip.contact` | PK |
| `Business_Individual` | `Equip.contact` | B / I / C |
| `Ckc_Id` | `Equip.contact` | For linkage quality metric 1c |
| `Creation_Date` | `Equip.contact` | Raw — cohort bucketing done in contact_enriched |
| `acc_no` | `ArMaster_Customer.Customer_No` | LEFT JOIN; NULL = No Account. `Customer_No` = `BILL_TO_ACC` on 99.996% of rows (verified) — current join logic valid. |
| `branch` | `ArMaster_Customer.TERRITORY` | `NULLIF(LTRIM(RTRIM(...)), '')` — 3-char branch code. NULL when contact has no account or TERRITORY not set → stored as NULL in snapshot, maps to `'Unassigned'` in Power BI. |
| `first_name` | `c.[name]` | `NULLIF(LTRIM(RTRIM(...)), '')` |
| `last_name` | `c.surname` | `NULLIF(LTRIM(RTRIM(...)), '')` |
| `company_name` | `c.company_name` | `NULLIF(LTRIM(RTRIM(...)), '')` |
| `street` | `c.street` | `NULLIF(LTRIM(RTRIM(...)), '')` |
| `city` | `c.city` | `NULLIF(LTRIM(RTRIM(...)), '')` |
| `state` | `c.state` | `NULLIF(LTRIM(RTRIM(...)), '')` |
| `pcode` | `c.pcode` | `NULLIF(LTRIM(RTRIM(...)), '')` |
| `country` | `c.country` | `NULLIF(LTRIM(RTRIM(...)), '')` — **no US default here** (see fix note below) |
| `biz_phone` | `c.BusinessPhone` | `NULLIF(LTRIM(RTRIM(...)), '')` |
| `priv_phone` | `c.PrivatePhone` | `NULLIF(LTRIM(RTRIM(...)), '')` |
| `mob_phone` | `c.MobilePhone` | `NULLIF(LTRIM(RTRIM(...)), '')` |
| `email` | `c.email_address` | `NULLIF(LTRIM(RTRIM(...)), '')` |
| `title` | `c.title` | Raw — validity checks applied in section 4g |
| `Generation` | `c.Generation` | Raw — validity checks applied in section 4g |
| `Suffix` | `c.Suffix` | Raw — validity checks applied in section 4g |

#### Fix: country normalization

In the individual queries, `country` is computed as `ISNULL(NULLIF(LTRIM(RTRIM(c.country)), ''), 'US')`. This breaks the `missing_country` completeness metric because the field is never NULL after defaulting.

**Resolution:** Store country raw (null-clean, no US default) in `active_contacts`. Apply the US default **only** where needed:
- `active_linked`: `ISNULL(ce.country, 'US') AS country` for parity comparison
- Section 4f zip check: `WHERE ISNULL(country, 'US') = 'US'`

### Tier 3 — Population Subsets

| CTE | Built from | Used by |
|---|---|---|
| `contact_linkage` | `contact_enriched` LEFT JOIN `customer_cross_ref` | Section 1 (linkage) |
| `unlinked_enriched` | `contact_enriched` WHERE NOT EXISTS in `customer_cross_ref` | Section 6 (match readiness) |
| `active_linked` | `contact_enriched` INNER JOIN `customer_cross_ref` + `customer_profile` | Section 2 (parity) |
| `field_parity` | `active_linked` — per-contact per-field parity classification (match / mismatch / equip_only / registry_only / both_null) | Section 2 aggregate |

#### `contact_linkage` notes
- LEFT JOIN `customer_cross_ref` ON `UPPER(cross_ref_number) = UPPER(contact_code)` AND `entity_id <> 999999998`
- Adds: `entity_id`, `contact_id`, `is_linked` (1/0)

#### `active_linked` notes
- INNER JOIN path: `contact_enriched` → `customer_cross_ref` (with `cross_ref_description = 'HUTSON INC Dealer XREF'`) → `customer_profile`
- Carries all EQUIP fields from `contact_enriched` + all Registry fields (normalized via NULLIF)
- Registry fields: `reg_company_name`, `reg_first_name`, `reg_last_name`, `reg_email`, `reg_biz_area`/`num`, `reg_priv_area`/`num`, `reg_mob_area`/`num`, `reg_street`, `reg_city`, `reg_state`, `reg_pcode`, `reg_country`
- Registry quality flags: `phys_postal_certified`, `phys_undeliverable_ind`, `mail_undeliverable_ind`
- Registry status flags: `out_of_busn_ind`, `descd_ind` — required for Section 2 status vs. active parity metrics

#### `inactive_linked` notes
- Parallel to `active_linked` but scoped to **inactive** EQUIP contacts (`Inactive_Indicator = 'I'`)
- Built from `Equip.contact` directly (not `contact_enriched`, which filters to active only)
- Applies same employee exclusions (`WKMECHFL`, `VhSalman`)
- INNER JOIN path same as `active_linked`: `customer_cross_ref` + `customer_profile`
- Fields: `contact_code`, `Business_Individual`, `Inactive_Reason`, `out_of_busn_ind`, `descd_ind`, plus dimension columns (`sales_decile`, `staleness_bucket`, `branch`, `creation_cohort`)
- `sales_decile` and `staleness_bucket` are `'Inactive'` — inactive contacts don't participate in revenue ranking or staleness. `branch` from `ArMaster_Customer` LEFT JOIN. `creation_cohort` bucketed same as active.

#### `field_parity` notes
- One row per contact per field with a `parity_result` label
- 12 fields total: `company_name` (B only), `first_name` / `last_name` (I,C only), `email`, `business_phone`, `private_phone`, `mobile_phone`, `street`, `city`, `state`, `zip`, `country`
- Phone comparison: concatenate Registry area_cd + phone_num and compare to EQUIP's 10-digit string
- Carries `sales_decile`, `staleness_bucket`, `creation_cohort` from `active_linked`

---

## Metric Sections (UNION ALL)

### Section 1: Linkage Quality

`metric_category = 'linkage'` | Source: `contact_linkage`

| metric_name | Numerator | Denominator | Dims |
|---|---|---|---|
| `linked_count` | `SUM(is_linked)` | `COUNT(*)` all active | Full |
| `unlinked_count` | `SUM(1 - is_linked)` | `COUNT(*)` all active | Full |
| `ckc_id_no_cross_ref` | contacts with `Ckc_Id IS NOT NULL AND is_linked = 0` | contacts with `Ckc_Id IS NOT NULL` | Full |
| `type_mismatch_linkage` | C linked at entity level OR B/I linked at contact level | linked contacts only | Full |
| `duplicate_entity_id` | entity_ids with 2+ linked contacts | `COUNT(DISTINCT entity_id)` among linked contacts | ALL dims |
| `orphan_cross_ref` | cross_ref entries with no matching active EQUIP contact | total cross_ref entries (excl sentinel) | ALL dims |

Type-mismatch logic:
- C mismatch: `contact_id <> 0`
- B/I mismatch: `contact_id = 0`

### Section 2: Registry Parity

`metric_category = 'parity'` | Source: `field_parity` + `active_linked` (for priority metrics)

**Field-level rows:** `metric_name = <field_name>_<parity_result>` (e.g., `email_match`, `street_mismatch`)  
Denominator = `SUM(COUNT(*)) OVER (PARTITION BY field_name, contact_type, sales_decile, staleness_bucket, creation_cohort)` — total linked contacts for that field × dim slice across all 5 parity outcomes.

**Priority rows:**

| metric_name | Condition | Denominator |
|---|---|---|
| `phys_addr_certified_mismatch` | `phys_postal_certified = 'CERTIFIED'` AND any address field differs between EQUIP and Registry | Linked contacts where `phys_postal_certified = 'CERTIFIED'` in that dim slice |
| `address_confirmed_undeliverable` | `phys_undeliverable_ind = 'Y'` OR `mail_undeliverable_ind = 'Y'` | All linked contacts in that dim slice |

Priority row denominators require a second pass over `active_linked` (unfiltered) to get the correct base per dim combination. Implementation: pre-aggregate `active_linked` into a supporting CTE before the final UNION ALL — one that counts (a) all linked contacts per dim slice and (b) linked contacts with `phys_postal_certified = 'CERTIFIED'` per dim slice — then join those counts in as the denominator.

**Registry status vs. EQUIP active status (priority rows):**

| metric_name | Condition | Scope | Denominator |
|---|---|---|---|
| `registry_oob_equip_active` | Registry `out_of_busn_ind = 'Y'` AND `ISNULL(c.Inactive_Indicator, 'A') <> 'I'` in EQUIP | B type, linked only | All linked B contacts in that dim slice |
| `registry_deceased_equip_active` | Registry `descd_ind = 'Y'` AND EQUIP active | I, C types, linked only | All linked I/C contacts in that dim slice |
| `equip_inactive_reason_mismatch` | EQUIP `Inactive_Reason = 'Out of Business'` AND Registry `out_of_busn_ind <> 'Y'`, OR EQUIP `Inactive_Reason = 'Deceased'` AND Registry `descd_ind <> 'Y'` | Linked **inactive** contacts only (`Inactive_Indicator = 'I'`) | All linked inactive contacts in that dim slice |

Implementation notes:
- The first two join through `active_linked` (which already filters to active EQUIP contacts via the `Inactive_Indicator` filter on `contact_enriched`) — no filter change needed; the condition is simply `out_of_busn_ind = 'Y'` or `descd_ind = 'Y'`
- The third requires a separate population: linked contacts where `Inactive_Indicator = 'I'`. This is currently excluded from `contact_enriched` (active-only). Add a parallel `inactive_linked` CTE joining inactive contacts to Registry, selecting only `contact_code`, `Business_Individual`, `Inactive_Reason`, `out_of_busn_ind`, `descd_ind`, plus the dimension columns (`sales_decile`, `staleness_bucket`, `branch`, `creation_cohort`)
- `out_of_busn_ind` and `descd_ind` must be added to the `active_linked` SELECT from `customer_profile` (not currently included)

### Section 3: Completeness

`metric_category = 'completeness'` | Source: `contact_enriched`

Uses inner UNION ALL subquery pattern. Each row carries `sales_decile`, `staleness_bucket`, `creation_cohort` from `contact_enriched`. Outer GROUP BY: `metric_name, contact_type, sales_decile, staleness_bucket, creation_cohort`.

Denominator = `COUNT(*)` per group (contacts in scope for that metric in that dim slice).

All fields pre-normalized via NULLIF in `active_contacts`, so checks are simply `IS NULL`.

| metric_name | Scope | Field checked |
|---|---|---|
| `missing_first_name` | I, C | `first_name IS NULL` |
| `missing_last_name` | I, C | `last_name IS NULL` |
| `missing_company_name` | B | `company_name IS NULL` |
| `missing_street` | All | `street IS NULL` |
| `missing_city` | All | `city IS NULL` |
| `missing_state` | All | `state IS NULL` |
| `missing_zip` | All | `pcode IS NULL` |
| `missing_country` | All | `country IS NULL` |
| `missing_email` | All | `email IS NULL` |
| `missing_all_phones` | All | `biz_phone IS NULL AND priv_phone IS NULL AND mob_phone IS NULL` |
| `no_contact_info` | All | all phones null AND `email IS NULL` |

All metrics use `Business_Individual AS contact_type` — including address, phone, and email fields that the individual `dq-completeness.sql` grouped as `'ALL'`. This enables slicing by contact type on every metric in Power BI. Confirmed decision.

### Section 4: Field Quality

`metric_category = 'field_quality'` | Source: `contact_enriched`

Same inner UNION ALL subquery pattern as completeness. Denominator = `COUNT(*)` per group.

| metric_name | Scope | Logic |
|---|---|---|
| `placeholder_name` | I, C | UPPER(LTRIM(RTRIM(`first_name`))) IN (`FIRSTNAME`, `FIRST NAME`, `FIRST`, `FNAME`) OR UPPER(LTRIM(RTRIM(`last_name`))) IN (`LASTNAME`, `LAST NAME`, `LAST`, `LNAME`) |
| `name_all_same_char` | I, C | entire `first_name` or `last_name` is one repeated character (e.g., `X`, `XXXXX`, `.....`) — `REPLACE(name, LEFT(name,1), '') = ''`; subsumes single-char check; also applied to `company_name` for B contacts |
| `name_numeric_only` | I, C | `first_name` or `last_name` contains only digits — `PATINDEX('%[^0-9]%', name) = 0`; catches `123`, `111`, `12345` etc.; also applied to `company_name` for B contacts |
| `status_text_in_name` | I, C | `first_name` or `last_name` LIKE `%DECEASED%`, `%OUT OF BUSINESS%`, `%DO NOT USE%`, `%DONT USE%`, `%DON'T USE%`, `% USE %`, `%INACTIVE%`, `%CLOSED%`, `%FARM PLAN%` |
| `status_text_in_company` | B | `company_name` LIKE same patterns + `% OOB %` (standalone to reduce false positives) |
| `status_text_in_street` | All | `street` LIKE `%DECEASED%`, `%OUT OF BUSINESS%`, `%DO NOT USE%`, `%DONT USE%`, `%DON'T USE%`, `%INACTIVE%`, `%CLOSED%` (no OOB, no FARM PLAN — not relevant to street) |
| `placeholder_street` | All (non-null street) | UPPER(LTRIM(RTRIM(`street`))) IN (`N/A`, `NA`, `NONE`, `UNKNOWN`, `UNK`, `TBD`, `NO ADDRESS`, `ADDRESS`, `NO STREET`, `-`) |
| `placeholder_city` | All (non-null city) | UPPER(LTRIM(RTRIM(`city`))) IN (`N/A`, `NA`, `NONE`, `UNKNOWN`, `UNK`, `TBD`, `NO CITY`, `CITY`, `-`) |
| `placeholder_state` | All (non-null state) | UPPER(LTRIM(RTRIM(`state`))) IN (`N/A`, `NA`, `NONE`, `UNKNOWN`, `UNK`, `XX`, `ZZ`) |
| `dba_in_company_name` | B | `company_name` LIKE `%DBA %`, `%D/B/A%`, `%DOING BUSINESS AS%` |
| `test_record` | All | UPPER(LTRIM(RTRIM(`first_name`))) IN (`TEST`, `TESTING`, `TEMP`, `DUMMY`, `SAMPLE`) OR UPPER(LTRIM(RTRIM(`last_name`))) IN (`TEST`, `TESTING`, `TEMP`, `DUMMY`, `SAMPLE`) OR UPPER(LTRIM(RTRIM(`company_name`))) IN (`TEST`, `TESTING`, `DUMMY`, `SAMPLE`, `TEMP`) |
| `contact_type_field_mismatch` | All | B contact has `first_name` or `last_name` populated but `company_name` IS NULL; OR I/C contact has `company_name` populated but both `first_name` and `last_name` IS NULL — likely miscoded `Business_Individual` value |
| `prefix_in_name` | I, C | `first_name` LIKE `MR.%`, `MR %`, `MRS.%`, `MRS %`, `MS.%`, `MS %`, `DR.%`, `DR %`, `REV.%`, `REV %`, `PROF.%`, `PROF %` |
| `suffix_in_surname` | I, C | `last_name` LIKE `% JR`, `% JR.`, `% SR`, `% SR.`, `% II`, `% III`, `% IV`, `% V`, `% MD`, `% PHD`, `% CPA`, `% ESQ`, `% DDS`, `% DO` |
| `combined_names_in_name` | I, C | `first_name` LIKE `%&%`, `% AND %`, `%/%`, `% OR %` |
| `familiar_name_pattern` | I, C | `first_name` LIKE `%(%)%` |
| `email_invalid_format` | All | `email IS NOT NULL AND email NOT LIKE '%@%.%'` |
| `email_placeholder` | All (non-null email) | LOWER(email) LIKE `noemail@%`, `test@test%`, `none@none%`, `nomail@%`, `donotcontact@%`, `noreply@%` |
| `biz_phone_sequential` | All (non-null) | `biz_phone = '1234567890'` |
| `biz_phone_repeated_digit` | All (non-null) | `LEN = 10 AND biz_phone = REPLICATE(LEFT(biz_phone,1), 10)` |
| `biz_phone_wrong_length` | All (non-null) | `LEN NOT IN (10, 11)` |
| `priv_phone_*` | All (non-null) | Same 3 checks on `priv_phone` |
| `mob_phone_*` | All (non-null) | Same 3 checks on `mob_phone` |
| `state_not_2char` | All (non-null state) | `LEN(state) <> 2` |
| `country_not_2char` | All (non-null country) | `LEN(country) <> 2` |
| `zip_not_5digits` | US contacts, non-null pcode | `pcode` NOT LIKE 5-digit or 5+4 pattern; filter: `ISNULL(country, 'US') = 'US'` |
| `generation_unrecognized` | I, C (non-null, non-blank Generation) | UPPER(LTRIM(RTRIM(Generation))) NOT IN (`JR`, `JR.`, `JUNIOR`, `SR`, `SR.`, `SENIOR`, `II`, `III`, `IV`, `V`) |
| `title_unrecognized` | I, C (non-null, non-blank title) | UPPER(LTRIM(RTRIM(title))) NOT IN known prefix list — see below |
| `suffix_unrecognized` | I, C (non-null, non-blank Suffix) | UPPER(LTRIM(RTRIM(Suffix))) NOT IN known suffix list — see below |
| `invalid_branch` | All (non-null TERRITORY) | `TERRITORY` IN (`07`, `13`, `52`, `55`, `61`, `63`, `64`, `67`, `70`, `71`) — known closed/invalid branch codes; hard-coded until branch dim table available |
| `contact_code_duplicate_normalized` | All | `UPPER(LTRIM(RTRIM(contact_code)))` appears 2+ times among active non-employee contacts — catches both true duplicates and case/whitespace variants that resolve to the same cross_ref key |
| `contact_code_has_whitespace` | All | `PATINDEX('%[ ' + CHAR(9) + CHAR(10) + CHAR(13) + ']%', contact_code) > 0` — leading, trailing, or embedded whitespace |
| `contact_code_non_alphanumeric` | All | `PATINDEX('%[^A-Za-z0-9]%', contact_code) > 0` — any character outside letters and digits (includes whitespace; keep both checks to distinguish failure types) |

#### Known Valid Prefixes (title field)

Seed list — expand after running the Registry distinct-value query (open question in data-quality-plan.md).

```
MR, MR., MRS, MRS., MS, MS., MISS, DR, DR., REV, REV., PROF, PROF.,
CAPT, CAPT., SGT, SGT., COL, COL., MAJ, MAJ., GEN, GEN., HON, HON.
```

Any value not in this list (case-insensitive, trimmed) is flagged as unrecognized. Values like `MR` and `MR.` are both valid — the list covers both punctuated and unpunctuated forms.

#### Known Valid Suffixes (Suffix field)

More open-ended than Generation or Prefix. Seed list covers common professional designations — expand after reviewing actual distinct values from EQUIP and Registry.

```
MD, DO, DDS, DMD, DVM, PHD, PH.D., JD, CPA, RN, NP, PA, PE,
ESQ, ESQ., MBA, CFA, CFP, LCSW, CPCU, FACP, FACS
```

Anything clearly not a credential (e.g., `123 MAIN ST`, `DECEASED`, a full name) is the target. The unrecognized flag casts a wide net — review results before bulk action.

### Section 5: Staleness

`metric_category = 'staleness'` | Source: `contact_enriched`

Each active contact is assigned to exactly one bucket via the staleness_bucket value already computed in `contact_enriched`. No inner subquery needed — direct GROUP BY.

- `metric_name` = `staleness_bucket` value (`No Account`, `Never Transacted`, `0-1yr`, … `5+yr`)
- `staleness_bucket` column = `'ALL'` (circular — the metric_name IS the bucket)
- Denominator: `SUM(COUNT(*)) OVER (PARTITION BY Business_Individual, sales_decile, creation_cohort)` — total contacts in that dim slice across all buckets

### Section 6: Match Readiness

`metric_category = 'match_readiness'` | Source: `unlinked_enriched`

Each unlinked contact is assigned to exactly one tier. Inner subquery computes tier flags; outer GROUP BY aggregates.

| metric_name | Tier | Criteria |
|---|---|---|
| `tier_1_strong` | 1 | Has name AND (street + city + state OR street + zip) |
| `tier_2_partial` | 2 | Has name AND (partial address OR any contact info) |
| `tier_3_name_only` | 3 | Has name, no address, no contact info |
| `tier_4_no_name` | 4 | Missing name regardless of other fields |

Name definition: I/C → both `first_name` and `last_name` non-null. B → `company_name` non-null.

Denominator: `SUM(COUNT(*)) OVER (PARTITION BY Business_Individual, sales_decile, staleness_bucket, creation_cohort)` — total unlinked contacts in that dim slice across all tiers.

---

## What's Excluded

| File | Reason |
|---|---|
| `dq-field-quality-coded-fields.sql` | Diagnostic only — surfaces distinct values, not snapshot-conformant |

---

## Fixes Applied vs. Individual Files

| Issue | Fix |
|---|---|
| `country` defaulted to `'US'` in individual CTEs breaks `missing_country` | Store raw (no US default) in `active_contacts`; apply default only in `active_linked` parity compare and Section 4f zip filter |
| 4 duplicate `active_contacts` CTEs with varying field lists | Single consolidated `active_contacts` CTE carries all fields needed by any section |
| Each individual file uses `CAST(GETDATE() AS date)` independently | Still computed inline per section (no behavioral change — all execute within the same query run) |
| Completeness: address/phone/email use `contact_type = 'ALL'` | Changed to `Business_Individual AS contact_type` to enable full dimensional slicing (Option A) |
| Priority parity denominators (cert mismatch, undeliverable) always 100% — window function partitioned same as GROUP BY | Fixed: cert mismatch denominator = linked contacts with `phys_postal_certified = 'CERTIFIED'` per dim slice; undeliverable denominator = all linked contacts per dim slice. Requires a pre-aggregated `linked_counts` CTE in Tier 3. |
| `duplicate_entity_id` denominator = total active contacts — unrelated population | Fixed: denominator = `COUNT(DISTINCT entity_id)` among linked contacts. Rate now reads "X% of linked entity IDs have multiple EQUIP contacts." |

---

## Open Questions Before / During Implementation

- [ ] **Snapshot table location** — which Fabric workspace/lakehouse hosts `data_quality_snapshot`? Determines how the Fabric pipeline job is configured to run this query.
- [ ] **`title` and `Suffix` valid value lists** — seed lists are in Section 4g above. Expand after running the Registry distinct-value query (open question in data-quality-plan.md). No structural query change needed — just add values to the NOT IN lists.
