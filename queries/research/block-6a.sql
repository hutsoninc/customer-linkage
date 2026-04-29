-- Block 6a: Corrected 2a — cross_ref breakdown by contact type
-- Uses UPPER() join to fix case-sensitivity issue.

SELECT
    c.Business_Individual,
    CASE
        WHEN xr.contact_id IS NULL OR xr.contact_id = 0 THEN 'entity only'
        ELSE 'entity + contact_id'
    END                                         AS ref_type,
    COUNT(*)                                    AS row_count,
    COUNT(DISTINCT xr.entity_id)                AS distinct_entity_ids
FROM DDP.customer_cross_ref xr
JOIN Equip.contact c ON UPPER(c.contact_code) = UPPER(xr.cross_ref_number)
GROUP BY
    c.Business_Individual,
    CASE WHEN xr.contact_id IS NULL OR xr.contact_id = 0 THEN 'entity only' ELSE 'entity + contact_id' END
ORDER BY c.Business_Individual
