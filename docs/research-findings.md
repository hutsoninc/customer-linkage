# Customer Linkage — Data Research Findings

**Date:** 2026-04-28  
**Purpose:** Map the relationships between EQUIP, John Deere Registry (DDP), and Salesforce datasets to inform the customer linkage and cleanup project.

---

## Project Context

We are linking EQUIP (dealer DBS) customer contacts to John Deere's Customer Registry (IKC/CKC). A formal linkage creates a pointer between an EQUIP contact code and a Registry Entity ID, enabling the EQUIP DBS number to appear in John Deere's Common Search Component (CSC) membership column across sales tools (JDQuote2, JDMint, Sales Center, Rewards, Warranty Portal, etc.).

**Scale:** ~524,971 EQUIP accounts. ~58,282 formally linked. ~466,000 remaining.

---

## Available Datasets

| Dataset | Source | Description |
|---|---|---|
| `Equip.contact` | EQUIP DBS | All contacts with name, address, type, CKC IDs |
| `Equip.ArMaster` | EQUIP DBS | Customer billing accounts |
| `DDP.customer_cross_ref` | John Deere DDP (synced from Registry) | Confirmed linkages between EQUIP contact codes and Registry entity IDs |
| `DDP.customer_profile` | John Deere DDP (synced from Registry) | Full Registry customer population with status flags |
| `Salesforce.Account` | Salesforce (Anvil) | Customer accounts (synced from EQUIP) and Prospect accounts (Salesforce-only) |

All data is in Microsoft Fabric Lakehouses. Queries are written in T-SQL.

---

## Confirmed Table Relationships

### EQUIP.contact ↔ EQUIP.ArMaster
- **Cardinality:** 1:1
- **Join:** `Equip.contact.contact_code = Equip.ArMaster.contact_code`
- Every ArMaster account has exactly one contact code. 524,971 accounts, all matched.

### EQUIP.contact ↔ DDP.customer_cross_ref
- **Cardinality:** Mostly 1:1 (contact → entity). 603 entity_ids map to 2+ contact codes (duplicates).
- **Join:** `Equip.contact.contact_code = DDP.customer_cross_ref.cross_ref_number`
- 58,282 contacts formally linked.

### DDP.customer_cross_ref ↔ DDP.customer_profile
- **Cardinality:** 1:1
- **Join:** `DDP.customer_cross_ref.entity_id = DDP.customer_profile.entity_id`

### EQUIP.ArMaster ↔ Salesforce.Account
- **Cardinality:** 1:1 for synced customers
- **Join:** `Equip.ArMaster.ACC_NO = Salesforce.Account.Anvil__AccountNumber__c`
- Salesforce Prospect accounts have no account number and no EQUIP record.

---

## Key Field Semantics

### EQUIP.contact — Business_Individual
| Value | Meaning |
|---|---|
| `B` | Business |
| `I` | Individual |
| `C` | Business Contact (individual associated with a business) |

### EQUIP.contact — Inactive_Indicator
| Value | Meaning |
|---|---|
| `A` | Active |
| `null` | Active (treat as A) |
| `I` | Inactive |

### EQUIP.contact — Ckc_Id and Cmp_Ckc_Id

The meaning of these fields depends on contact type — confirmed at 96–99% match rate against `DDP.customer_cross_ref` (block 2c-revised):

| Contact Type | Ckc_Id | Cmp_Ckc_Id |
|---|---|---|
| B (Business) | Own Registry Entity ID | Not used |
| I (Individual) | Own Registry Entity ID | Not used |
| C (Business Contact) | Parent Business's Registry Entity ID | Own Registry Contact ID |

In Registry, a Business and all its Business Contacts share the same Entity ID. The Contact ID uniquely identifies each individual within the business.

### Salesforce.Account — Entity ID Fields

Two fields, with a precedence rule:
- `Anvil__CustomerCompEntityID__c` — set by quote workflow (JDQuote2/JDSC sync). How prospects get entity IDs without being in EQUIP.
- `H_Equip_contact_Ckc_Id__c` — synced from EQUIP's formal Registry linkage. **Overwrites `Anvil__CustomerCompEntityID__c` when populated.**

Creating formal EQUIP linkages will automatically correct stale Anvil-sourced entity IDs on Salesforce customer records through the normal sync.

---

## Registry Entity ID Ranges

Entity IDs are **temporally allocated** — not type-encoded. All three contact types (B, I, C) appear in all ranges. Ranges indicate when the customer was first added to Registry:

| Range | Era | Deceased % | OOB % | Registry Count |
|---|---|---|---|---|
| 1xx (100M–108M) | Oldest | 5.8% | 0.27% | 71,320 |
| 3xx (300M–364M) | Middle | 1.3% | 0.08% | 173,953 |
| 5xx (500M–546M) | Newest | 0.4% | 0.02% | 137,330 |
| 999,999,998 | Sentinel/placeholder | — | 100% | 1 |

Sequential adjacent IDs (e.g., 515471720 / 515471721) indicate a Business and its first Contact created together in Registry at the same time.

