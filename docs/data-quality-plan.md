# Data Quality Reporting Plan

**Created:** 2026-04-30  
**Status:** In Planning

---

## Goals

1. **Track data quality trends** — weekly snapshots stored in Fabric, visualized in Power BI to answer "are we improving?"
2. **Surface cleanup targets** — give Phase 2 cleanup work a measurable before/after baseline
3. **Report current state** — a Power BI report covering linkage quality, completeness, field quality, and Registry parity

---

## Architecture

### Snapshot Table (Fabric)
Extend the existing daily linkage snapshot pipeline to also run quality metrics on a **weekly** schedule. Append results to a `data_quality_snapshot` table:

| Column | Description |
|---|---|
| `snapshot_date` | Date the snapshot was taken |
| `metric_category` | e.g., `completeness`, `field_quality`, `parity`, `linkage` |
| `metric_name` | e.g., `null_email`, `invalid_phone_allzeros`, `phys_addr_mismatch` |
| `contact_type` | `B`, `I`, `C`, or `ALL` |
| `sales_decile` | `D1`–`D10` (D1 = highest 5-yr revenue), `Unranked` (no revenue history), or `ALL` |
| `staleness_bucket` | `0-1yr`, `1-2yr`, `2-3yr`, `3-4yr`, `4-5yr`, `5+yr`, `Never`, `No Account`, or `ALL` |
| `branch` | Branch ID from `Equip.contact` territory field, or `ALL` |
| `creation_cohort` | `Pre-2015`, `2015–2020`, `2020–2025`, `2025+`, or `ALL` |
| `numerator` | Count of records with the issue |
| `denominator` | Total active records in scope for that metric |

Store **aggregated counts only** — not per-contact rows. Per-contact detail stays in live Fabric tables for drill-down.

### Aggregation Dimensions

Every metric is pre-aggregated across all dimension combinations at snapshot time. Each dimension can be used independently as a slicer in Power BI.

#### Sales Decile
- Computed with `NTILE(10) OVER (ORDER BY total_5yr_revenue DESC)` — D1 = highest-revenue accounts
- **5-year rolling window** — captures equipment buying cycles; aligns with the 5+ yr staleness inactivation threshold
- Revenue = total across all departments and transaction types (large equipment, parts, service)
- Contacts with no revenue history (No Account, Never Transacted) → `Unranked`, not forced into D10
- Deciles are recomputed each weekly snapshot — a contact's decile can shift as revenue ages out of the 5-year window
- Open question: confirm exact revenue field and table name in the Accounts dataset. See Open Questions.

#### Staleness Bucket
Defined in full in Section 5. Used as both a standalone metric and a cross-dimension for the staleness × decile matrix.

#### Branch
- Branch ID from the territory field on `Equip.contact` (field name TBD — see Open Questions)
- A branch dimension table will be brought into the data model to carry attributes like active/closed status and location name — branch ID is stored in the snapshot table and joined to the dim in Power BI
- 28 active locations + some closed from acquisitions — primarily useful for spotting acquisition data quality patterns; closed/active classification comes from the dim table, not the snapshot

#### Creation Cohort
- Binned from `Equip.contact.Creation_Date`: `Pre-2015`, `2015–2020`, `2020–2025`, `2025+`
- `2025+` isolates the most recent records to see current data entry quality independently
- `2020–2025` is expected to be skewed by acquisitions loaded in 2021 and 2022 — worth filtering by branch to separate acquisition records from organic growth in that window
- Distinguishes legacy data quality debt from ongoing data entry problems: if Pre-2015 records dominate the flags it's historical debt; if 2020–2025 or 2025+ are equally bad it's a process problem

### Power BI
- **Current state:** filter snapshot table to `MAX(snapshot_date)`
- **Trends:** all snapshot rows over time
- Single dataset serves both views — no separate live vs. historical connection needed

---

## Metric Categories

---

### 1. Linkage Quality

