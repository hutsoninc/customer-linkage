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
        WHEN c.Business_Individual IN ('B', 'C') THEN c.company_name
        ELSE NULL
    END                                             AS [Business Name],

    c.Doing_Business_As                             AS [Doing Business As Name],

    -- Person name fields: stripped for B-type to force business entity match
    CASE WHEN c.Business_Individual = 'B' THEN NULL ELSE c.title          END AS [Prefix],
    CASE WHEN c.Business_Individual = 'B' THEN NULL ELSE c.name            END AS [First Name],
    CASE WHEN c.Business_Individual = 'B' THEN NULL ELSE c.Familiar_Name   END AS [Familiar Name],
    CASE WHEN c.Business_Individual = 'B' THEN NULL ELSE c.initial         END AS [Middle Name],
    CASE WHEN c.Business_Individual = 'B' THEN NULL ELSE c.surname         END AS [Last Name],
    CASE WHEN c.Business_Individual = 'B' THEN NULL ELSE c.Generation      END AS [Generation],
    CASE WHEN c.Business_Individual = 'B' THEN NULL ELSE c.Suffix          END AS [Suffix],

    -- Physical address
    c.street                                        AS [Address Line 1],
    c.street_2                                      AS [Address Line 2],
    c.city                                          AS [City],
    c.state                                         AS [State Code],
    c.pcode                                         AS [Postal Code],
    ISNULL(NULLIF(LTRIM(RTRIM(c.country)), ''), 'US') AS [Country Code],

    -- Contact info (used for potential match scoring)
    c.email_address                                 AS [Email Address],
    c.BusinessPhone                                 AS [Work Phone],
    c.PrivatePhone                                  AS [Home Phone],
    c.MobilePhone                                   AS [Mobile Phone],

    -- Fax: route to home or work depending on contact type
    CASE WHEN c.Business_Individual = 'I' THEN c.fax_no ELSE NULL END AS [Home Fax],
    CASE WHEN c.Business_Individual IN ('B','C') THEN c.fax_no ELSE NULL END AS [Work Fax],

    -- Tax: suppressed for US records
    NULL                                            AS [Tax Type],
    NULL                                            AS [Tax ID used only in countryCode: AR AU BO BR BZ CL CO CR DO EC GF GT GY HN HT JM MX NI NZ PA PE PR PY SR SV TT UY VE]

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