The sentinel record (entity_id = 999,999,998) is a placeholder/null value — the near-maximum integer, marked out of business. Check for this value in EQUIP and Salesforce data as it may indicate invalid CKC ID entries.

---

## Linkage State Summary

| Segment | Count | Notes |
|---|---|---|
| Formally linked via cross_ref | 58,282 | Active Registry linkages |
| SF and cross_ref agree — clean | 55,796 | Healthy baseline |
| SF and cross_ref disagree | 144 | Needs manual review before any bulk operations |
| EQUIP has CKC ID, no cross_ref entry | 590 | Informally linked — Path A candidates |
| SF customers: Anvil-only entity ID | 12,970 | Entity ID from quote workflow, no formal EQUIP link |
| SF prospects: Anvil entity ID from quotes | 23,973 | Not in EQUIP — prospect→customer conversion backlog |
| EQUIP active accounts, fully unlinked | ~466,000 | Path B — cleanup + match upload |

### Duplicate Linkages (603 entity_ids with 2+ EQUIP contacts)

| Pattern | Count | Interpretation |
|---|---|---|
| I+I | 372 | Same individual entered twice — clear dedup candidates |
| C+C | 123 | Same business contact entered twice — clear dedup candidates |
| C+I | 49 | Same Registry entity typed as both C and I in EQUIP — needs investigation |
| I+I+I | 9 | Three-way individual duplicate |
| B+C | 9 | Likely legitimate — business + contact share same parent entity_id |
| C+C+C | 6 | Three-way business contact duplicate |
| B+C+C | 1 | Business with two contacts, all under same entity |
| C+C+C+C+C | 1 | Five-way business contact duplicate (EASTMIC* cluster) |
| C+I+I | 1 | Complex mixed case |
| B+B | 1 | True business duplicate |

---

## Test Blocks

All result files are stored in `results/`. All tests run on **2026-04-28**.

---

### Block 1a — Contact Type Breakdown
**File:** `results/block-1a-results.tsv`  
**Purpose:** Understand the distribution of active vs. inactive contacts by type (B/I/C) and how many have CKC IDs and Cmp_Ckc_Id populated.

```sql
SELECT
    Business_Individual,
    ISNULL(Inactive_Indicator, 'A')         AS status,
    COUNT(*)                                 AS total,
    COUNT(Ckc_Id)                            AS has_ckc_id,
    SUM(CASE WHEN Cmp_Ckc_Id IS NULL THEN 1 ELSE 0 END)   AS cmp_null,
    SUM(CASE WHEN Cmp_Ckc_Id = 0    THEN 1 ELSE 0 END)    AS cmp_zero,
    SUM(CASE WHEN Cmp_Ckc_Id > 0    THEN 1 ELSE 0 END)    AS cmp_populated
FROM Equip.contact
GROUP BY Business_Individual, ISNULL(Inactive_Indicator, 'A')
ORDER BY Business_Individual, status;
```

**Key Findings:**
- Active B: 13,493 total, 144 linked (1.1%)
- Active C: 143,098 total, 9,595 linked (6.7%) — large unlinked population
- Active I: 408,469 total, 48,543 linked (11.9%)
- 3,995 active C-type contacts have `Cmp_Ckc_Id` populated — aligns with Business Contact linkages that have a Contact ID

---

### Block 1b — ArMaster to Contact Cardinality
**File:** `results/block-1b-results.tsv`  
**Purpose:** Confirm whether each ArMaster account maps to exactly one contact code, or if multiple accounts can share a contact.

```sql
SELECT
    contact_code_count,
    COUNT(ACC_NO) AS account_count
FROM (
    SELECT contact_code, COUNT(ACC_NO) AS contact_code_count
    FROM Equip.ArMaster
    GROUP BY contact_code
) t
GROUP BY contact_code_count
ORDER BY contact_code_count;
```

**Key Findings:**
- Perfect 1:1. All 524,971 accounts have exactly one contact code. No shared contacts.

---

### Block 1c — Cmp_Ckc_Id Parent Contact Hypothesis (Initial)
**File:** `results/block-1c-results.tsv`  
**Purpose:** Test whether `Cmp_Ckc_Id` points to a parent Business contact's `Ckc_Id` within EQUIP (i.e., is it a self-referential join within the contact table?).

```sql
SELECT
    child.contact_code,
    child.Business_Individual,
    child.Ckc_Id,
    child.Cmp_Ckc_Id,
    parent.contact_code     AS parent_contact_code,
    parent.Business_Individual AS parent_type,
    parent.Ckc_Id           AS parent_ckc_id
FROM Equip.contact child
LEFT JOIN Equip.contact parent
    ON parent.Ckc_Id = child.Cmp_Ckc_Id
WHERE child.Cmp_Ckc_Id > 0
ORDER BY child.Business_Individual;
```

