-- Block 6f: Corrected 3b — SF vs. cross_ref entity ID agreement
-- Key baseline query. Uses UPPER() join to fix case-sensitivity issue.

SELECT
    COUNT(*)                                                            AS sf_customers_with_equip_ckc,
    SUM(CASE WHEN sf.H_Equip_contact_Ckc_Id__c = xr.entity_id  THEN 1 ELSE 0 END) AS ids_agree,
    SUM(CASE WHEN sf.H_Equip_contact_Ckc_Id__c != xr.entity_id THEN 1 ELSE 0 END) AS ids_disagree,
    SUM(CASE WHEN xr.entity_id IS NULL                          THEN 1 ELSE 0 END) AS no_cross_ref_found
FROM Salesforce.Account sf
JOIN Equip.ArMaster ar
    ON ar.ACC_NO = sf.Anvil__AccountNumber__c
JOIN Equip.contact c
    ON c.contact_code = ar.contact_code
LEFT JOIN DDP.customer_cross_ref xr
    ON UPPER(xr.cross_ref_number) = UPPER(c.contact_code)
WHERE sf.RecordTypeId = '0124W000001aGwlQAE'
  AND sf.H_Equip_contact_Ckc_Id__c IS NOT NULL
