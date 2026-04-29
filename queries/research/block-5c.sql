-- Block 5c: Confirm cross_ref stores contact codes in uppercase
-- Finds records where cross_ref_number case differs from contact_code case.

SELECT TOP 30
    xr.cross_ref_number,
    c.contact_code,
    CASE WHEN xr.cross_ref_number = UPPER(xr.cross_ref_number) THEN 'upper' ELSE 'mixed/lower' END AS xr_case,
    CASE WHEN c.contact_code  = UPPER(c.contact_code)  THEN 'upper' ELSE 'mixed/lower' END AS equip_case
FROM DDP.customer_cross_ref xr
JOIN Equip.contact c
    ON UPPER(xr.cross_ref_number) = UPPER(c.contact_code)
WHERE xr.cross_ref_number <> c.contact_code
ORDER BY xr.cross_ref_number
