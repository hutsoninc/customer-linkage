-- Section 6: Match Readiness
-- data-quality-plan.md § 6
-- Output conforms to data_quality_snapshot schema:
--   snapshot_date, metric_category, metric_name, contact_type,
--   sales_decile, staleness_bucket, branch, creation_cohort, numerator, denominator
-- Scope: unlinked active non-employee contacts only

WITH active_contacts AS (
    SELECT
        c.contact_code,
        c.Business_Individual,
        NULLIF(LTRIM(RTRIM(c.[name])),        '') AS first_name,
        NULLIF(LTRIM(RTRIM(c.surname)),       '') AS last_name,
        NULLIF(LTRIM(RTRIM(c.company_name)),  '') AS company_name,
        NULLIF(LTRIM(RTRIM(c.street)),        '') AS street,
        NULLIF(LTRIM(RTRIM(c.city)),          '') AS city,
        NULLIF(LTRIM(RTRIM(c.state)),         '') AS state,
        NULLIF(LTRIM(RTRIM(c.pcode)),         '') AS pcode,
        NULLIF(LTRIM(RTRIM(c.BusinessPhone)), '') AS biz_phone,
        NULLIF(LTRIM(RTRIM(c.PrivatePhone)),  '') AS priv_phone,
        NULLIF(LTRIM(RTRIM(c.MobilePhone)),   '') AS mob_phone,
        NULLIF(LTRIM(RTRIM(c.email_address)), '') AS email,
        CASE
            WHEN c.Creation_Date IS NULL              THEN 'Unknown'
            WHEN YEAR(c.Creation_Date) < 2016         THEN 'Pre-2015'
            WHEN YEAR(c.Creation_Date) <= 2020        THEN '2016-2020'
            WHEN YEAR(c.Creation_Date) <= 2025        THEN '2021-2025'
            ELSE                                           '2026+'
        END AS creation_cohort
    FROM [Bronze_Production_Lakehouse].[Equip].[contact] c
        LEFT JOIN [Bronze_Production_Lakehouse].[Equip].[WKMECHFL] wk
            ON wk.[Code] = c.contact_code
        LEFT JOIN [Bronze_Production_Lakehouse].[Equip].[VhSalman] vs
            ON vs.[CODE] = c.contact_code
    WHERE ISNULL(c.Inactive_Indicator, 'A') <> 'I'
      AND wk.[Code] IS NULL
      AND vs.[CODE] IS NULL
),
unlinked_contacts AS (
    SELECT ac.*
    FROM active_contacts ac
        LEFT JOIN [Bronze_Production_Lakehouse].[DDP].[customer_cross_ref] xr
            ON UPPER(xr.cross_ref_number) = UPPER(ac.contact_code)
           AND xr.entity_id <> 999999998
    WHERE xr.cross_ref_number IS NULL
),
tiered AS (
    SELECT
        contact_code,
        Business_Individual,
        creation_cohort,
        CASE
            WHEN Business_Individual IN ('I', 'C')
                 AND first_name IS NOT NULL
                 AND last_name  IS NOT NULL  THEN 1
            WHEN Business_Individual = 'B'
                 AND company_name IS NOT NULL THEN 1
            ELSE 0
        END AS has_name,
        CASE
            WHEN street IS NOT NULL AND city IS NOT NULL AND state IS NOT NULL THEN 1
            WHEN street IS NOT NULL AND pcode IS NOT NULL                       THEN 1
            ELSE 0
        END AS has_full_address,
        CASE
            WHEN street IS NOT NULL OR city  IS NOT NULL
              OR state  IS NOT NULL OR pcode IS NOT NULL THEN 1
            ELSE 0
        END AS has_partial_address,
        CASE
            WHEN biz_phone IS NOT NULL OR priv_phone IS NOT NULL
              OR mob_phone  IS NOT NULL OR email      IS NOT NULL THEN 1
            ELSE 0
        END AS has_contact_info
    FROM unlinked_contacts
),
tiered_with_label AS (
    SELECT
        contact_code,
        Business_Individual,
        creation_cohort,
        CASE
            WHEN has_name = 0                                                       THEN 4
            WHEN has_name = 1 AND has_full_address    = 1                           THEN 1
            WHEN has_name = 1 AND (has_partial_address = 1 OR has_contact_info = 1) THEN 2
            ELSE                                                                         3
        END AS tier
    FROM tiered
)
SELECT
    CAST(GETDATE() AS date)  AS snapshot_date,
    'match_readiness'        AS metric_category,
    CASE tier
        WHEN 1 THEN 'tier_1_strong'
        WHEN 2 THEN 'tier_2_partial'
        WHEN 3 THEN 'tier_3_name_only'
        WHEN 4 THEN 'tier_4_no_name'
    END                      AS metric_name,
    Business_Individual      AS contact_type,
    'ALL'                    AS sales_decile,
    'ALL'                    AS staleness_bucket,
    'ALL'                    AS branch,
    creation_cohort,
    COUNT(*)                 AS numerator,
    SUM(COUNT(*)) OVER (
        PARTITION BY Business_Individual, creation_cohort
    )                        AS denominator
FROM tiered_with_label
GROUP BY tier, Business_Individual, creation_cohort
ORDER BY tier, Business_Individual, creation_cohort;
