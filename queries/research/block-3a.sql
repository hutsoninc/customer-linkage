-- Block 3a: Salesforce account breakdown
-- Entity ID coverage across Salesforce Customer and Prospect records.

SELECT
    CASE RecordTypeId
        WHEN '0124W000001aGwlQAE' THEN 'Customer'
        WHEN '0124W000001aGwgQAE' THEN 'Prospect'
        ELSE 'Other'
    END                                                                 AS record_type,
    COUNT(*)                                                            AS total,
    COUNT(Anvil__AccountNumber__c)                                      AS has_account_number,
    COUNT(Anvil__CustomerCompEntityID__c)                               AS has_anvil_entity_id,
    COUNT(H_Equip_contact_Ckc_Id__c)                                   AS has_equip_ckc_id,
    SUM(CASE WHEN Anvil__CustomerCompEntityID__c IS NOT NULL
              AND H_Equip_contact_Ckc_Id__c IS NULL     THEN 1 ELSE 0 END) AS anvil_only,
    SUM(CASE WHEN H_Equip_contact_Ckc_Id__c IS NOT NULL THEN 1 ELSE 0 END) AS equip_sourced
FROM Salesforce.Account
GROUP BY RecordTypeId
ORDER BY record_type
