-- Block 6c: Corrected 2d — C-type entity-only linkages
-- Uses UPPER() join to fix case-sensitivity issue.

SELECT
    SUM(CASE WHEN c.Cmp_Ckc_Id IS NULL THEN 1 ELSE 0 END)  AS cmp_null,
    SUM(CASE WHEN c.Cmp_Ckc_Id = 0     THEN 1 ELSE 0 END)  AS cmp_zero,
    SUM(CASE WHEN c.Cmp_Ckc_Id > 0     THEN 1 ELSE 0 END)  AS cmp_populated,
    SUM(CASE WHEN c.Ckc_Id IS NOT NULL  THEN 1 ELSE 0 END)  AS has_ckc_id
FROM DDP.customer_cross_ref xr
JOIN Equip.contact c ON UPPER(c.contact_code) = UPPER(xr.cross_ref_number)
WHERE c.Business_Individual = 'C'
  AND (xr.contact_id IS NULL OR xr.contact_id = 0)