**Key Findings:**
- `parent_contact_code` is NULL on every row — `Cmp_Ckc_Id` does NOT join back to any other contact's `Ckc_Id`.
- Hypothesis disproved. However, the data revealed sequential adjacent ID pairs (e.g., Ckc_Id=515471720, Cmp_Ckc_Id=515471721), pointing to a different interpretation: `Ckc_Id` = parent business entity, `Cmp_Ckc_Id` = contact's own Contact ID in Registry. Confirmed by block 2c-revised.

---

### Block 2a — Cross-ref Breakdown by Contact Type
**File:** `results/block-2a-results.tsv`  
**Purpose:** Understand how DDP.customer_cross_ref entity_id and contact_id relate to EQUIP contact types.

```sql
SELECT
    c.Business_Individual,
    CASE
        WHEN xr.contact_id IS NULL OR xr.contact_id = 0 THEN 'entity only'
        ELSE 'entity + contact_id'
    END                                         AS ref_type,
    COUNT(*)                                    AS row_count,
    COUNT(DISTINCT xr.entity_id)                AS distinct_entity_ids
FROM DDP.customer_cross_ref xr
JOIN Equip.contact c ON c.contact_code = xr.cross_ref_number
GROUP BY
    c.Business_Individual,
    CASE WHEN xr.contact_id IS NULL OR xr.contact_id = 0 THEN 'entity only' ELSE 'entity + contact_id' END
ORDER BY c.Business_Individual;
```

**Key Findings:**
- B and I types are almost entirely "entity only" as expected — businesses and individuals have an Entity ID, no Contact ID.
- C types split: 3,902 have entity + contact_id (proper Business Contact linkages), 5,533 are entity only (linked to business entity but no Contact ID stored — likely legacy linkages).
- 77 I-type contacts have a contact_id in cross_ref (unusual — may be data quality issues).

---

### Block 2b — Duplicate Entity IDs (Multiple DBS per Registry Entity)
**File:** `results/block-2b-results.tsv`  
**Purpose:** Identify how many Registry entity_ids are linked to more than one EQUIP contact code (potential duplicates).

```sql
SELECT
    links_per_entity,
    COUNT(*) AS entity_id_count
FROM (
    SELECT entity_id, COUNT(cross_ref_number) AS links_per_entity
    FROM DDP.customer_cross_ref
    GROUP BY entity_id
) t
GROUP BY links_per_entity
ORDER BY links_per_entity;
```

**Key Findings:**
- 57,051 entity_ids → 1 EQUIP contact (clean)
- 585 entity_ids → 2 EQUIP contacts
- 17 entity_ids → 3 EQUIP contacts
- 1 entity_id → 5 EQUIP contacts
- **603 entity_ids total with duplicate EQUIP contacts.** These are confirmed duplicates requiring deduplication in EQUIP.

---

### Block 2c — Cmp_Ckc_Id Hypothesis Test (Initial — Incorrect)
**File:** `results/block-2c-results.tsv`  
**Purpose:** Test whether `Cmp_Ckc_Id = entity_id` and `Ckc_Id = contact_id` in cross_ref for Business Contact rows.

**Result:** 0 matches. Hypothesis was backwards. See block 2c-revised.

---

### Block 2c-revised — Cmp_Ckc_Id Hypothesis Test (Corrected)
**File:** `results/block-2c-revised-results.tsv`  
**Purpose:** Test the reversed hypothesis: `Ckc_Id = entity_id` (parent business) and `Cmp_Ckc_Id = contact_id`.

```sql
SELECT
    COUNT(*)                                                              AS total_with_contact_id,
    SUM(CASE WHEN c.Ckc_Id      = xr.entity_id  THEN 1 ELSE 0 END)     AS ckc_matches_entity_id,
    SUM(CASE WHEN c.Cmp_Ckc_Id  = xr.contact_id THEN 1 ELSE 0 END)     AS cmp_matches_contact_id,
    SUM(CASE WHEN c.Ckc_Id      = xr.entity_id
             AND c.Cmp_Ckc_Id  = xr.contact_id  THEN 1 ELSE 0 END)     AS both_match
FROM DDP.customer_cross_ref xr
JOIN Equip.contact c ON c.contact_code = xr.cross_ref_number
WHERE xr.contact_id IS NOT NULL AND xr.contact_id != 0;
```

**Key Findings:**
- 3,947/3,980 (99.2%): `Ckc_Id = entity_id` ✓
- 3,858/3,980 (97.0%): `Cmp_Ckc_Id = contact_id` ✓
- 3,828/3,980 (96.2%): both match ✓
- **Confirmed:** For C-type contacts, `Ckc_Id` = parent Business Entity ID, `Cmp_Ckc_Id` = own Contact ID.

---

### Block 2d — C-type "Entity Only" Linkages
**File:** `results/block-2d-results.tsv`  
**Purpose:** For the 5,533 C-type contacts linked as "entity only" (no contact_id in cross_ref), understand whether they have `Cmp_Ckc_Id` populated.

