-- Block 6g: Corrected 3c — sample the SF / cross_ref disagreements
-- Uses UPPER() join to fix case-sensitivity issue.

SELECT TOP 50
    sf.Id                               AS sf_account_id,
    sf.Anvil__AccountNumber__c          AS account_number,
    sf.H_Equip_contact_Ckc_Id__c       AS sf_ckc_id,
    xr.entity_id                        AS cross_ref_entity_id,
    c.contact_code,
    c.Business_Individual
FROM Salesforce.Account sf
JOIN Equip.ArMaster ar
    ON ar.ACC_NO = sf.Anvil__AccountNumber__c
JOIN Equip.contact c
    ON c.contact_code = ar.contact_code
JOIN DDP.customer_cross_ref xr
    ON UPPER(xr.cross_ref_number) = UPPER(c.contact_code)
WHERE sf.RecordTypeId = '0124W000001aGwlQAE'
  AND sf.H_Equip_contact_Ckc_Id__c IS NOT NULL
  AND sf.H_Equip_contact_Ckc_Id__c != xr.entity_id
