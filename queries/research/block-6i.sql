-- Block 6i: Corrected 4a — entity ID pattern by contact type
-- Uses UPPER() join to fix case-sensitivity issue.

SELECT
    LEFT(CAST(xr.entity_id AS VARCHAR), 1)      AS leading_digit,
    c.Business_Individual                         AS contact_type,
    CASE WHEN xr.contact_id IS NULL
              OR xr.contact_id = 0
         THEN 'entity only'
         ELSE 'entity + contact_id'
    END                                           AS ref_type,
    COUNT(*)                                      AS row_count,
    MIN(xr.entity_id)                             AS min_entity_id,
    MAX(xr.entity_id)                             AS max_entity_id
FROM DDP.customer_cross_ref xr
JOIN Equip.contact c ON UPPER(c.contact_code) = UPPER(xr.cross_ref_number)
GROUP BY
    LEFT(CAST(xr.entity_id AS VARCHAR), 1),
    c.Business_Individual,
    CASE WHEN xr.contact_id IS NULL
              OR xr.contact_id = 0
         THEN 'entity only'
         ELSE 'entity + contact_id'
    END
ORDER BY leading_digit, contact_type
