-- Section 2: Registry Parity
-- data-quality-plan.md § 2
-- Output conforms to data_quality_snapshot schema:
--   snapshot_date, metric_category, metric_name, contact_type,
--   sales_decile, staleness_bucket, branch, creation_cohort, numerator, denominator
-- Scope: linked active non-employee contacts
-- metric_name = <field>_match | <field>_mismatch | <field>_equip_only | <field>_registry_only | <field>_both_null
-- denominator = total linked contacts in scope for that field + contact_type + cohort
-- Phone comparison: Registry stores area_cd + phone_num split; EQUIP stores 10-digit string

WITH active_linked AS (
    SELECT
        c.contact_code,
        c.Business_Individual,
        -- EQUIP fields (normalize blanks → NULL)
        NULLIF(LTRIM(RTRIM(c.company_name)),   '') AS company_name,
        NULLIF(LTRIM(RTRIM(c.[name])),         '') AS first_name,
        NULLIF(LTRIM(RTRIM(c.surname)),        '') AS last_name,
        NULLIF(LTRIM(RTRIM(c.email_address)),  '') AS email,
        NULLIF(LTRIM(RTRIM(c.BusinessPhone)),  '') AS biz_phone,
        NULLIF(LTRIM(RTRIM(c.PrivatePhone)),   '') AS priv_phone,
        NULLIF(LTRIM(RTRIM(c.MobilePhone)),    '') AS mob_phone,
        NULLIF(LTRIM(RTRIM(c.street)),         '') AS street,
        NULLIF(LTRIM(RTRIM(c.city)),           '') AS city,
        NULLIF(LTRIM(RTRIM(c.state)),          '') AS state,
        NULLIF(LTRIM(RTRIM(c.pcode)),          '') AS pcode,
        NULLIF(LTRIM(RTRIM(c.country)), '') AS country,
        -- Registry fields (customer_profile)
        NULLIF(LTRIM(RTRIM(cp.nm1_txt)),            '') AS reg_company_name,
        NULLIF(LTRIM(RTRIM(cp.first_nm)),           '') AS reg_first_name,
        NULLIF(LTRIM(RTRIM(cp.last_nm)),            '') AS reg_last_name,
        NULLIF(LTRIM(RTRIM(cp.email_addr_txt)),     '') AS reg_email,
        NULLIF(LTRIM(RTRIM(cp.work_area_cd)),       '') AS reg_biz_area,
        NULLIF(LTRIM(RTRIM(cp.work_phone_num)),     '') AS reg_biz_num,
        NULLIF(LTRIM(RTRIM(cp.home_area_cd)),       '') AS reg_priv_area,
        NULLIF(LTRIM(RTRIM(cp.home_phone_num)),     '') AS reg_priv_num,
        NULLIF(LTRIM(RTRIM(cp.mobile_area_cd)),     '') AS reg_mob_area,
        NULLIF(LTRIM(RTRIM(cp.mobile_phone_num)),   '') AS reg_mob_num,
        NULLIF(LTRIM(RTRIM(cp.phys_street1_txt)),   '') AS reg_street,
        NULLIF(LTRIM(RTRIM(cp.phys_city)),          '') AS reg_city,
        NULLIF(LTRIM(RTRIM(cp.phys_state_prov_cd)), '') AS reg_state,
        NULLIF(LTRIM(RTRIM(cp.phys_postal_cd)),     '') AS reg_pcode,
        NULLIF(LTRIM(RTRIM(cp.phys_iso2_cntry_cd)), '') AS reg_country,
        -- Registry quality flags
        cp.phys_postal_certified,
        cp.phys_undeliverable_ind,
        cp.mail_undeliverable_ind,
        -- Cohort
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
        INNER JOIN [Bronze_Production_Lakehouse].[DDP].[customer_cross_ref] xr
            ON UPPER(xr.cross_ref_number) = UPPER(c.contact_code)
           AND xr.entity_id <> 999999998
        INNER JOIN [Bronze_Production_Lakehouse].[DDP].[customer_profile] cp
            ON cp.entity_id              = xr.entity_id
           AND cp.contact_id             = xr.contact_id
           AND xr.cross_ref_description  = 'HUTSON INC Dealer XREF'
    WHERE ISNULL(c.Inactive_Indicator, 'A') <> 'I'
      AND wk.[Code] IS NULL
      AND vs.[CODE] IS NULL
),

