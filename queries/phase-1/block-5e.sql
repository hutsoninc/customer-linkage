-- Block 5e: Corrected Phase 1.1 extraction — genuinely unlinked informal EQUIP records
-- Contacts with a CKC ID in EQUIP but no formal cross_ref entry.
-- Output matches Create_Bulk_Linkages_Template.csv column order.
-- Upload via Customer Linkage Tool → Create DBS Linkage (Path A).

SELECT
    c.contact_code                                      AS [DBS Number],
    c.Ckc_Id                                            AS [Entity Id],
    CASE
        WHEN c.Business_Individual = 'C'
             AND c.Cmp_Ckc_Id IS NOT NULL
             AND c.Cmp_Ckc_Id > 0
             AND c.Cmp_Ckc_Id <> 999999998
        THEN c.Cmp_Ckc_Id
        ELSE NULL
    END                                                 AS [Contact Id]
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
ORDER BY c.contact_code
