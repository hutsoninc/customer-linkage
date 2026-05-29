-- Block 7e: Phase 1.3 — Quote-to-sale gap: extract sold-to contact data for tight match upload
-- Finds units sold MTD where the sold-to EQUIP account differs from the quoted prospect,
-- the sold-to account has no entity ID, and the quoted prospect does have one.
-- Output is formatted to DBS_Registry_UploadTemplate.csv column order for Path B upload.
--
-- Filter to narrow date range (Anvil__SalesDate__c >= 'YYYY-MM-DD') before running.
-- After tight matches return, compare matched entity IDs against [Quoted Entity Id] —
-- agreement confirms the sold-to customer and quoted prospect are the same entity.
-- Use confirmed matches as Path A linkage candidates for the sold-to EQUIP account.

WITH SoldToDiffFromQuoted AS (
    SELECT
      dsu.Name AS [Stock Unit]
    , sold_to_account.Name AS [Sold To Account]
    , jdquote_account.Name AS [Quoted Account]
    , sold_to_account.Anvil__CustomerCompEntityID__c AS [Sold To Entity Id]
    , jdquote_account.Anvil__CustomerCompEntityID__c AS [Quoted Entity Id]
    , sold_to_account.Anvil__Contact_Code__c AS [Sold To Contact Code]
    , jdquote_account.Anvil__Contact_Code__c AS [Quoted Contact Code]
    , jdq.Name AS [Quote Name]
    , dsu.Anvil__SalesDate__c AS [Customer Invoice Date]
    , dsu.Id AS [Stock Unit Salesforce Id]
    , dsu.Anvil__Sold_JDQuote__c AS [Quote Salesforce Id]
    , dsu.Anvil__Account__c AS [Sold To Account Salesforce Id]
    , jdq.Anvil__Customer__c AS [Quoted Account Salesforce Id]
    FROM Salesforce.Anvil__DealerStockUnit__c dsu
    LEFT JOIN Salesforce.Account sold_to_account ON sold_to_account.Id = dsu.Anvil__Account__c
    LEFT JOIN Salesforce.Anvil__JDQuote__c jdq ON jdq.Id = dsu.Anvil__Sold_JDQuote__c
    LEFT JOIN Salesforce.Account jdquote_account ON jdquote_account.Id = jdq.Anvil__Customer__c
    WHERE 1 = 1
      AND sold_to_account.Id <> jdquote_account.Id
      AND dsu.Anvil__SalesDate__c IS NOT NULL
      AND dsu.Anvil__SalesDate__c >= '2026-05-01'
      AND sold_to_account.Anvil__CustomerCompEntityID__c IS NULL
      AND jdquote_account.Anvil__CustomerCompEntityID__c IS NOT NULL
      AND jdquote_account.Anvil__Contact_Code__c IS NULL
)

SELECT DISTINCT
  -- Salesforce account context
  s.[Sold To Account]
, s.[Quoted Account]
, s.[Sold To Entity Id]
, s.[Quoted Entity Id]
, s.[Sold To Contact Code]
, s.[Quoted Contact Code]

  -- Equip contact identity
, c.contact_code                                            AS [DBS Customer Number]
, CASE
      WHEN c.Business_Individual IN ('B', 'C') THEN NULLIF(LTRIM(RTRIM(c.company_name)), '')
      ELSE NULL
  END                                                       AS [Business Name]
, NULLIF(LTRIM(RTRIM(c.Doing_Business_As)), '')             AS [Doing Business As Name]
, CASE WHEN c.Business_Individual = 'B' THEN NULL ELSE NULLIF(LTRIM(RTRIM(c.title)),        '') END AS [Prefix]
, CASE WHEN c.Business_Individual = 'B' THEN NULL ELSE NULLIF(LTRIM(RTRIM(c.name)),         '') END AS [First Name]
, CASE WHEN c.Business_Individual = 'B' THEN NULL ELSE NULLIF(LTRIM(RTRIM(c.Familiar_Name)),'') END AS [Familiar Name]
, CASE WHEN c.Business_Individual = 'B' THEN NULL ELSE NULLIF(LTRIM(RTRIM(c.initial)),      '') END AS [Middle Name]
, CASE WHEN c.Business_Individual = 'B' THEN NULL ELSE NULLIF(LTRIM(RTRIM(c.surname)),      '') END AS [Last Name]
, CASE WHEN c.Business_Individual = 'B' THEN NULL ELSE NULLIF(LTRIM(RTRIM(c.Generation)),   '') END AS [Generation]
, CASE WHEN c.Business_Individual = 'B' THEN NULL ELSE NULLIF(LTRIM(RTRIM(c.Suffix)),       '') END AS [Suffix]

  -- Physical address
, NULLIF(LTRIM(RTRIM(c.street)),   '')                      AS [Address Line 1]
, NULLIF(LTRIM(RTRIM(c.street_2)), '')                      AS [Address Line 2]
, NULLIF(LTRIM(RTRIM(c.city)),     '')                      AS [City]
, NULLIF(LTRIM(RTRIM(c.state)),    '')                      AS [State Code]
, NULLIF(LTRIM(RTRIM(c.pcode)),    '')                      AS [Postal Code]
, ISNULL(NULLIF(LTRIM(RTRIM(c.country)), ''), 'US')         AS [Country Code]

  -- Contact info
, NULLIF(LTRIM(RTRIM(c.email_address)), '')                 AS [Email Address]
, NULLIF(LTRIM(RTRIM(c.BusinessPhone)), '')                 AS [Work Phone]
, NULLIF(LTRIM(RTRIM(c.PrivatePhone)),  '')                 AS [Home Phone]
, NULLIF(LTRIM(RTRIM(c.MobilePhone)),   '')                 AS [Mobile Phone]
, CASE WHEN c.Business_Individual = 'I'         THEN NULLIF(LTRIM(RTRIM(c.fax_no)), '') ELSE NULL END AS [Home Fax]
, CASE WHEN c.Business_Individual IN ('B', 'C') THEN NULLIF(LTRIM(RTRIM(c.fax_no)), '') ELSE NULL END AS [Work Fax]

  -- Tax (suppressed for US)
, NULL                                                      AS [Tax Type]
, NULL                                                      AS [Tax ID]

-- Additional columns for cross checking results
-- Exclude from tight match import
-- , c.Business_Individual AS [Contact Type]
-- , c.Ckc_Id AS [Equip Contact Entity ID]
-- , ISNULL(c.Cmp_Ckc_Id, 0) AS [Equip Company Entity ID]

FROM SoldToDiffFromQuoted s
INNER JOIN Equip.contact c ON c.contact_code = s.[Sold To Contact Code]

ORDER BY s.[Quoted Account]
