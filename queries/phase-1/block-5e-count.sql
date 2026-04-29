-- Block 5e-count: Sanity check for block-5e
-- Expected: ~49 total (674 original minus 625 case-sensitive false positives)

SELECT
    COUNT(*)                                                            AS total,
    SUM(CASE WHEN c.Business_Individual = 'B' THEN 1 ELSE 0 END)      AS business,
    SUM(CASE WHEN c.Business_Individual = 'I' THEN 1 ELSE 0 END)      AS individual,
    SUM(CASE WHEN c.Business_Individual = 'C' THEN 1 ELSE 0 END)      AS business_contact,
    SUM(CASE WHEN c.Business_Individual = 'C'
              AND c.Cmp_Ckc_Id > 0
              AND c.Cmp_Ckc_Id <> 999999998
         THEN 1 ELSE 0 END)                                            AS contact_with_contact_id
FROM Equip.contact c
LEFT JOIN DDP.customer_cross_ref xr
    ON UPPER(xr.cross_ref_number) = UPPER(c.contact_code)
LEFT JOIN Equip.WKMECHFL m ON m.Code = c.contact_code
LEFT JOIN Equip.VhSalman s ON s.CODE = c.contact_code
WHERE c.Ckc_Id IS NOT NULL
  AND c.Ckc_Id <> 999999998
  AND ISNULL(c.Inactive_Indicator, 'A') <> 'I'
  AND xr.cross_ref_number IS NULL
  AND m.Code IS NULL
  AND s.CODE IS NULL
