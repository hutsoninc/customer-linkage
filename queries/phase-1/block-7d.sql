-- Block 7d: Deceased / Out-of-Business check for Phase 1.2 tight match entity IDs
-- Reads all AGREE + DISAGREE tight match entity IDs from the reconciliation CSV
-- and checks each against DDP.customer_profile for descd_ind / out_of_busn_ind flags.
-- Run this before accepting any Phase 1.2 batches.
--
-- Paste the entity IDs from the reconciliation CSV into the IN list, or use
-- fabric_query.py to run this against a temp table approach if the list is large.
-- For the full 8,446-record population, use the Phase 1.2 SF population as the
-- source (same population as block-7a) joined to customer_profile via Anvil entity ID.

SELECT
    sf.Anvil__AccountNumber__c                              AS acc_no,
    ar.contact_code,
    sf.Anvil__CustomerCompEntityID__c                       AS sf_entity_id,
    cp.out_of_busn_ind,
    cp.descd_ind,
    cp.entity_type_cd,
    CASE
        WHEN cp.entity_id IS NULL    THEN 'NOT IN REGISTRY'
        WHEN cp.descd_ind      = 'Y' THEN 'DECEASED'
        WHEN cp.out_of_busn_ind = 'Y' THEN 'OUT OF BUSINESS'
        ELSE 'ACTIVE'
    END                                                     AS registry_status
FROM Salesforce.Account sf
JOIN Equip.ArMaster ar
    ON ar.ACC_NO = sf.Anvil__AccountNumber__c
JOIN Equip.contact c
    ON c.contact_code = ar.contact_code
LEFT JOIN Equip.WKMECHFL m ON m.Code = c.contact_code
LEFT JOIN Equip.VhSalman s ON s.CODE = c.contact_code
LEFT JOIN DDP.customer_profile cp
    ON cp.entity_id              = sf.Anvil__CustomerCompEntityID__c
    AND cp.contact_id            = 0
    AND cp.cross_ref_description = 'HUTSON INC Dealer XREF'
WHERE sf.RecordTypeId = '0124W000001aGwlQAE'
  AND sf.Anvil__CustomerCompEntityID__c IS NOT NULL
  AND sf.H_Equip_contact_Ckc_Id__c IS NULL
  AND ISNULL(c.Inactive_Indicator, 'A') <> 'I'
  AND m.Code IS NULL
  AND s.CODE IS NULL
  AND (
      cp.entity_id IS NULL
      OR cp.descd_ind      = 'Y'
      OR cp.out_of_busn_ind = 'Y'
  )
ORDER BY registry_status, ar.contact_code
