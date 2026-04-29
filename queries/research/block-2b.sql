-- Block 2b: Duplicate entity IDs (multiple DBS contacts per Registry entity)
-- Identify how many Registry entity_ids are linked to more than one EQUIP contact code.

SELECT
    links_per_entity,
    COUNT(*) AS entity_id_count
FROM (
    SELECT entity_id, COUNT(cross_ref_number) AS links_per_entity
    FROM DDP.customer_cross_ref
    GROUP BY entity_id
) t
GROUP BY links_per_entity
ORDER BY links_per_entity
