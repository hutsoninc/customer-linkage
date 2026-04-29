-- Block 6d: Corrected 2e — duplicate entity ID contact list
-- Uses UPPER() join to fix case-sensitivity issue.

SELECT
    xr.entity_id,
    COUNT(xr.cross_ref_number)                                  AS dbs_count,
    STRING_AGG(c.Business_Individual, ', ')
        WITHIN GROUP (ORDER BY xr.cross_ref_number)             AS contact_types,
    STRING_AGG(xr.cross_ref_number, ', ')
        WITHIN GROUP (ORDER BY xr.cross_ref_number)             AS contact_codes
FROM DDP.customer_cross_ref xr
JOIN Equip.contact c ON UPPER(c.contact_code) = UPPER(xr.cross_ref_number)
GROUP BY xr.entity_id
HAVING COUNT(xr.cross_ref_number) > 1
ORDER BY COUNT(xr.cross_ref_number) DESC
