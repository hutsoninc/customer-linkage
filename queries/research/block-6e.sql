-- Block 6e: Corrected 2f — duplicate type combination summary
-- Uses UPPER() join to fix case-sensitivity issue.

SELECT
    type_combo,
    COUNT(*) AS entity_count
FROM (
    SELECT
        entity_id,
        STRING_AGG(c.Business_Individual, '+')
            WITHIN GROUP (ORDER BY c.Business_Individual) AS type_combo
    FROM DDP.customer_cross_ref xr
    JOIN Equip.contact c ON UPPER(c.contact_code) = UPPER(xr.cross_ref_number)
    GROUP BY xr.entity_id
    HAVING COUNT(xr.cross_ref_number) > 1
) t
GROUP BY type_combo
ORDER BY entity_count DESC
