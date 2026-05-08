-- Section 4: Field Quality Checks
-- data-quality-plan.md § 4a–4g
-- Output conforms to data_quality_snapshot schema:
--   snapshot_date, metric_category, metric_name, contact_type,
--   sales_decile, staleness_bucket, branch, creation_cohort, numerator, denominator
-- Scope: all active non-employee contacts
-- Run dq-field-quality-coded-fields.sql separately for distinct suffix/prefix value surfacing

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
        c.title,
        c.Generation,
        c.Suffix,
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
    'field_quality'         AS metric_category,
    metric_name,
    contact_type,
    'ALL'                   AS sales_decile,
    'ALL'                   AS staleness_bucket,
    'ALL'                   AS branch,
    creation_cohort,
    SUM(is_flagged)         AS numerator,
    COUNT(*)                AS denominator
FROM (

    /* ── 4a. Status text in name fields (I, C) ───────────────────────────── */
    SELECT '4a_status_text_in_name' AS metric_name, Business_Individual AS contact_type,
           creation_cohort,
           CASE
               WHEN [name]  LIKE '%DECEASED%' OR [name]  LIKE '%OUT OF BUSINESS%'
                         OR [name]  LIKE '%DO NOT USE%' OR [name]  LIKE '%INACTIVE%'
                         OR [name]  LIKE '%CLOSED%'
                 OR surname LIKE '%DECEASED%' OR surname LIKE '%OUT OF BUSINESS%'
                         OR surname LIKE '%DO NOT USE%' OR surname LIKE '%INACTIVE%'
                         OR surname LIKE '%CLOSED%'
               THEN 1 ELSE 0
           END AS is_flagged
    FROM active_contacts
    WHERE Business_Individual IN ('I', 'C')

    UNION ALL

    /* ── 4a. Status text in company_name (B) ─────────────────────────────── */
    -- Note: OOB may produce false positives in business names — review results before acting
    SELECT '4a_status_text_in_company', Business_Individual, creation_cohort,
           CASE
               WHEN company_name LIKE '%DECEASED%'       OR company_name LIKE '%OUT OF BUSINESS%'
                 OR company_name LIKE '% OOB %'          OR company_name LIKE '%DO NOT USE%'
                 OR company_name LIKE '%INACTIVE%'        OR company_name LIKE '%CLOSED%'
               THEN 1 ELSE 0
           END
    FROM active_contacts
    WHERE Business_Individual = 'B'

    UNION ALL

    /* ── 4a. Status text in street field (all types) ─────────────────────── */
    SELECT '4a_status_text_in_street', Business_Individual, creation_cohort,
           CASE
               WHEN street LIKE '%DECEASED%'     OR street LIKE '%OUT OF BUSINESS%'
                 OR street LIKE '%DO NOT USE%'   OR street LIKE '%INACTIVE%'
                 OR street LIKE '%CLOSED%'
               THEN 1 ELSE 0
           END
    FROM active_contacts

    UNION ALL

    /* ── 4b. DBA in company_name field (B only) ──────────────────────────── */
    SELECT '4b_dba_in_company_name', Business_Individual, creation_cohort,
           CASE
               WHEN company_name LIKE '%DBA %'
                 OR company_name LIKE '%D/B/A%'
                 OR company_name LIKE '%DOING BUSINESS AS%'
               THEN 1 ELSE 0
           END
    FROM active_contacts
    WHERE Business_Individual = 'B'

    UNION ALL

    /* ── 4c. Prefix/salutation in name field (I, C) ──────────────────────── */
    SELECT '4c_prefix_in_name', Business_Individual, creation_cohort,
           CASE
               WHEN [name] LIKE 'MR.%'   OR [name] LIKE 'MR %'
                 OR [name] LIKE 'MRS.%'  OR [name] LIKE 'MRS %'
                 OR [name] LIKE 'MS.%'   OR [name] LIKE 'MS %'
                 OR [name] LIKE 'DR.%'   OR [name] LIKE 'DR %'
                 OR [name] LIKE 'REV.%'  OR [name] LIKE 'REV %'
                 OR [name] LIKE 'PROF.%' OR [name] LIKE 'PROF %'
               THEN 1 ELSE 0
           END
    FROM active_contacts
    WHERE Business_Individual IN ('I', 'C')

    UNION ALL

    /* ── 4c. Generation/suffix in surname field (I, C) ───────────────────── */
    SELECT '4c_suffix_in_surname', Business_Individual, creation_cohort,
           CASE
               WHEN surname LIKE '% JR'   OR surname LIKE '% JR.'
                 OR surname LIKE '% SR'   OR surname LIKE '% SR.'
                 OR surname LIKE '% II'   OR surname LIKE '% III'
                 OR surname LIKE '% IV'   OR surname LIKE '% V'
                 OR surname LIKE '% MD'   OR surname LIKE '% PHD'
                 OR surname LIKE '% CPA'  OR surname LIKE '% ESQ'
                 OR surname LIKE '% DDS'  OR surname LIKE '% DO'
               THEN 1 ELSE 0
           END
    FROM active_contacts
    WHERE Business_Individual IN ('I', 'C')

    UNION ALL

    /* ── 4c. Combined names in name field — should be separate records ────── */
    SELECT '4c_combined_names_in_name', Business_Individual, creation_cohort,
           CASE
               WHEN [name] LIKE '%&%'
                 OR [name] LIKE '% AND %'
                 OR [name] LIKE '%/%'
               THEN 1 ELSE 0
           END
    FROM active_contacts
    WHERE Business_Individual IN ('I', 'C')

    UNION ALL

    /* ── 4c. Familiar name (nickname in parens) e.g. "Billy (Joe)" ────────── */
    SELECT '4c_familiar_name_pattern', Business_Individual, creation_cohort,
           CASE WHEN [name] LIKE '%(%)%' THEN 1 ELSE 0 END
    FROM active_contacts
    WHERE Business_Individual IN ('I', 'C')

    UNION ALL

    /* ── 4d. Email structurally invalid (has value but missing @domain.tld) ─ */
    SELECT '4d_email_invalid_format', Business_Individual, creation_cohort,
           CASE
               WHEN NULLIF(LTRIM(RTRIM(email_address)), '') IS NOT NULL
                AND email_address NOT LIKE '%@%.%'
               THEN 1 ELSE 0
           END
    FROM active_contacts

    UNION ALL

    /* ── 4d. Known placeholder email patterns ─────────────────────────────── */
    SELECT '4d_email_placeholder', Business_Individual, creation_cohort,
           CASE
               WHEN LOWER(email_address) LIKE 'noemail@%'
                 OR LOWER(email_address) LIKE 'test@test%'
                 OR LOWER(email_address) LIKE 'none@none%'
                 OR LOWER(email_address) LIKE 'nomail@%'
                 OR LOWER(email_address) LIKE 'donotcontact@%'
                 OR LOWER(email_address) LIKE 'noreply@%'
               THEN 1 ELSE 0
           END
    FROM active_contacts
    WHERE NULLIF(LTRIM(RTRIM(email_address)), '') IS NOT NULL

    UNION ALL

    /* ── 4d. Internal/Deere email on customer record ─────────────────────── */
    SELECT '4d_email_internal_deere', Business_Individual, creation_cohort,
           CASE
               WHEN email_address LIKE '%@deere.com'
                 OR email_address LIKE '%@johndeere.com'
               THEN 1 ELSE 0
           END
    FROM active_contacts
    WHERE NULLIF(LTRIM(RTRIM(email_address)), '') IS NOT NULL

    UNION ALL

    /* ── 4e. BusinessPhone — all zeros ───────────────────────────────────── */
    SELECT '4e_biz_phone_allzeros', Business_Individual, creation_cohort,
           CASE WHEN BusinessPhone = '0000000000' THEN 1 ELSE 0 END
    FROM active_contacts
    WHERE NULLIF(LTRIM(RTRIM(BusinessPhone)), '') IS NOT NULL

    UNION ALL

    /* ── 4e. BusinessPhone — sequential placeholder ───────────────────────── */
    SELECT '4e_biz_phone_sequential', Business_Individual, creation_cohort,
           CASE WHEN BusinessPhone = '1234567890' THEN 1 ELSE 0 END
    FROM active_contacts
    WHERE NULLIF(LTRIM(RTRIM(BusinessPhone)), '') IS NOT NULL

    UNION ALL

    /* ── 4e. BusinessPhone — all same digit (e.g. 1111111111) ───────────── */
    SELECT '4e_biz_phone_repeated_digit', Business_Individual, creation_cohort,
           CASE
               WHEN LEN(BusinessPhone) = 10
                AND BusinessPhone = REPLICATE(LEFT(BusinessPhone, 1), 10)
               THEN 1 ELSE 0
           END
    FROM active_contacts
    WHERE NULLIF(LTRIM(RTRIM(BusinessPhone)), '') IS NOT NULL

    UNION ALL

    /* ── 4e. BusinessPhone — wrong length ────────────────────────────────── */
    SELECT '4e_biz_phone_wrong_length', Business_Individual, creation_cohort,
           CASE
               WHEN LEN(LTRIM(RTRIM(BusinessPhone))) NOT IN (10, 11)
               THEN 1 ELSE 0
           END
    FROM active_contacts
    WHERE NULLIF(LTRIM(RTRIM(BusinessPhone)), '') IS NOT NULL

    UNION ALL

    /* ── 4e. PrivatePhone — all zeros ────────────────────────────────────── */
    SELECT '4e_priv_phone_allzeros', Business_Individual, creation_cohort,
           CASE WHEN PrivatePhone = '0000000000' THEN 1 ELSE 0 END
    FROM active_contacts
    WHERE NULLIF(LTRIM(RTRIM(PrivatePhone)), '') IS NOT NULL

    UNION ALL

    /* ── 4e. PrivatePhone — sequential placeholder ───────────────────────── */
    SELECT '4e_priv_phone_sequential', Business_Individual, creation_cohort,
           CASE WHEN PrivatePhone = '1234567890' THEN 1 ELSE 0 END
    FROM active_contacts
    WHERE NULLIF(LTRIM(RTRIM(PrivatePhone)), '') IS NOT NULL

    UNION ALL

    /* ── 4e. PrivatePhone — all same digit ───────────────────────────────── */
    SELECT '4e_priv_phone_repeated_digit', Business_Individual, creation_cohort,
           CASE
               WHEN LEN(PrivatePhone) = 10
                AND PrivatePhone = REPLICATE(LEFT(PrivatePhone, 1), 10)
               THEN 1 ELSE 0
           END
    FROM active_contacts
    WHERE NULLIF(LTRIM(RTRIM(PrivatePhone)), '') IS NOT NULL

    UNION ALL

    /* ── 4e. PrivatePhone — wrong length ─────────────────────────────────── */
    SELECT '4e_priv_phone_wrong_length', Business_Individual, creation_cohort,
           CASE
               WHEN LEN(LTRIM(RTRIM(PrivatePhone))) NOT IN (10, 11)
               THEN 1 ELSE 0
           END
    FROM active_contacts
    WHERE NULLIF(LTRIM(RTRIM(PrivatePhone)), '') IS NOT NULL

    UNION ALL

    /* ── 4e. MobilePhone — all zeros ─────────────────────────────────────── */
    SELECT '4e_mob_phone_allzeros', Business_Individual, creation_cohort,
           CASE WHEN MobilePhone = '0000000000' THEN 1 ELSE 0 END
    FROM active_contacts
    WHERE NULLIF(LTRIM(RTRIM(MobilePhone)), '') IS NOT NULL

    UNION ALL

    /* ── 4e. MobilePhone — sequential placeholder ────────────────────────── */
    SELECT '4e_mob_phone_sequential', Business_Individual, creation_cohort,
           CASE WHEN MobilePhone = '1234567890' THEN 1 ELSE 0 END
    FROM active_contacts
    WHERE NULLIF(LTRIM(RTRIM(MobilePhone)), '') IS NOT NULL

    UNION ALL

    /* ── 4e. MobilePhone — all same digit ────────────────────────────────── */
    SELECT '4e_mob_phone_repeated_digit', Business_Individual, creation_cohort,
           CASE
               WHEN LEN(MobilePhone) = 10
                AND MobilePhone = REPLICATE(LEFT(MobilePhone, 1), 10)
               THEN 1 ELSE 0
           END
    FROM active_contacts
    WHERE NULLIF(LTRIM(RTRIM(MobilePhone)), '') IS NOT NULL

    UNION ALL

    /* ── 4e. MobilePhone — wrong length ──────────────────────────────────── */
    SELECT '4e_mob_phone_wrong_length', Business_Individual, creation_cohort,
           CASE
               WHEN LEN(LTRIM(RTRIM(MobilePhone))) NOT IN (10, 11)
               THEN 1 ELSE 0
           END
    FROM active_contacts
    WHERE NULLIF(LTRIM(RTRIM(MobilePhone)), '') IS NOT NULL

    UNION ALL

    /* ── 4f. State not 2 characters ──────────────────────────────────────── */
    SELECT '4f_state_not_2char', Business_Individual, creation_cohort,
           CASE WHEN LEN(LTRIM(RTRIM(state))) <> 2 THEN 1 ELSE 0 END
    FROM active_contacts
    WHERE NULLIF(LTRIM(RTRIM(state)), '') IS NOT NULL

    UNION ALL

    /* ── 4f. Country not 2 characters ────────────────────────────────────── */
    SELECT '4f_country_not_2char', Business_Individual, creation_cohort,
           CASE WHEN LEN(LTRIM(RTRIM(country))) <> 2 THEN 1 ELSE 0 END
    FROM active_contacts
    WHERE NULLIF(LTRIM(RTRIM(country)), '') IS NOT NULL

    UNION ALL

    /* ── 4f. Country written out instead of ISO-2 code ───────────────────── */
    SELECT '4f_country_written_out', Business_Individual, creation_cohort,
           CASE
               WHEN UPPER(LTRIM(RTRIM(country))) IN (
                   'UNITED STATES', 'UNITED STATES OF AMERICA', 'USA', 'US OF A',
                   'CANADA', 'MEXICO', 'AUSTRALIA', 'NEW ZEALAND'
               )
               THEN 1 ELSE 0
           END
    FROM active_contacts
    WHERE NULLIF(LTRIM(RTRIM(country)), '') IS NOT NULL

    UNION ALL

    /* ── 4f. Zip not 5 digits (US contacts only) ─────────────────────────── */
    SELECT '4f_zip_not_5digits', Business_Individual, creation_cohort,
           CASE
               WHEN pcode NOT LIKE '[0-9][0-9][0-9][0-9][0-9]'
                AND pcode NOT LIKE '[0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]'
               THEN 1 ELSE 0
           END
    FROM active_contacts
    WHERE NULLIF(LTRIM(RTRIM(pcode)), '') IS NOT NULL
      AND ISNULL(NULLIF(LTRIM(RTRIM(country)), ''), 'US') = 'US'

    UNION ALL

    /* ── 4g. Generation field — unrecognized value (I, C) ────────────────── */
    SELECT '4g_generation_unrecognized', Business_Individual, creation_cohort,
           CASE
               WHEN UPPER(LTRIM(RTRIM(Generation))) NOT IN (
                   'JR', 'JR.', 'JUNIOR',
                   'SR', 'SR.', 'SENIOR',
                   'II', 'III', 'IV', 'V'
               )
               THEN 1 ELSE 0
           END
    FROM active_contacts
    WHERE Business_Individual IN ('I', 'C')
      AND NULLIF(LTRIM(RTRIM(Generation)), '') IS NOT NULL

) m
GROUP BY metric_name, contact_type, creation_cohort
ORDER BY metric_name, contact_type, creation_cohort;