**Scope:** All active contacts (`ISNULL(Inactive_Indicator, 'A') <> 'I'`), excluding employees.

| Metric | Query Logic |
|---|---|
| Linked % by type | `cross_ref` join present, broken out by `Business_Individual` (B/I/C) |
| Unlinked count by type | No `cross_ref` entry, by type |
| Duplicate entity IDs | Entity IDs with 2+ EQUIP contacts linked — Phase 6 targets |
| EQUIP has `Ckc_Id`, no `cross_ref` | `Ckc_Id IS NOT NULL` AND no matching `cross_ref` entry — Phase 1.1 residual |
| Orphan `cross_ref` entries | `cross_ref_number` has no matching active EQUIP contact |
| Type-mismatch linkages | C-type linked at entity level (contact_id = 0); B/I linked at contact level (contact_id ≠ 0) |

---

### 2. Registry Parity

**Scope:** Linked contacts only — join `Equip.contact` → `DDP.customer_cross_ref` → `DDP.customer_profile`.

Phone comparison note: Registry stores phones split (`work_area_cd` + `work_phone_num`). Concatenate to compare with EQUIP's stripped 10-digit `BusinessPhone`/`PrivatePhone`/`MobilePhone`.

For each field, track a **4-way breakdown:**
- Match
- Mismatch
- EQUIP only (EQUIP has value, Registry null)
- Registry only (Registry has value, EQUIP null)

#### Field Mapping

| EQUIP Field | Registry Field (`customer_profile`) | Contact Types |
|---|---|---|
| `company_name` | `nm1_txt` | B only |
| `name` (first) | `first_nm` | I, C |
| `surname` (last) | `last_nm` | I, C |
| `email_address` | `email_addr_txt` | All |
| `BusinessPhone` | `work_area_cd` + `work_phone_num` | All |
| `PrivatePhone` | `home_area_cd` + `home_phone_num` | All |
| `MobilePhone` | `mobile_area_cd` + `mobile_phone_num` | All |
| `street` | `phys_street1_txt` | All |
| `city` | `phys_city` | All |
| `state` | `phys_state_prov_cd` | All |
| `pcode` | `phys_postal_cd` | All |
| `country` | `phys_iso2_cntry_cd` | All |

#### Verified Address Flags (high-value signals)
These columns exist in `DDP.customer_profile` — discovered via schema query 2026-04-30:

| Column | Meaning |
|---|---|
| `phys_postal_certified` | USPS-certified physical address (Y/N) |
| `phys_crtfc_dt` | Date physical address was certified |
| `phys_undeliverable_ind` | Physical address confirmed undeliverable (Y/N) |
| `mail_postal_certified` | USPS-certified mailing address |
| `mail_crtfc_dt` | Date mailing address was certified |
| `mail_undeliverable_ind` | Mailing address confirmed undeliverable |

**Priority parity metrics:**
1. Registry has `phys_postal_certified = 'Y'` AND physical address differs from EQUIP → high confidence EQUIP is out of date
2. `phys_undeliverable_ind = 'Y'` or `mail_undeliverable_ind = 'Y'` on a linked contact → EQUIP has a bad address that Registry has confirmed

#### Opt-Out Flags (also in `customer_profile`)
Available but not a primary quality metric. Could be surfaced as informational:
`email_opt_out`, `home_phone_opt_out`, `work_phone_opt_out`, `mobile_opt_out`, `all_opt_out_flg`

---

### 3. Completeness (Null/Blank Counts)

Use `NULLIF(LTRIM(RTRIM(field)), '')` on all fields — EQUIP has both NULLs and empty strings.

| Metric | Scope | Fields |
|---|---|---|
| Missing first name | I, C | `name` |
| Missing last name | I, C | `surname` |
| Missing company name | B | `company_name` |
| Missing street | All | `street` |
| Missing city | All | `city` |
| Missing state | All | `state` |
| Missing zip | All | `pcode` |
| Missing country | All | `country` |
| Missing all phones | All | `BusinessPhone` AND `PrivatePhone` AND `MobilePhone` all null/blank |
| Missing email | All | `email_address` |
| No contact info at all | All | No phone AND no email — hardest to match in linkage tool |

