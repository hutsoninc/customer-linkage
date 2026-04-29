-- Block 6b: Corrected 2c-revised — Ckc_Id / Cmp_Ckc_Id hypothesis
-- Uses UPPER() join to fix case-sensitivity issue.

SELECT
    COUNT(*)                                                              AS total_with_contact_id,
    SUM(CASE WHEN c.Ckc_Id      = xr.entity_id  THEN 1 ELSE 0 END)     AS ckc_matches_entity_id,
    SUM(CASE WHEN c.Cmp_Ckc_Id  = xr.contact_id THEN 1 ELSE 0 END)     AS cmp_matches_contact_id,
    SUM(CASE WHEN c.Ckc_Id      = xr.entity_id
             AND c.Cmp_Ckc_Id  = xr.contact_id  THEN 1 ELSE 0 END)     AS both_match
FROM DDP.customer_cross_ref xr
JOIN Equip.contact c ON UPPER(c.contact_code) = UPPER(xr.cross_ref_number)
WHERE xr.contact_id IS NOT NULL AND xr.contact_id != 0