```sql
SELECT
    SUM(CASE WHEN c.Cmp_Ckc_Id IS NULL THEN 1 ELSE 0 END)  AS cmp_null,
    SUM(CASE WHEN c.Cmp_Ckc_Id = 0     THEN 1 ELSE 0 END)  AS cmp_zero,
    SUM(CASE WHEN c.Cmp_Ckc_Id > 0     THEN 1 ELSE 0 END)  AS cmp_populated,
    SUM(CASE WHEN c.Ckc_Id IS NOT NULL  THEN 1 ELSE 0 END)  AS has_ckc_id
FROM DDP.customer_cross_ref xr
JOIN Equip.contact c ON c.contact_code = xr.cross_ref_number
WHERE c.Business_Individual = 'C'
  AND (xr.contact_id IS NULL OR xr.contact_id = 0);
```

**Key Findings:**
- 609 have NULL Cmp_Ckc_Id, 4,894 have Cmp_Ckc_Id = 0, only 30 have it populated.
- These C-type contacts were linked to the parent business's Entity ID but never had a Contact ID assigned — likely legacy linkages created before Contact IDs were tracked, or linked at the business level rather than as a named contact.

---

### Block 2e — Inspect Duplicate Entity ID Contacts
**File:** `results/block-2e-results.tsv`  
**Purpose:** For the 603 entity_ids with multiple EQUIP contacts, list the contact codes and types to understand the nature of the duplicates.

```sql
SELECT
    xr.entity_id,
    COUNT(xr.cross_ref_number)          AS dbs_count,
    STRING_AGG(c.Business_Individual, ', ')
        WITHIN GROUP (ORDER BY xr.cross_ref_number) AS contact_types,
    STRING_AGG(xr.cross_ref_number, ', ')
        WITHIN GROUP (ORDER BY xr.cross_ref_number)  AS contact_codes
FROM DDP.customer_cross_ref xr
JOIN Equip.contact c ON c.contact_code = xr.cross_ref_number
GROUP BY xr.entity_id
HAVING COUNT(xr.cross_ref_number) > 1
ORDER BY COUNT(xr.cross_ref_number) DESC;
```

**Key Findings:**
- Majority are same-type pairs (I,I or C,C) with similar names and sequential contact code numbers — classic data entry duplicates with spelling variants.
- Mixed types (I+C, B+C) require investigation before merging.
- Notable case: entity_id 104400978 has 5 Business Contact codes (EASTMIC* cluster).

---

### Block 2f — Duplicate Type Combination Summary
**File:** `results/block-2f-results.tsv`  
**Purpose:** Categorize the 603 duplicate entity_ids by their contact type combination to prioritize deduplication work.

```sql
SELECT
    type_combo,
    COUNT(*) AS entity_count
FROM (
    SELECT
        entity_id,
        STRING_AGG(c.Business_Individual, '+')
            WITHIN GROUP (ORDER BY c.Business_Individual) AS type_combo
    FROM DDP.customer_cross_ref xr
    JOIN Equip.contact c ON c.contact_code = xr.cross_ref_number
    GROUP BY xr.entity_id
    HAVING COUNT(xr.cross_ref_number) > 1
) t
GROUP BY type_combo
ORDER BY entity_count DESC;
```

**Key Findings:**

| Pattern | Count | Action |
|---|---|---|
| I+I | 372 | Clear dedup — same individual entered twice |
| C+C | 123 | Clear dedup — same business contact entered twice |
| C+I | 49 | Investigate — same Registry entity typed differently in EQUIP |
| B+C | 9 | Likely legitimate — business + contact share entity_id |
| I+I+I | 9 | Three-way individual duplicate |
| C+C+C | 6 | Three-way business contact duplicate |
| Others | 35 | Complex/mixed cases |

---

### Block 3a — Salesforce Account Breakdown
**File:** `results/block-3a-results.tsv`  
**Purpose:** Understand entity ID coverage across Salesforce Customer and Prospect records.

```sql
SELECT
    CASE RecordTypeId
        WHEN '0124W000001aGwlQAE' THEN 'Customer'
        WHEN '0124W000001aGwgQAE' THEN 'Prospect'
        ELSE 'Other'
    END                                                                 AS record_type,
    COUNT(*)                                                            AS total,
    COUNT(Anvil__AccountNumber__c)                                      AS has_account_number,
    COUNT(Anvil__CustomerCompEntityID__c)                               AS has_anvil_entity_id,
    COUNT(H_Equip_contact_Ckc_Id__c)                                   AS has_equip_ckc_id,
    SUM(CASE WHEN Anvil__CustomerCompEntityID__c IS NOT NULL
              AND H_Equip_contact_Ckc_Id__c IS NULL     THEN 1 ELSE 0 END) AS anvil_only,
    SUM(CASE WHEN H_Equip_contact_Ckc_Id__c IS NOT NULL THEN 1 ELSE 0 END) AS equip_sourced
FROM Salesforce.Account
GROUP BY RecordTypeId
ORDER BY record_type;
```

**Key Findings:**
- 532,835 Customer records; 532,012 have account numbers (linked to EQUIP).
- 56,571 customers formally linked (have `H_Equip_contact_Ckc_Id__c` from EQUIP).
- 12,970 customers have Anvil-only entity IDs (from quote workflow, no formal EQUIP link).
- 50,705 Prospect records; 23,973 have Anvil entity IDs from quotes — not in EQUIP.
- 93,516 total records with some form of entity ID (matches dataset description).

