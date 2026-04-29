-- Block 4b: Entity ID pattern across full Registry population
-- Deceased and OOB distribution by ID range to confirm temporal allocation.

SELECT
    LEFT(CAST(entity_id AS VARCHAR), 1)     AS leading_digit,
    COUNT(*)                                 AS total,
    SUM(CASE WHEN out_of_busn_ind = 'Y'
             THEN 1 ELSE 0 END)             AS out_of_business,
    SUM(CASE WHEN descd_ind = 'Y'
             THEN 1 ELSE 0 END)             AS deceased,
    MIN(entity_id)                           AS min_id,
    MAX(entity_id)                           AS max_id
FROM DDP.customer_profile
GROUP BY LEFT(CAST(entity_id AS VARCHAR), 1)
ORDER BY leading_digit