Express each as count + % of active contacts in scope.

---

### 4. Field Quality

All checks scoped to **active** contacts.

#### 4a. Status Text in Wrong Fields
Active contacts where name/company fields contain status text instead of using `Inactive_Indicator` / `Inactive_Reason`.

Patterns to check in `name`, `surname`, `company_name`, `street`:
- `'%DECEASED%'`
- `'%OUT OF BUSINESS%'`
- `'%OOB%'` (standalone — watch for false positives in business names)
- `'%DO NOT USE%'`
- `'%INACTIVE%'`
- `'%CLOSED%'`

#### 4b. DBA in Wrong Field
`company_name` LIKE `'%DBA %'` OR `'%D/B/A%'` OR `'%DOING BUSINESS AS%'`

Data belongs in `Doing_Business_As` field.

#### 4c. Name Field Issues (I, C types)

| Issue | Check |
|---|---|
| Prefix in `name` | `name` LIKE `'MR.%'` OR `'MRS.%'` OR `'DR.%'` OR `'MS.%'` OR `'REV.%'` etc. |
| Generation/suffix in `surname` | `surname` LIKE `'% JR'` OR `'% JR.'` OR `'% SR'` OR `'% II'` OR `'% III'` OR `'% IV'` OR `'% MD'` OR `'% PHD'` OR `'% CPA'` |
| Combined names in `name` | `name` LIKE `'%&%'` OR `'% AND %'` OR `'%/%'` — should be separate records |
| Familiar name pattern in `name` | `name` LIKE `'%(%)%'` — e.g., "Billy (Joe)" |

#### 4d. Email Quality

| Issue | Check |
|---|---|
| Structurally invalid | `email_address` NOT LIKE `'%@%.%'` |
| Missing `@` entirely | `email_address` NOT LIKE `'%@%'` (subset of above) |
| Known placeholder patterns | LOWER contains: `noemail@`, `test@test`, `none@none`, `nomail@`, `donotcontact@`, `noreply@` |
| Internal/employee emails | `email_address` LIKE `'%@deere.com'` OR `'%@johndeere.com'` on customer records |

**API validation (deferred):** After SQL cleanup, assess remaining population. ZeroBounce/NeverBounce ~$0.003/email bulk. Value: email affects potential match scoring in the linkage tool. Decision: get structural baseline first, then evaluate cost vs. remaining volume.

#### 4e. Phone Quality

Apply to `BusinessPhone`, `PrivatePhone`, `MobilePhone` separately.

| Issue | Check |
|---|---|
| All zeros | `= '0000000000'` |
| Sequential placeholder | `= '1234567890'` |
| All same digit | LIKE `'1111111111'` through `'9999999999'` — or use `PATINDEX` / repeated-char detection |
| Wrong length (US) | `LEN(field) NOT IN (10, 11)` when not null/blank |
| Leading zero | `LEFT(field, 1) = '0'` — not a valid US area code |
| Starts with 1 (11-digit) | `LEN(field) = 11 AND LEFT(field, 1) = '1'` — may be valid (1 + 10-digit), verify separately |

**API validation (deferred):** Same decision framework as email. Carrier lookup ~$0.005/number. Useful for confirming mobile vs. landline (affects which EQUIP field to use). Defer until structural baseline is established.

#### 4f. Address Quality

