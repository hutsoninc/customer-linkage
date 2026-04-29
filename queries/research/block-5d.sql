-- Block 5d: Count false positives caused by case-sensitive cross_ref join
-- Records from block-5a that actually have a cross_ref entry but were missed due to case mismatch.

SELECT
    COUNT(*) AS false_positives
FROM Equip.contact c
LEFT JOIN DDP.customer_cross_ref xr_exact
    ON xr_exact.cross_ref_number = c.contact_code
LEFT JOIN DDP.customer_cross_ref xr_upper
    ON UPPER(xr_upper.cross_ref_number) = UPPER(c.contact_code)
WHERE c.Ckc_Id IS NOT NULL
  AND c.Ckc_Id <> 999999998
  AND ISNULL(c.Inactive_Indicator, 'A') <> 'I'
  AND xr_exact.cross_ref_number IS NULL      -- missed by exact match
  AND xr_upper.cross_ref_number IS NOT NULL  -- but found case-insensitively