---

### Block 3b — Salesforce vs. Cross-ref Entity ID Agreement
**File:** `results/block-3b-results.tsv`  
**Purpose:** For Salesforce customers with a formal EQUIP CKC ID, check whether it agrees with the Registry cross_ref linkage.

```sql
SELECT
    COUNT(*)                                                            AS sf_customers_with_equip_ckc,
    SUM(CASE WHEN sf.H_Equip_contact_Ckc_Id__c = xr.entity_id  THEN 1 ELSE 0 END) AS ids_agree,
    SUM(CASE WHEN sf.H_Equip_contact_Ckc_Id__c != xr.entity_id THEN 1 ELSE 0 END) AS ids_disagree,
    SUM(CASE WHEN xr.entity_id IS NULL                          THEN 1 ELSE 0 END) AS no_cross_ref_found
FROM Salesforce.Account sf
JOIN Equip.ArMaster ar
    ON ar.ACC_NO = sf.Anvil__AccountNumber__c
JOIN Equip.contact c
    ON c.contact_code = ar.contact_code
LEFT JOIN DDP.customer_cross_ref xr
    ON xr.cross_ref_number = c.contact_code
WHERE sf.RecordTypeId = '0124W000001aGwlQAE'
  AND sf.H_Equip_contact_Ckc_Id__c IS NOT NULL;
```

**Key Findings:**
- 55,796/56,530 (98.7%) agree — clean.
- 144 disagree — Salesforce and Registry cross_ref have different entity IDs for the same contact. Do not include in bulk operations without manual review.
- 590 have no cross_ref entry — EQUIP has CKC ID, synced to Salesforce, but no formal Registry linkage record. Path A candidates.

---

### Block 3c — Inspect the 144 Disagreements
**File:** `results/block-3c-results.tsv`  
**Purpose:** Sample the 144 records where Salesforce and cross_ref entity IDs disagree to understand the cause.

```sql
SELECT TOP 50
    sf.Id                               AS sf_account_id,
    sf.Anvil__AccountNumber__c          AS account_number,
    sf.H_Equip_contact_Ckc_Id__c       AS sf_ckc_id,
    xr.entity_id                        AS cross_ref_entity_id,
    c.contact_code,
    c.Business_Individual
FROM Salesforce.Account sf
JOIN Equip.ArMaster ar
    ON ar.ACC_NO = sf.Anvil__AccountNumber__c
JOIN Equip.contact c
    ON c.contact_code = ar.contact_code
JOIN DDP.customer_cross_ref xr
    ON xr.cross_ref_number = c.contact_code
WHERE sf.RecordTypeId = '0124W000001aGwlQAE'
  AND sf.H_Equip_contact_Ckc_Id__c IS NOT NULL
  AND sf.H_Equip_contact_Ckc_Id__c != xr.entity_id;
```

**Key Findings:**
- Two patterns observed:
  - **Small numeric difference** (e.g., Δ309, Δ568): likely the sequential allocation pattern where a business and its contact get adjacent IDs — one side linked to the business entity, the other to the contact entity.
  - **Very different IDs**: the contact was re-linked to a different Registry entity at some point and one side was not updated. Requires manual review.
- All 144 should be reviewed individually before any bulk operation.

---

### Block 3d — Inspect the 590 with No Cross-ref Entry
**File:** `results/block-3d-results.tsv`  
**Purpose:** For the 590 Salesforce customers with an EQUIP CKC ID but no cross_ref entry, verify whether the CKC ID stored in EQUIP matches what Salesforce has.

```sql
SELECT
    COUNT(*)                                                        AS total,
    COUNT(c.Ckc_Id)                                                AS has_ckc_in_equip,
    SUM(CASE WHEN c.Ckc_Id = sf.H_Equip_contact_Ckc_Id__c
             THEN 1 ELSE 0 END)                                    AS ckc_agrees_with_sf
FROM Salesforce.Account sf
JOIN Equip.ArMaster ar
    ON ar.ACC_NO = sf.Anvil__AccountNumber__c
JOIN Equip.contact c
    ON c.contact_code = ar.contact_code
LEFT JOIN DDP.customer_cross_ref xr
    ON xr.cross_ref_number = c.contact_code
WHERE sf.RecordTypeId = '0124W000001aGwlQAE'
  AND sf.H_Equip_contact_Ckc_Id__c IS NOT NULL
  AND xr.entity_id IS NULL;
```