| Issue | Check |
|---|---|
| State not 2-char | `LEN(LTRIM(RTRIM(state))) <> 2` when not null/blank |
| Country not 2-char | `LEN(LTRIM(RTRIM(country))) <> 2` when not null/blank |
| State written out | `state` IN ('IOWA', 'ILLINOIS', 'INDIANA', 'MINNESOTA', ...) — surface via `GROUP BY state` |
| Country written out | `country` IN ('UNITED STATES', 'USA', 'UNITED STATES OF AMERICA', 'CANADA', ...) |
| Zip not 5 digits | `pcode` not matching `[0-9][0-9][0-9][0-9][0-9]` for US records |
| Zip cross-reference | Zip → expected state mismatch — **requires reference table (deferred)** |

**Address reference dataset (deferred):** Start with format checks above. If a zip code dataset is available in Fabric (USPS or simplemaps), add zip→state consistency check. Evaluate dataset currency before use.

#### 4g. Generation, Prefix, and Suffix Field Validity (I, C types)

Check that data in the dedicated fields is a recognized value — not free-text, names, addresses, or status text entered in the wrong place.

| Field | EQUIP Column | Valid Values | Notes |
|---|---|---|---|
| Prefix | `title` | Values from Type Code Maintenance = TI (Mr., Mrs., Ms., Dr., Rev., Prof., etc.) | List is maintained in EQUIP — query `TI` type codes to get the authoritative set. Any value not in that list is invalid. |
| Generation | `Generation` | Jr., Jr, Junior, Sr., Sr, Senior, II, III, IV, V | Small known set. Variations without punctuation (Jr vs Jr.) are common — standardize as part of cleanup. |
| Suffix | `Suffix` | MD, PhD, DO, DDS, DVM, JD, CPA, RN, PE, Esq., etc. | More open-ended than Generation, but free-text garbage (e.g., "123 Main St", "DECEASED") is clearly invalid. Start by surfacing distinct values via `GROUP BY Suffix` to identify patterns before defining the full valid list. |

Track count of records where each field is non-null but contains an unrecognized value. These are candidates for bulk correction or nulling out.

---

### 5. Account Staleness

**Goal:** Identify inactivation candidates and track cleanup progress. Directly feeds Phase 2.1 (inactivate stale accounts) and informs the cutoff date decision.

**Data source:** External EQUIP Accounts dataset (contains last transaction date per `ACC_NO`). Join path: `Equip.contact` → `Equip.ArMaster` → Accounts dataset on `ACC_NO`.

**Scope:** Active contacts only (`ISNULL(Inactive_Indicator, 'A') <> 'I'`), excluding employees.

#### Staleness Buckets

Each active contact falls into exactly one bucket:

| Bucket | Definition |
|---|---|
| **No Account** | Contact has no `ArMaster` record (LEFT JOIN `ArMaster`, `ACC_NO IS NULL`). Qualitatively different from never-transacted — may be data entry orphans, unfinished records, or expected for certain contact structures. Needs investigation. See Open Questions. |
| **Never Transacted** | Has `ArMaster` record, but no transaction rows in the Accounts dataset. |
| **0–1 yr** | Last transaction within the past year |
| **1–2 yr** | 1–2 years since last transaction |
| **2–3 yr** | 2–3 years since last transaction |
| **3–4 yr** | 3–4 years since last transaction |
| **4–5 yr** | 4–5 years since last transaction |
| **5+ yr** | More than 5 years since last transaction — primary inactivation candidates |

#### Staleness Trend
Stacked bar chart by snapshot week — shows the full distribution shifting over time. As Phase 2.1 inactivations run, the 5+ and "Never Transacted" buckets should visibly shrink. The 0–1 yr bucket is a health check on the active customer base.

#### Staleness × Decile Matrix
Cross-tabulation of staleness bucket (rows) by sales decile (columns). Each cell shows count and/or a quality metric (e.g., clean record %).

Key reads:
- **D1–D2, 5+ yr** — highest-value customers with stale data; highest priority for outreach and cleanup before they churn
- **D1–D2, 0–1 yr** — healthy top accounts; baseline for what "good" looks like
- **D9–D10, 5+ yr** — low-value stale accounts; inactivation candidates; don't invest cleanup effort here
- **Any decile, Never Transacted** — accounts created but never used; investigate before inactivating

