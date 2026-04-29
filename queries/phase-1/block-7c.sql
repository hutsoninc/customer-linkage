-- Block 7c: Post-upload validation — did the Customer Linkage Tool write back to EQUIP?
--
-- Run AFTER the Phase 1.2 Path B upload has been processed and the overnight sync has run.
-- Checks whether Ckc_Id was populated in Equip.contact for the records we linked.
--
-- If Ckc_Id is now populated → tool writes back to EQUIP when the field was blank (bidirectional, no-overwrite).
-- If Ckc_Id is still NULL → tool is one-directional; EQUIP requires separate remediation.

SELECT
    c.contact_code,
    c.Business_Individual,

    -- EQUIP entity ID — was it populated by the tool?
    c.Ckc_Id                                            AS equip_ckc_id,
    c.Cmp_Ckc_Id                                        AS equip_cmp_ckc_id,

    -- Registry linkage — what entity ID did the tool actually create?
    xr.entity_id                                        AS cross_ref_entity_id,
    xr.contact_id                                       AS cross_ref_contact_id,

    -- Salesforce entity ID (from quote workflow — was not updated by formal linkage)
    sf.Anvil__CustomerCompEntityID__c                   AS sf_anvil_entity_id,
    sf.H_Equip_contact_Ckc_Id__c                       AS sf_equip_entity_id,

    CASE
        WHEN xr.entity_id IS NULL         THEN 'Not Linked'
        WHEN c.Ckc_Id IS NULL             THEN 'Linked — EQUIP not updated'
        WHEN c.Ckc_Id = xr.entity_id     THEN 'Linked — EQUIP matches'
        ELSE                                   'Linked — EQUIP mismatch'
    END                                                 AS equip_writeback_status

FROM Salesforce.Account sf
JOIN Equip.ArMaster ar
    ON ar.ACC_NO = sf.Anvil__AccountNumber__c
JOIN Equip.contact c
    ON c.contact_code = ar.contact_code
LEFT JOIN DDP.customer_cross_ref xr
    ON UPPER(xr.cross_ref_number) = UPPER(c.contact_code)
WHERE sf.RecordTypeId = '0124W000001aGwlQAE'
  AND sf.Anvil__CustomerCompEntityID__c IS NOT NULL
  AND ISNULL(c.Inactive_Indicator, 'A') <> 'I'
ORDER BY equip_writeback_status, c.contact_code