**Key Findings:**
- 586/590 have a matching `Ckc_Id` in EQUIP that agrees with Salesforce — data is consistent between both systems.
- These contacts have real CKC IDs stored and synced, but the formal Registry linkage was never created through the Customer Linkage Tool (or the DDP sync hasn't captured it).
- **Strong Path A candidates** — submit their existing CKC IDs as bulk formal linkages using the `Create_Bulk_Linkages_Template.csv` format.
- 4 records have no `Ckc_Id` in EQUIP despite Salesforce having one — stale sync artifacts, minor cleanup needed.

---

### Block 4a — Entity ID Pattern by Contact Type
**File:** `results/block-4a-results.tsv`  
**Purpose:** Determine whether Registry entity ID leading digit encodes customer type (B/I/C) or represents something else.

```sql
SELECT
    LEFT(CAST(xr.entity_id AS VARCHAR), 1)      AS leading_digit,
    c.Business_Individual                         AS contact_type,
    CASE WHEN xr.contact_id IS NULL
              OR xr.contact_id = 0
         THEN 'entity only'
         ELSE 'entity + contact_id'
    END                                           AS ref_type,
    COUNT(*)                                      AS row_count,
    MIN(xr.entity_id)                             AS min_entity_id,
    MAX(xr.entity_id)                             AS max_entity_id
FROM DDP.customer_cross_ref xr
JOIN Equip.contact c ON c.contact_code = xr.cross_ref_number
GROUP BY
    LEFT(CAST(xr.entity_id AS VARCHAR), 1),
    c.Business_Individual,
    CASE WHEN xr.contact_id IS NULL
              OR xr.contact_id = 0
         THEN 'entity only'
         ELSE 'entity + contact_id'
    END
ORDER BY leading_digit, contact_type;
```

**Key Findings:**
- All three contact types (B, I, C) appear in all leading digit ranges — the leading digit does **not** encode type.
- IDs commonly start with 1, 3, or 5. No 2, 4, 6, 7, 8 ranges exist in our data.

---

### Block 4b — Entity ID Pattern Across Full Registry Population
**File:** `results/block-4b-results.tsv`  
**Purpose:** Confirm the entity ID range pattern against the full Registry population (not just our linked contacts) and understand deceased/OOB distribution by range.

```sql
SELECT
    LEFT(CAST(entity_id AS VARCHAR), 1)     AS leading_digit,
    COUNT(*)                                 AS total,
    SUM(CASE WHEN out_of_busn_ind = 'Y'
             THEN 1 ELSE 0 END)             AS out_of_business,
    SUM(CASE WHEN descd_ind = 'Y'
             THEN 1 ELSE 0 END)             AS deceased,
    MIN(entity_id)                           AS min_id,
    MAX(entity_id)                           AS max_id
FROM DDP.customer_profile
GROUP BY LEFT(CAST(entity_id AS VARCHAR), 1)
ORDER BY leading_digit;
```

**Key Findings:**
- Full Registry population visible in DDP: 382,603 records.
- 1xx range: 5.8% deceased — oldest customers.
- 3xx range: 1.3% deceased — middle era.
- 5xx range: 0.4% deceased — newest customers.
- Confirmed temporal allocation: IDs were assigned sequentially as customers were added to Registry, jumping from the 100M block to 300M to 500M as each filled.
- One sentinel record: entity_id = 999,999,998, marked out of business. Likely a placeholder/null value — check EQUIP and Salesforce for this value as it would indicate invalid CKC ID entries.

---

---

## Phase 1 Execution Findings

### Block 7a — Phase 1.2 Extraction (Anvil-Only Customers)

**Query:** `queries/phase-1/block-7a.sql`  
**Result:** `results/block-7a-results.tsv` — 12,818 rows  
**Upload file:** `uploads/phase1b-anvil-only-match.csv`

The 12,970 Anvil-only SF customers reduced to 12,818 after inner-joining to EQUIP:

| Reason | Count |
|---|---|
| SF customers with LEFT JOIN to EQUIP | 12,891 |
| No EQUIP contact record at all | -48 |
| EQUIP contact inactive | -25 |
| **Upload file rows** | **12,818** |

The 79 gap between 12,970 and 12,891 are SF Customer accounts whose `Anvil__AccountNumber__c` doesn't join to any `ArMaster` record.

---

### Block 7b — Phase 1.1 Entity/Contact ID Validation

**Query:** `queries/phase-1/block-7b.sql`  
**Result:** `results/block-7b-results.tsv`

Validated all 49 Phase 1.1 informal-link records against `DDP.customer_profile` to confirm each entity ID (and contact ID for C-type records) still exists in Registry.

**Entity-level summary:**

| Status | Count |
|---|---|
| Entity confirmed in `customer_profile` | 30 |
| Entity NOT found in `customer_profile` | 19 |

**Contact-level summary (C-type records only):**

| Status | Count |
|---|---|
| Contact confirmed in `customer_profile` | 3 |
| Contact NOT found (entity also missing) | 5 |
| Contact NOT found (entity exists) | 1 |
| Not applicable (B/I type) | 40 |

**Key findings:**

- **30 clean records:** Entity confirmed present and active (no `out_of_busn_ind = Y` or `descd_ind = Y` flags). Three of these (JONESBROC21598, SHADLAC308238, WABASHVALLEYP54) also have their contact IDs confirmed — these should link at the contact level cleanly.

- **19 stale entity IDs:** The `Ckc_Id` stored in EQUIP no longer exists in Registry as a primary entity. These are likely entities that were merged in JD's system. Testing confirmed the Customer Linkage Tool follows the merge chain and creates a link to the surviving entity — but with a different entity ID than what we uploaded. The EQUIP `Ckc_Id` values on these records are stale and should be updated after linkage.

- **5 C-type records with missing entity AND contact (AHWLLC4793368, HEDINGERKEITH71, JLDLAGUËH7E5N86, ROSSVIEWHIGHS68, WILSONSOAK71156):** Both the entity and the contact within it no longer exist in `customer_profile`. The tool will follow the entity merge chain but — as confirmed in test upload — returns `Contact ID = 0`, meaning the linkage lands at the business entity level rather than the individual contact level.

- **CARNAHANC6541 (edge case):** Entity (`301695636`) exists, but the contact within it (`301695637`) does not. The contact was likely merged or deleted independently. Will link at entity level only.

**Test upload results (`uploads/phase1a-informal-links-test.csv` → `results/Report_phase1a-informal-links-test.xlsx`):**

Uploaded 4 records as a test:

| DBS Number | Status | Notes |
|---|---|---|
| WILSONSOAK71156 | Linkage Created on Merged Entity ID | Entity merged; contact linkage dropped (Merged Contact ID = 0) |
| WILSONVAN423230 | Linkage Created on Merged Entity ID | Entity merged; no contact expected (B/I type) |
| YAGLEJAC9453 | Linkage Created Successfully | Clean |
| YOUNBUC709311 | Linkage Created Successfully | Clean |

**Decision pending:** How to handle the 6 records where contact-level linkage will be lost (see Open Questions in `project-plan.md`).

---

### Phase 1.2 Tight Match Results

**Email:** `source-materials/tight-match-process-complete-email.txt`  
**Upload file:** `uploads/phase1b-anvil-only-match.csv` (12,818 rows)

| Result | Count |
|---|---|
| Tight match | 8,173 |
| Potential match | 3,872 |
| No match | 277 |
| Already linked | 7 |
| Error | 489 |
| **Total** | **12,818** |

**Second upload (489 error corrections):** `uploads/phase1b-errors-corrected-20260429-150026.csv` — no errors on resubmission. Returned 273 additional tight matches.

**Errors:** All 489 errors were caused by a blank `country` field — the tool requires a valid 2-character ISO country code. Some records had empty string `''` rather than NULL, so `ISNULL` alone was insufficient. Fix applied to `block-7a.sql` (and used as the standard pattern going forward for all upload queries):

```sql
ISNULL(NULLIF(LTRIM(RTRIM(c.country)), ''), 'US') AS [Country Code]
```

Corrected re-upload file (489 rows): `uploads/phase1b-errors-corrected-20260429-150026.csv` (filename shortened — see timestamp convention below).

**Timestamp convention:** `fabric_query.py` supports a `--timestamp` flag that appends `YYYYMMDD-HHMMSS` to the output filename. The script auto-truncates the stem so the full filename never exceeds 50 characters (the Customer Linkage Tool's limit). Use `--timestamp` on all upload file runs.

---

### Phase 1.2 Tight Match Reconciliation

**Script:** `scripts/reconcile_tight_matches.py`  
**Input:** `results/Tight Match-phase1b-anvil-only-match.xlsx` + `results/Tight Match-phase1b-errors-corrected-20260429-150026.xlsx`  
**Output:** `uploads/phase1b-reconciliation.csv`

Combined tight match results (8,173 + 273) reconciled against Salesforce `Anvil__CustomerCompEntityID__c`:

| Status | Count | Meaning |
|---|---|---|
| AGREE | 7,157 | Tight match entity ID matches Salesforce — safe to bulk accept |
| DISAGREE | 1,289 | Tight match entity ID differs from Salesforce |
| SF_MISSING | 0 | All DBS numbers found in Salesforce |

**DISAGREE breakdown:** 1,056 entity-level (Contact ID = 0), 233 contact-level.

**Interpretation:** A tight match means Deere's algorithm is highly confident based on standardized name + address comparison. When it returns a *different* entity ID than what Salesforce has, the most likely cause is that the Salesforce `Anvil__CustomerCompEntityID__c` was stale or assigned incorrectly during a quote workflow — the tight match is probably more reliable. Decision pending on how to handle (see Open Questions in `project-plan.md`).

---

### Employee Contact Exclusion (block-7a correction)

**Finding:** `Equip.contact` includes internal employee records used elsewhere in EQUIP (service technicians and salespersons). These must be excluded from all customer linkage uploads.

**Employee tables:**

| Table | Role | Key Column | Total Rows | Joins to contact | Has `is_terminated` |
|---|---|---|---|---|---|
| `Equip.WKMECHFL` | Service technicians | `Code` | 1,787 | 1,768 (99%) | Yes (`is_terminated`) |
| `Equip.VhSalman` | Salespersons | `CODE` | 2,468 | 2,435 (99%) | Yes (`Is_Terminated`) |

Both join 1:1 to `Equip.contact.contact_code`. All employees are excluded regardless of termination status — the contact record is an employee record regardless of whether they still work there.

**Impact on Phase 1.2:** 20 employee rows (18 unique contact codes — T6176 and T6194 appear in both tables) slipped into the original upload. 10 of the 18 received tight matches: 7 in the AGREE group and 3 in the DISAGREE group. The agree/disagree upload files have been regenerated with employees removed:

- `uploads/phase1b-agree-20260429-152040.csv` — 7,150 records (was 7,157)
- `uploads/phase1b-disagree-20260429-152040.csv` — 1,286 records (was 1,289)

**Fix applied to `block-7a.sql`** and documented as a standing rule in `CLAUDE.md`.

**Data sync behavior — confirmed from Help Document and screenshots:**

Three distinct mechanisms exist for moving data between EQUIP and Registry. They are separate and should not be confused:

| Mechanism | Direction | Scope | How |
|---|---|---|---|
| **Bulk Linkage Tool** | Registry ← EQUIP (contact data upload), then Registry → EQUIP (entity ID only, overnight) | Linkage only — no contact data sync | Automated overnight |
| **Contact Information Search** (EQUIP Contact Code Maintenance → Customer Search) | Registry → EQUIP | Selective: Delivery Details, Postal Address, Other Contact Info | Manual per record; checkboxes select which sections to pull in; "Update Cust Ent ID Only" updates entity ID only; "Update" applies entity ID + all checked sections |
| **DBS Data Share** (CSC 2.0, US/CA EQUIP dealers only) | Bidirectional | Contact data in both directions simultaneously | Manual per record within CSC 2.0 |

The Help Document is explicit: *"The linkage does not sync data between systems — it simply establishes that a DBS contact and a Registry entity are the same customer. Data differences between the two records are acceptable."*

Entity ID write-back IS documented: *"EQUIP dealers: linkages created in Registry via the tool are sent to EQUIP overnight."*

**Screenshot observation (Equip Contact Information Search Screen.png):** WILSONSOAK71156 was opened in Contact Code Maintenance. The Contact Information Search popup pre-populated with the existing `Ckc_Id = 349494940` and returned no results — because that entity no longer exists as a primary entity in Registry (it merged into `321788532`). A user trying to fix this manually would need to clear the entity ID field, search by name, find `321788532`, select the correct BC row (contact `328618610` — BENJAMIN WILSON), and click Update. This is a non-obvious manual remediation step for stale merged entity IDs.

**EQUIP write-back behavior — CONFIRMED (2026-04-30):** After the Phase 1.1 test upload, EQUIP updated overnight:

- **Entity ID write-back confirmed** — `Ckc_Id` was updated to the surviving merged entity ID.
- **Contact ID preserved, not zeroed** — `Cmp_Ckc_Id` (328618610) was retained in EQUIP even though the tool returned `Contact ID = 0` in the "Merged Contact ID that was linked" column. The tool does not zero out an existing contact ID during write-back.
- **Likely no-overwrite rule** — the tool appears to write entity/contact IDs back to EQUIP but will not overwrite a field that already has a value with a lower-confidence value (e.g., 0). If the contact itself were reassigned to a different contact ID in the Registry, it's possible that ID would be written back.

**Implication for merged entity records:** The 5 Phase 1.1 records that linked to a merged entity (WILSONSOAK71156 and peers) will have their EQUIP `Ckc_Id` corrected to the surviving entity overnight. The contact ID will be preserved as-is rather than cleared. This is the correct behavior for our use case — no manual remediation needed for these records.

**Phase 1.2 follow-up:** Run `queries/phase-1/block-7c.sql` after Phase 1.2 upload and overnight sync to confirm `Ckc_Id` was populated on the null-`Ckc_Id` records. That will confirm the write-back also fires for records with no prior value.

---

## Pending Investigations

- **Block 4c/4d** (not yet run): Check whether sentinel entity_id 999,999,998 appears in EQUIP.contact or Salesforce.Account.
- **Block 2g** (not yet run): Inspect the 49 C+I mixed-type duplicate cases to determine if they are legitimate or data entry errors.
- **Block 3 Salesforce queries** for the 12,970 Anvil-only customers: validate entity IDs against Registry before using for Path A linkage.

---

## Next Steps

1. **Path A — 586 informal links:** Extract contact codes + CKC IDs, format to `Create_Bulk_Linkages_Template.csv`, submit as first formal linkage batch.
2. **Path A — 12,970 Anvil-only customers:** Validate entity IDs, then bulk link those confirmed correct.
3. **Path B — ~466k unlinked:** EQUIP data cleanup (standardize State/Country codes, fix misplaced fields) then batch upload via Match DBS Customer List.
4. **Deduplication:** Address 511 same-type duplicates (I+I, C+C) via EQUIP Customer/Contact Merge — coordinate with CustomerTRAX, Foresight, Sedona first.
5. **144 disagreements:** Manual review before any bulk operations touch those records.
6. **Operations Center:** Separate workstream after Registry linkage is mature.