Quality metrics (completeness %, clean record %) overlaid on the matrix show whether high-value accounts have proportionally better or worse data than the rest of the population.

---

### 6. Match Readiness

**Goal:** For unlinked active contacts, estimate how likely a Path B upload is to produce a tight match. Shapes Phase 3 batch prioritization and sets expectations on tight match rate before uploading.

**Scope:** Unlinked active contacts only (contacts already in `cross_ref` don't need matching).

#### Tier Definitions

| Tier | Criteria | Expected Outcome |
|---|---|---|
| **1 — Strong** | Name present AND (street + city + state OR street + zip) | Tight match likely |
| **2 — Partial** | Name present AND (partial address OR at least one valid phone/email) | Potential match possible |
| **3 — Name Only** | Name present, no address and no contact info | Unlikely to match without data enrichment |
| **4 — No Name** | Missing first+last (I/C) or company name (B) | Cannot match regardless of other fields |

Name definition: for I/C, both `name` AND `surname` must be non-blank. For B, `company_name` must be non-blank.

#### Tracking
- Tier distribution across all four tiers, broken out by contact type (B/I/C)
- Goal: tier 1 + 2 % grows over time as Phase 2 cleanup runs
- After Phase 3 batches produce results, calibrate empirically: validate which tiers produced tight matches vs. potential matches vs. no match, then refine thresholds if needed

---

### 7. Overall Quality Score

A single composite metric aggregated to a population-level score for a simple trend line: "is overall data quality improving?"

#### Approach: Clean Record % (start here)

Track the **% of active contacts with zero quality flags** as the primary headline metric. A contact is "clean" if it passes all checks across completeness and field quality. Simple to compute and explain. Use this for the first Power BI release.

#### Approach: Weighted Index (after baseline is established)

Once baseline counts are in, a 0–100 index can be derived by weighting issue categories:

| Component | Weight | Rationale |
|---|---|---|
| Name complete | 25 | Required for any match attempt |
| Address complete + valid format | 25 | Primary tight-match signal |
| Phone or email present and structurally valid | 20 | Secondary match signal; affects potential match scoring |
| No field quality flags (status text, placeholder, combined name, invalid coded fields, etc.) | 20 | General cleanup signal |
| Match readiness tier 1 or 2 (unlinked only) | 10 | Linkage readiness |

Average the per-contact score across all active contacts for the weekly snapshot. Introduce the weighted index once Phase 3 data can validate the scoring weights against real match outcomes.

---

## Power BI Report Structure

All pages support slicing by contact type (B/I/C), branch, sales decile, staleness bucket, and creation cohort unless otherwise noted.

| Page | Content |
|---|---|
| 1. Executive Summary | KPI cards: % linked, clean record %, staleness risk %, match readiness tier 1+2 %. Traffic-light status per category. |
| 2. Linkage Quality | Linked/unlinked by type (B/I/C), duplicate entity counts, cross-ref orphans. Trend line for total linkages. |
| 3. Completeness | Null/blank rates by field and contact type. "No contact info" segment. |
| 4. Field Quality | Status-in-wrong-field, name issues (including coded field validity), phone patterns, email patterns, address format issues. |
| 5. Registry Parity | Match/mismatch/EQUIP-only/Registry-only per field for linked contacts. Certified-but-different and undeliverable highlights. |
| 6. Account Staleness | Staleness bucket trend (stacked bar by week). Staleness × decile matrix with quality metrics in cells. |
| 7. Match Readiness | Tier distribution for unlinked contacts by type. Post-Phase-3: empirical match rate by tier. |
| 8. Trends | Line charts for all major metrics over weekly snapshots, including overall quality score. |

---

## Implementation Steps

- [ ] **Step 1 — Write SQL queries** for each metric category. Run against Fabric, validate counts make sense.
- [ ] **Step 2 — Capture baseline** before any cleanup. Save to `results/quality-baseline-20260430.tsv`. This is the Phase 2.8 before-state.
- [ ] **Step 3 — Add to Fabric pipeline** as a weekly job. Append aggregated results to `data_quality_snapshot` table.
- [ ] **Step 4 — Build Power BI report** on top of snapshot table.
- [ ] **Step 5 — Evaluate APIs** after SQL cleanup. Get structural baseline counts first, then decide if email/phone API cost is justified.
- [ ] **Step 6 — Address reference dataset** — determine if a zip code table is available in Fabric for zip→state cross-check.

---

## Open Questions

- [ ] **Zip code reference dataset** — is a current zip→state/county mapping available in Fabric? USPS and simplemaps are options if not.
- [ ] **Phone API scope** — after structural cleanup, how many phone numbers remain questionable? Is carrier validation worth the cost for tight-match improvement?
- [ ] **Email API scope** — same question. Email affects potential match scoring specifically.
- [ ] **Registry parity policy** — for linked contacts where Registry has a certified address that differs from EQUIP, what is the update policy? Manual review, DBS Data Share, or leave as-is? (Carries over from project-plan.md Step 2.7.)
- [ ] **Snapshot table location** — which Fabric workspace/lakehouse should `data_quality_snapshot` live in? Same as the existing linkage snapshot?
- [ ] **Power BI audience** — internal tracking only, or presentable to management/staff? Determines polish level and whether explanatory text is needed in the report.
- [ ] **OOB pattern false positives** — `'%OOB%'` will match legitimate business names (e.g., "Oob Farm Supply"). Evaluate after running: may need to narrow to standalone word or common variants only.
- [ ] **Contacts without accounts** — are contacts without an `ArMaster` record expected (e.g., C-type business contacts that share their parent's account) or a data quality issue? Run a count broken out by `Business_Individual` type to classify before deciding how to handle in the staleness buckets.
- [ ] **Staleness dataset join** — what is the exact table/view name and key column for the EQUIP Accounts dataset with last transaction date? Confirm the join key matches `ArMaster.ACC_NO`.
- [ ] **Suffix valid value list** — run `SELECT DISTINCT Suffix, COUNT(*) FROM Equip.contact WHERE Suffix IS NOT NULL GROUP BY Suffix ORDER BY COUNT(*) DESC` to surface the actual values in use before defining the valid list.
- [ ] **Prefix valid value list** — query Type Code Maintenance `TI` codes to get the authoritative prefix list. Confirm the values match what's actually stored in `title`.
- [ ] **Match readiness tier calibration** — after first Phase 3 upload batch, pull tight match rate by tier to validate thresholds. Adjust tier definitions if empirical results differ from expectations.
- [ ] **Overall quality score weights** — defer weight decisions until baseline counts are known. Revisit after Phase 3 to validate against match outcomes.
- [ ] **Sales decile — revenue field** — confirm the exact field name and table for 5-year revenue in the Accounts dataset. Clarify whether it's a running total or needs to be aggregated from transaction rows. Confirm the join key to `ArMaster.ACC_NO`.
- [ ] **Branch field name** — confirm the exact column name for the territory/branch field on `Equip.contact`. Confirm it carries a branch ID that joins to the branch dimension table.
- [ ] **Branch dimension table** — identify the table to bring in as a dim (location name, active/closed status, acquisition flag). Confirm it's available in Fabric or needs to be loaded.

---

## Reference

| Resource | Notes |
|---|---|
| `docs/project-plan.md` Phase 2 | Data cleanup phases this reporting supports |
| `docs/dataset-equip-contact.md` | Full `Equip.contact` column reference |
| `DDP.customer_profile` schema | 90 columns — queried 2026-04-30. Key verified-address flags: `phys_postal_certified`, `phys_undeliverable_ind`, `mail_postal_certified`, `mail_undeliverable_ind`. |
| `queries/tracking.sql` | Existing linkage count query — model for snapshot approach |
