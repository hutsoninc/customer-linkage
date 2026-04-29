-- Block 6h: Corrected 3d — validate the true "no cross_ref" SF customers
-- Uses UPPER() join to fix case-sensitivity issue.

SELECT
    COUNT(*)                                                        AS total,
    COUNT(c.Ckc_Id)                                                AS has_ckc_in_equip,
    SUM(CASE WHEN c.Ckc_Id = sf.H_Equip_contact_Ckc_Id__c
             THEN 1 ELSE 0 END)                                    AS ckc_agrees_with_sf
FROM Salesforce.Account sf
JOIN Equip.ArMaster ar
    ON ar.ACC_NO = sf.Anvil__AccountNumber__c
JOIN Equip.contact c
    ON c.contact_code = ar.contact_code
LEFT JOIN DDP.customer_cross_ref xr
    ON UPPER(xr.cross_ref_number) = UPPER(c.contact_code)
WHERE sf.RecordTypeId = '0124W000001aGwlQAE'
  AND sf.H_Equip_contact_Ckc_Id__c IS NOT NULL
  AND xr.entity_id IS NULL
