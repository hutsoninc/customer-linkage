-- Block 7b: Validate Phase 1a entity/contact IDs against DDP.customer_profile
-- For B/I types: confirms the entity_id exists and is active in Registry.
-- For C types: confirms both the parent entity_id AND the contact_id exist.
-- Records missing from customer_profile were likely merged, deleted, or have a bad ID.

WITH phase1a AS (
    SELECT
        c.contact_code,
        c.Business_Individual,
        c.Ckc_Id                                        AS entity_id,
        CASE
            WHEN c.Business_Individual = 'C'
                AND c.Cmp_Ckc_Id IS NOT NULL
                AND c.Cmp_Ckc_Id > 0
                AND c.Cmp_Ckc_Id <> 999999998
            THEN c.Cmp_Ckc_Id
            ELSE NULL
        END                                             AS contact_id
    FROM Equip.contact c
    LEFT JOIN DDP.customer_cross_ref xr
        ON UPPER(xr.cross_ref_number) = UPPER(c.contact_code)
    WHERE c.Ckc_Id IS NOT NULL
      AND c.Ckc_Id <> 999999998
      AND ISNULL(c.Inactive_Indicator, 'A') <> 'I'
      AND xr.cross_ref_number IS NULL
)
SELECT
    p.contact_code,
    p.Business_Individual,
    p.entity_id,
    p.contact_id,

    -- Entity-level presence and health
    CASE WHEN cp_ent.entity_id IS NULL THEN 'Not Found' ELSE 'Found' END AS entity_in_registry,
    cp_ent.out_of_busn_ind                              AS entity_out_of_busn,
    cp_ent.descd_ind                                    AS entity_deceased,

    -- Contact-level presence (C-type only)
    CASE
        WHEN p.contact_id IS NULL     THEN 'N/A'
        WHEN cp_con.entity_id IS NULL THEN 'Not Found'
        ELSE                               'Found'
    END                                                 AS contact_in_registry

FROM phase1a p
LEFT JOIN DDP.customer_profile cp_ent
    ON cp_ent.entity_id = p.entity_id
    AND cp_ent.contact_id = 0
LEFT JOIN DDP.customer_profile cp_con
    ON cp_con.entity_id = p.entity_id
    AND cp_con.contact_id = p.contact_id
ORDER BY entity_in_registry DESC, contact_in_registry DESC, p.contact_code