/* Per-contact per-field parity result; field_name kept for denominator partitioning */
field_parity AS (

    SELECT 'company_name' AS field_name, Business_Individual AS contact_type, creation_cohort,
           CASE
               WHEN company_name IS NULL     AND reg_company_name IS NULL     THEN 'both_null'
               WHEN company_name IS NOT NULL AND reg_company_name IS NULL     THEN 'equip_only'
               WHEN company_name IS NULL     AND reg_company_name IS NOT NULL THEN 'registry_only'
               WHEN UPPER(company_name) = UPPER(reg_company_name)             THEN 'match'
               ELSE 'mismatch'
           END AS parity_result
    FROM active_linked WHERE Business_Individual = 'B'

    UNION ALL

    SELECT 'first_name', Business_Individual, creation_cohort,
           CASE
               WHEN first_name IS NULL     AND reg_first_name IS NULL     THEN 'both_null'
               WHEN first_name IS NOT NULL AND reg_first_name IS NULL     THEN 'equip_only'
               WHEN first_name IS NULL     AND reg_first_name IS NOT NULL THEN 'registry_only'
               WHEN UPPER(first_name) = UPPER(reg_first_name)             THEN 'match'
               ELSE 'mismatch'
           END
    FROM active_linked WHERE Business_Individual IN ('I', 'C')

    UNION ALL

    SELECT 'last_name', Business_Individual, creation_cohort,
           CASE
               WHEN last_name IS NULL     AND reg_last_name IS NULL     THEN 'both_null'
               WHEN last_name IS NOT NULL AND reg_last_name IS NULL     THEN 'equip_only'
               WHEN last_name IS NULL     AND reg_last_name IS NOT NULL THEN 'registry_only'
               WHEN UPPER(last_name) = UPPER(reg_last_name)             THEN 'match'
               ELSE 'mismatch'
           END
    FROM active_linked WHERE Business_Individual IN ('I', 'C')

    UNION ALL

    SELECT 'email', Business_Individual, creation_cohort,
           CASE
               WHEN email IS NULL     AND reg_email IS NULL     THEN 'both_null'
               WHEN email IS NOT NULL AND reg_email IS NULL     THEN 'equip_only'
               WHEN email IS NULL     AND reg_email IS NOT NULL THEN 'registry_only'
               WHEN LOWER(email) = LOWER(reg_email)             THEN 'match'
               ELSE 'mismatch'
           END
    FROM active_linked

    UNION ALL

    SELECT 'business_phone', Business_Individual, creation_cohort,
           CASE
               WHEN biz_phone IS NULL AND reg_biz_area IS NULL AND reg_biz_num IS NULL
                   THEN 'both_null'
               WHEN biz_phone IS NOT NULL AND reg_biz_area IS NULL AND reg_biz_num IS NULL
                   THEN 'equip_only'
               WHEN biz_phone IS NULL AND (reg_biz_area IS NOT NULL OR reg_biz_num IS NOT NULL)
                   THEN 'registry_only'
               WHEN biz_phone = ISNULL(reg_biz_area, '') + ISNULL(reg_biz_num, '')
                   THEN 'match'
               ELSE 'mismatch'
           END
    FROM active_linked

    UNION ALL

    SELECT 'private_phone', Business_Individual, creation_cohort,
           CASE
               WHEN priv_phone IS NULL AND reg_priv_area IS NULL AND reg_priv_num IS NULL
                   THEN 'both_null'
               WHEN priv_phone IS NOT NULL AND reg_priv_area IS NULL AND reg_priv_num IS NULL
                   THEN 'equip_only'
               WHEN priv_phone IS NULL AND (reg_priv_area IS NOT NULL OR reg_priv_num IS NOT NULL)
                   THEN 'registry_only'
               WHEN priv_phone = ISNULL(reg_priv_area, '') + ISNULL(reg_priv_num, '')
                   THEN 'match'
               ELSE 'mismatch'
           END
    FROM active_linked

    UNION ALL

    SELECT 'mobile_phone', Business_Individual, creation_cohort,
           CASE
               WHEN mob_phone IS NULL AND reg_mob_area IS NULL AND reg_mob_num IS NULL
                   THEN 'both_null'
               WHEN mob_phone IS NOT NULL AND reg_mob_area IS NULL AND reg_mob_num IS NULL
                   THEN 'equip_only'
               WHEN mob_phone IS NULL AND (reg_mob_area IS NOT NULL OR reg_mob_num IS NOT NULL)
                   THEN 'registry_only'
               WHEN mob_phone = ISNULL(reg_mob_area, '') + ISNULL(reg_mob_num, '')
                   THEN 'match'
               ELSE 'mismatch'
           END
    FROM active_linked

    UNION ALL

    SELECT 'street', Business_Individual, creation_cohort,
           CASE
               WHEN street IS NULL     AND reg_street IS NULL     THEN 'both_null'
               WHEN street IS NOT NULL AND reg_street IS NULL     THEN 'equip_only'
               WHEN street IS NULL     AND reg_street IS NOT NULL THEN 'registry_only'
               WHEN UPPER(street) = UPPER(reg_street)             THEN 'match'
               ELSE 'mismatch'
           END
    FROM active_linked

    UNION ALL

    SELECT 'city', Business_Individual, creation_cohort,
           CASE
               WHEN city IS NULL     AND reg_city IS NULL     THEN 'both_null'
               WHEN city IS NOT NULL AND reg_city IS NULL     THEN 'equip_only'
               WHEN city IS NULL     AND reg_city IS NOT NULL THEN 'registry_only'
               WHEN UPPER(city) = UPPER(reg_city)             THEN 'match'
               ELSE 'mismatch'
           END
    FROM active_linked

    UNION ALL

    SELECT 'state', Business_Individual, creation_cohort,
           CASE
               WHEN state IS NULL     AND reg_state IS NULL     THEN 'both_null'
               WHEN state IS NOT NULL AND reg_state IS NULL     THEN 'equip_only'
               WHEN state IS NULL     AND reg_state IS NOT NULL THEN 'registry_only'
               WHEN UPPER(state) = UPPER(reg_state)             THEN 'match'
               ELSE 'mismatch'
           END
    FROM active_linked

    UNION ALL

    SELECT 'zip', Business_Individual, creation_cohort,
           CASE
               WHEN pcode IS NULL     AND reg_pcode IS NULL     THEN 'both_null'
               WHEN pcode IS NOT NULL AND reg_pcode IS NULL     THEN 'equip_only'
               WHEN pcode IS NULL     AND reg_pcode IS NOT NULL THEN 'registry_only'
               WHEN UPPER(pcode) = UPPER(reg_pcode)             THEN 'match'
               ELSE 'mismatch'
           END
    FROM active_linked

    UNION ALL

    SELECT 'country', Business_Individual, creation_cohort,
           CASE
               WHEN country IS NULL     AND reg_country IS NULL     THEN 'both_null'
               WHEN country IS NOT NULL AND reg_country IS NULL     THEN 'equip_only'
               WHEN country IS NULL     AND reg_country IS NOT NULL THEN 'registry_only'
               WHEN UPPER(country) = UPPER(reg_country)             THEN 'match'
               ELSE 'mismatch'
           END
    FROM active_linked
)

