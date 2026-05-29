-- Block 7a: Phase 1.2 — Extract contact data for Anvil-only SF customers
-- Target: SF Customer records with an Anvil entity ID but no formal EQUIP linkage.
-- Output matches DBS_Registry_UploadTemplate.csv column order for Path B upload.
--
-- Business logic applied:
--   B-type: person name fields stripped so Registry matches at business entity level
--   I-type: full person name fields included
--   C-type: both business name and person name included (links to specific contact)
--   Fax: home fax for individuals, work fax for businesses/contacts
--   Tax ID: suppressed (US records only)

SELECT
    c.contact_code                                  AS [DBS Customer Number],

    -- Business name (blank for pure individuals)
    CASE
        WHEN c.Business_Individual IN ('B', 'C') THEN NULLIF(LTRIM(RTRIM(c.company_name)), '')
        ELSE NULL
    END                                             AS [Business Name],

    NULLIF(LTRIM(RTRIM(c.Doing_Business_As)), '')   AS [Doing Business As Name],

    -- Person name fields: stripped for B-type to force business entity match
    CASE WHEN c.Business_Individual = 'B' THEN NULL ELSE NULLIF(LTRIM(RTRIM(c.title)),        '') END AS [Prefix],
    CASE WHEN c.Business_Individual = 'B' THEN NULL ELSE NULLIF(LTRIM(RTRIM(c.name)),         '') END AS [First Name],
    CASE WHEN c.Business_Individual = 'B' THEN NULL ELSE NULLIF(LTRIM(RTRIM(c.Familiar_Name)),'') END AS [Familiar Name],
    CASE WHEN c.Business_Individual = 'B' THEN NULL ELSE NULLIF(LTRIM(RTRIM(c.initial)),      '') END AS [Middle Name],
    CASE WHEN c.Business_Individual = 'B' THEN NULL ELSE NULLIF(LTRIM(RTRIM(c.surname)),      '') END AS [Last Name],
    CASE WHEN c.Business_Individual = 'B' THEN NULL ELSE NULLIF(LTRIM(RTRIM(c.Generation)),   '') END AS [Generation],
    CASE WHEN c.Business_Individual = 'B' THEN NULL ELSE NULLIF(LTRIM(RTRIM(c.Suffix)),       '') END AS [Suffix],

    -- Physical address
    NULLIF(LTRIM(RTRIM(c.street)),   '')            AS [Address Line 1],
    NULLIF(LTRIM(RTRIM(c.street_2)), '')            AS [Address Line 2],
    NULLIF(LTRIM(RTRIM(c.city)),     '')            AS [City],
    NULLIF(LTRIM(RTRIM(c.state)),    '')            AS [State Code],
    NULLIF(LTRIM(RTRIM(c.pcode)),    '')            AS [Postal Code],
    ISNULL(NULLIF(LTRIM(RTRIM(c.country)), ''), 'US') AS [Country Code],

    -- Contact info (used for potential match scoring)
    NULLIF(LTRIM(RTRIM(c.email_address)), '')       AS [Email Address],
    NULLIF(LTRIM(RTRIM(c.BusinessPhone)), '')       AS [Work Phone],
    NULLIF(LTRIM(RTRIM(c.PrivatePhone)),  '')       AS [Home Phone],
    NULLIF(LTRIM(RTRIM(c.MobilePhone)),   '')       AS [Mobile Phone],

    -- Fax: route to home or work depending on contact type
    CASE WHEN c.Business_Individual = 'I'        THEN NULLIF(LTRIM(RTRIM(c.fax_no)), '') ELSE NULL END AS [Home Fax],
    CASE WHEN c.Business_Individual IN ('B','C') THEN NULLIF(LTRIM(RTRIM(c.fax_no)), '') ELSE NULL END AS [Work Fax],

    -- Tax: suppressed for US records
    NULL                                            AS [Tax Type],
    NULL                                            AS [Tax ID]

    -- Additional columns for cross checking results
    -- Exclude from tight match import
    -- , c.Business_Individual AS [Contact Type]
    -- , c.Ckc_Id AS [Equip Contact Entity ID]
    -- , ISNULL(c.Cmp_Ckc_Id, 0) AS [Equip Company Entity ID]
    -- , sf.Anvil__CustomerCompEntityID__c AS [Salesforce Contact Entity ID]

FROM Salesforce.Account sf
JOIN Equip.ArMaster ar
    ON ar.ACC_NO = sf.Anvil__AccountNumber__c
JOIN Equip.contact c
    ON c.contact_code = ar.contact_code
LEFT JOIN Equip.WKMECHFL m
    ON m.Code = c.contact_code
LEFT JOIN Equip.VhSalman s
    ON s.CODE = c.contact_code
WHERE sf.RecordTypeId = '0124W000001aGwlQAE'
  AND sf.Anvil__CustomerCompEntityID__c IS NOT NULL
  AND sf.H_Equip_contact_Ckc_Id__c IS NULL
  AND ISNULL(c.Inactive_Indicator, 'A') <> 'I'
  AND m.Code IS NULL    -- exclude service technicians
  AND s.CODE IS NULL    -- exclude salespersons
ORDER BY c.contact_code
