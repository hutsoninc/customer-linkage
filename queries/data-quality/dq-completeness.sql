-- Section 3: Completeness (Null/Blank Counts)
-- data-quality-plan.md § 3
-- Output conforms to data_quality_snapshot schema:
--   snapshot_date, metric_category, metric_name, contact_type,
--   sales_decile, staleness_bucket, branch, creation_cohort, numerator, denominator
-- Scope: all active non-employee contacts
-- Uses NULLIF(LTRIM(RTRIM(field)), '') to catch both NULLs and blank strings

WITH active_contacts AS (
    SELECT
        c.contact_code,
        c.Business_Individual,
        c.[name],
        c.surname,
        c.company_name,
        c.street,
        c.city,
        c.state,
        c.pcode,
        c.country,
        c.BusinessPhone,
        c.PrivatePhone,
        c.MobilePhone,
        c.email_address,
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
)
SELECT
    CAST(GETDATE() AS date) AS snapshot_date,
    'completeness'          AS metric_category,
    metric_name,
    contact_type,
    'ALL'                   AS sales_decile,
    'ALL'                   AS staleness_bucket,
    'ALL'                   AS branch,
    creation_cohort,
    SUM(is_missing)         AS numerator,
    COUNT(*)                AS denominator
FROM (

    SELECT 'missing_first_name' AS metric_name, Business_Individual AS contact_type,
           creation_cohort,
           CASE WHEN NULLIF(LTRIM(RTRIM([name])), '') IS NULL THEN 1 ELSE 0 END AS is_missing
    FROM active_contacts
    WHERE Business_Individual IN ('I', 'C')

    UNION ALL

    SELECT 'missing_last_name', Business_Individual, creation_cohort,
           CASE WHEN NULLIF(LTRIM(RTRIM(surname)), '') IS NULL THEN 1 ELSE 0 END
    FROM active_contacts
    WHERE Business_Individual IN ('I', 'C')

    UNION ALL

    SELECT 'missing_company_name', Business_Individual, creation_cohort,
           CASE WHEN NULLIF(LTRIM(RTRIM(company_name)), '') IS NULL THEN 1 ELSE 0 END
    FROM active_contacts
    WHERE Business_Individual = 'B'

    UNION ALL

    SELECT 'missing_street', 'ALL', creation_cohort,
           CASE WHEN NULLIF(LTRIM(RTRIM(street)), '') IS NULL THEN 1 ELSE 0 END
    FROM active_contacts

    UNION ALL

    SELECT 'missing_city', 'ALL', creation_cohort,
           CASE WHEN NULLIF(LTRIM(RTRIM(city)), '') IS NULL THEN 1 ELSE 0 END
    FROM active_contacts

    UNION ALL

    SELECT 'missing_state', 'ALL', creation_cohort,
           CASE WHEN NULLIF(LTRIM(RTRIM(state)), '') IS NULL THEN 1 ELSE 0 END
    FROM active_contacts

    UNION ALL

    SELECT 'missing_zip', 'ALL', creation_cohort,
           CASE WHEN NULLIF(LTRIM(RTRIM(pcode)), '') IS NULL THEN 1 ELSE 0 END
    FROM active_contacts

    UNION ALL

    SELECT 'missing_country', 'ALL', creation_cohort,
           CASE WHEN NULLIF(LTRIM(RTRIM(country)), '') IS NULL THEN 1 ELSE 0 END
    FROM active_contacts

    UNION ALL

    SELECT 'missing_email', 'ALL', creation_cohort,
           CASE WHEN NULLIF(LTRIM(RTRIM(email_address)), '') IS NULL THEN 1 ELSE 0 END
    FROM active_contacts

    UNION ALL

    SELECT 'missing_all_phones', 'ALL', creation_cohort,
           CASE
               WHEN NULLIF(LTRIM(RTRIM(BusinessPhone)), '') IS NULL
                AND NULLIF(LTRIM(RTRIM(PrivatePhone)),  '') IS NULL
                AND NULLIF(LTRIM(RTRIM(MobilePhone)),   '') IS NULL
               THEN 1 ELSE 0
           END
    FROM active_contacts

    UNION ALL

    SELECT 'no_contact_info', 'ALL', creation_cohort,
           CASE
               WHEN NULLIF(LTRIM(RTRIM(BusinessPhone)), '') IS NULL
                AND NULLIF(LTRIM(RTRIM(PrivatePhone)),  '') IS NULL
                AND NULLIF(LTRIM(RTRIM(MobilePhone)),   '') IS NULL
                AND NULLIF(LTRIM(RTRIM(email_address)), '') IS NULL
               THEN 1 ELSE 0
           END
    FROM active_contacts

) m
GROUP BY metric_name, contact_type, creation_cohort
ORDER BY metric_name, contact_type, creation_cohort;