/* ── Field-level parity rows ─────────────────────────────────────── */
SELECT
    CAST(GETDATE() AS date)                      AS snapshot_date,
    'parity'                                     AS metric_category,
    field_name + '_' + parity_result             AS metric_name,
    contact_type,
    'ALL'                                        AS sales_decile,
    'ALL'                                        AS staleness_bucket,
    'ALL'                                        AS branch,
    creation_cohort,
    COUNT(*)                                     AS numerator,
    SUM(COUNT(*)) OVER (
        PARTITION BY field_name, contact_type, creation_cohort
    )                                            AS denominator
FROM field_parity
GROUP BY field_name, parity_result, contact_type, creation_cohort

UNION ALL

/* ── Priority: Registry certified address differs from EQUIP ─────── */
SELECT
    CAST(GETDATE() AS date), 'parity', 'phys_addr_certified_mismatch',
    Business_Individual, 'ALL', 'ALL', 'ALL', creation_cohort,
    COUNT(*),
    SUM(COUNT(*)) OVER (PARTITION BY Business_Individual, creation_cohort)
FROM active_linked
WHERE phys_postal_certified = 'CERTIFIED'
  AND (
       UPPER(ISNULL(street, '')) <> UPPER(ISNULL(reg_street, ''))
    OR UPPER(ISNULL(city,   '')) <> UPPER(ISNULL(reg_city,   ''))
    OR UPPER(ISNULL(state,  '')) <> UPPER(ISNULL(reg_state,  ''))
    OR UPPER(ISNULL(pcode,  '')) <> UPPER(ISNULL(reg_pcode,  ''))
  )
GROUP BY Business_Individual, creation_cohort

UNION ALL

/* ── Priority: Registry confirmed undeliverable address ──────────── */
SELECT
    CAST(GETDATE() AS date), 'parity', 'address_confirmed_undeliverable',
    Business_Individual, 'ALL', 'ALL', 'ALL', creation_cohort,
    COUNT(*),
    SUM(COUNT(*)) OVER (PARTITION BY Business_Individual, creation_cohort)
FROM active_linked
WHERE phys_undeliverable_ind = 'Y'
   OR mail_undeliverable_ind = 'Y'
GROUP BY Business_Individual, creation_cohort

ORDER BY metric_name, contact_type, creation_cohort;
