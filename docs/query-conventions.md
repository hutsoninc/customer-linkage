# Query Conventions

Standing rules for all T-SQL queries in this project. See CLAUDE.md for the short-form rules — this file has the full patterns with examples.

---

## 1. cross_ref Join — Always Use UPPER()

`DDP.customer_cross_ref.cross_ref_number` is stored ALL CAPS. `Equip.contact.contact_code` is mixed case. Fabric collation is case-sensitive. Without UPPER(), ~92% of matches are missed.

```sql
-- CORRECT
JOIN DDP.customer_cross_ref xr
    ON UPPER(xr.cross_ref_number) = UPPER(c.contact_code)

-- WRONG
JOIN DDP.customer_cross_ref xr
    ON xr.cross_ref_number = c.contact_code
```

---

## 2. Country Code — Handle NULL and Empty String

The Customer Linkage Tool requires a valid 2-character ISO country code. Some EQUIP records have `''` (empty string) rather than NULL, so `ISNULL` alone misses them.

```sql
ISNULL(NULLIF(LTRIM(RTRIM(c.country)), ''), 'US') AS [Country Code]
```

---

## 3. Exclude Employee Contacts

`Equip.contact` includes service technicians (`Equip.WKMECHFL`) and salespersons (`Equip.VhSalman`). Exclude all employees from upload queries regardless of termination status.

```sql
LEFT JOIN Equip.WKMECHFL m ON m.Code = c.contact_code
LEFT JOIN Equip.VhSalman s ON s.CODE = c.contact_code
...
AND m.Code IS NULL    -- exclude service technicians
AND s.CODE IS NULL    -- exclude salespersons
```

---

## 4. Inactive Contacts — Treat NULL as Active

`Inactive_Indicator` is `A` (active), `I` (inactive), or NULL (treat as active). Always filter:

```sql
AND ISNULL(c.Inactive_Indicator, 'A') <> 'I'
```

---

## 5. Sentinel Entity ID — Exclude 999,999,998

`Ckc_Id = 999,999,998` is a known invalid sentinel value in EQUIP. Exclude it wherever checking for a valid entity ID:

```sql
AND c.Ckc_Id IS NOT NULL
AND c.Ckc_Id <> 999999998
```

---

## 6. Upload File Column — Tax ID Full Header

The `DBS_Registry_UploadTemplate.csv` last column has a long name. Use exactly:

```sql
NULL AS [Tax ID used only in countryCode: AR AU BO BR BZ CL CO CR DO EC GF GT GY HN HT JM MX NI NZ PA PE PR PY SR SV TT UY VE]
```

---

## 7. B/I/C Business Logic for Upload Files

| EQUIP Type | Business Name | Person Name Fields | Fax |
|---|---|---|---|
| B (Business) | `company_name` | All NULL — forces entity-level match | `fax_no` → Work Fax |
| I (Individual) | NULL | All populated | `fax_no` → Home Fax |
| C (Business Contact) | `company_name` | All populated | `fax_no` → Work Fax |

```sql
CASE WHEN c.Business_Individual IN ('B','C') THEN c.company_name ELSE NULL END AS [Business Name],
CASE WHEN c.Business_Individual = 'B' THEN NULL ELSE c.name END AS [First Name],
-- (repeat for all person name fields)
CASE WHEN c.Business_Individual = 'I' THEN c.fax_no ELSE NULL END AS [Home Fax],
CASE WHEN c.Business_Individual IN ('B','C') THEN c.fax_no ELSE NULL END AS [Work Fax],
```

---

## 8. Ckc_Id / Cmp_Ckc_Id Semantics by Contact Type

| Type | `Ckc_Id` | `Cmp_Ckc_Id` |
|---|---|---|
| B or I | Own Registry Entity ID | Unused (null or 0) |
| C (Business Contact) | **Parent Business** Entity ID | Own Registry Contact ID |

When generating Path A upload (Create DBS Linkage), C-type Contact ID comes from `Cmp_Ckc_Id`, not `Ckc_Id`.

---

## 9. Phase 1.2 Population Filter (Salesforce Anvil-only customers)

Standard WHERE clause for querying the 12,818-record Phase 1.2 population:

```sql
WHERE sf.RecordTypeId = '0124W000001aGwlQAE'
  AND sf.Anvil__CustomerCompEntityID__c IS NOT NULL
  AND sf.H_Equip_contact_Ckc_Id__c IS NULL
  AND ISNULL(c.Inactive_Indicator, 'A') <> 'I'
  AND m.Code IS NULL    -- employee exclusion (requires WKMECHFL left join)
  AND s.CODE IS NULL    -- employee exclusion (requires VhSalman left join)
```

---

## 10. Deceased / Out-of-Business — Check customer_profile Before Accepting Tight Matches

`DDP.customer_profile` has `descd_ind` and `out_of_busn_ind` flags. Entity IDs sourced from Salesforce may point to entities that have since been marked deceased or out of business. The tight match algorithm will still succeed against these entities — there is no automatic exclusion. Check before accepting batches.

Use `contact_id = 0` to select the entity-level row (not a specific contact row):

```sql
LEFT JOIN DDP.customer_profile cp
    ON cp.entity_id   = <entity_id_column>
    AND cp.contact_id = 0
```

Flag records where:
- `cp.entity_id IS NULL` → entity not in Registry at all
- `cp.descd_ind = 'Y'` → deceased
- `cp.out_of_busn_ind = 'Y'` → out of business

See `queries/phase-1/block-7d.sql` for the full Phase 1.2 population check.

---

## 11. Employee Exclusion Applies to All Upload Queries

`Equip.contact` includes service technicians (`Equip.WKMECHFL`, `Code` column) and salespersons (`Equip.VhSalman`, `CODE` column). Both join 1:1 to `contact_code`. Exclude regardless of termination status — both tables retain terminated employees.

This exclusion must be in **every** query that produces an upload file or counts upload candidates. See also Rule 3 for the full pattern.

---

## 12. customer_profile Join — Always Filter on cross_ref_description

As of 2026-05-01, `DDP.customer_profile` has a `cross_ref_description` column. The same entity_id + contact_id pair now appears in multiple rows — one per source system. Without the filter, joins fan out and produce duplicate rows.

Known values: `'HUTSON INC Dealer XREF'` (our linkages) and `'EDA UCC-1 BUYERS'` (EDA dataset, edadata.com — not yet in Fabric).

Always add `cross_ref_description = 'HUTSON INC Dealer XREF'` to every join to `DDP.customer_profile`:

```sql
-- Entity-level health check (contact_id = 0 = entity row)
LEFT JOIN DDP.customer_profile cp
    ON cp.entity_id              = <entity_id_column>
    AND cp.contact_id            = 0
    AND cp.cross_ref_description = 'HUTSON INC Dealer XREF'

-- Contact-level join (C-type records)
LEFT JOIN DDP.customer_profile cp
    ON cp.entity_id              = <entity_id_column>
    AND cp.contact_id            = <contact_id_column>
    AND cp.cross_ref_description = 'HUTSON INC Dealer XREF'
```
