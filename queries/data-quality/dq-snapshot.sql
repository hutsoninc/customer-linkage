-- DQ Snapshot: Combined Data Quality Metrics
-- queries/data-quality/dq-snapshot.sql
-- Output schema: snapshot_date, metric_category, metric_name, contact_type,
--                sales_decile, staleness_bucket, branch, creation_cohort, numerator, denominator
-- Scope: all active non-employee contacts (Sections 1,3,4,5); subsets for 2 and 6.

WITH

/* ═══════════════════════════════════════════════════════
   TIER 1 — Revenue / Dimension Foundation
   ═══════════════════════════════════════════════════════ */

date_range AS (
    SELECT CAST(EOMONTH(DATEADD(MONTH, -1, GETDATE())) AS date) AS EndDate
),
dr AS (
    SELECT
        EndDate,
        CAST(DATEADD(MONTH, -59, DATEFROMPARTS(YEAR(EndDate), MONTH(EndDate), 1)) AS date) AS StartDate
    FROM date_range
),
account_revenue AS (
    SELECT AccountNumber, SUM(CompleteGoods + Parts + Service + Rental) AS TotalRevenue
    FROM (
        SELECT
            am.Customer_No AS AccountNumber,
            CAST(
                SUM(ISNULL(vhs.SALES_VALUE, 0))
                + ISNULL((
                    SELECT SUM(ISNULL(vsa.Sale_Value, 0))
                    FROM [Bronze_Production_Lakehouse].[Equip].[VhStockAccess] vsa
                    WHERE vhs.NO = vsa.Stock_No
                  ), 0)
            AS DECIMAL(12,2)) AS CompleteGoods,
            CAST(0 AS DECIMAL(12,2)) AS Parts,
            CAST(0 AS DECIMAL(12,2)) AS Service,
            CAST(0 AS DECIMAL(12,2)) AS Rental
        FROM [Bronze_Production_Lakehouse].[Equip].[ArMaster_Customer] am
            INNER JOIN [Bronze_Production_Lakehouse].[Equip].[VhStock] vhs
                ON vhs.Owner = am.contact_code
        WHERE vhs.SALESDATE BETWEEN (SELECT StartDate FROM dr) AND (SELECT EndDate FROM dr)
        GROUP BY vhs.NO, am.Customer_No

        UNION ALL

        SELECT am.Customer_No,
            CAST(0 AS DECIMAL(12,2)),
            CAST(SUM(ISNULL(i.parts_sale_val, 0)) AS DECIMAL(12,2)),
            CAST(0 AS DECIMAL(12,2)),
            CAST(0 AS DECIMAL(12,2))
        FROM [Bronze_Production_Lakehouse].[Equip].[ArMaster_Customer] am
            INNER JOIN [Bronze_Production_Lakehouse].[Equip].[Invoice] i
                ON i.bill_to_acc = am.Customer_No
               AND i.invo_type IN ('C', 'I')
               AND i.module_type = 'I'
        WHERE i.invo_datetime BETWEEN (SELECT StartDate FROM dr) AND (SELECT EndDate FROM dr)
        GROUP BY am.Customer_No

        UNION ALL

        SELECT am.Customer_No,
            CAST(0 AS DECIMAL(12,2)),
            CAST(0 AS DECIMAL(12,2)),
            CAST(SUM(
                ISNULL(i.parts_sale_val,  0) + ISNULL(i.labour_sale_val, 0)
                + ISNULL(i.sublet_sal_val, 0) + ISNULL(i.other_sale_val,  0)
            ) AS DECIMAL(12,2)),
            CAST(0 AS DECIMAL(12,2))
        FROM [Bronze_Production_Lakehouse].[Equip].[ArMaster_Customer] am
            INNER JOIN [Bronze_Production_Lakehouse].[Equip].[Invoice] i
                ON i.bill_to_acc = am.Customer_No
               AND i.invo_type IN ('C', 'I')
               AND i.module_type = 'W'
        WHERE i.invo_datetime BETWEEN (SELECT StartDate FROM dr) AND (SELECT EndDate FROM dr)
        GROUP BY am.Customer_No

        UNION ALL

        SELECT am.Customer_No,
            CAST(0 AS DECIMAL(12,2)),
            CAST(0 AS DECIMAL(12,2)),
            CAST(0 AS DECIMAL(12,2)),
            CAST(SUM(ISNULL(rh.Value, 0)) AS DECIMAL(12,2))
        FROM [Bronze_Production_Lakehouse].[Equip].[ArMaster_Customer] am
            INNER JOIN [Bronze_Production_Lakehouse].[Equip].[Invoice] i
                ON i.bill_to_acc = am.Customer_No
               AND i.invo_type IN ('C', 'I')
            LEFT OUTER JOIN [Bronze_Production_Lakehouse].[Equip].[Rental_History] rh
                ON i.document_no = rh.Invoice_No
        WHERE i.invo_datetime BETWEEN (SELECT StartDate FROM dr) AND (SELECT EndDate FROM dr)
        GROUP BY am.Customer_No
    ) sq
    GROUP BY AccountNumber
),
revenue_ranked AS (
    SELECT AccountNumber, NTILE(10) OVER (ORDER BY TotalRevenue DESC) AS RawDecile
    FROM account_revenue
    WHERE TotalRevenue > 0
),
last_tx AS (
    SELECT acc_no, MAX(tx_date) AS last_tx_date
    FROM (
        SELECT am.Customer_No AS acc_no, CAST(vhs.SALESDATE AS date) AS tx_date
        FROM [Bronze_Production_Lakehouse].[Equip].[ArMaster_Customer] am
            INNER JOIN [Bronze_Production_Lakehouse].[Equip].[VhStock] vhs
                ON vhs.Owner = am.contact_code
        WHERE vhs.SALESDATE IS NOT NULL

        UNION ALL

        SELECT am.Customer_No, CAST(i.invo_datetime AS date)
        FROM [Bronze_Production_Lakehouse].[Equip].[ArMaster_Customer] am
            INNER JOIN [Bronze_Production_Lakehouse].[Equip].[Invoice] i
                ON i.bill_to_acc = am.Customer_No
               AND i.invo_type IN ('C', 'I') AND i.module_type = 'I'
        WHERE i.invo_datetime IS NOT NULL

        UNION ALL

        SELECT am.Customer_No, CAST(i.invo_datetime AS date)
        FROM [Bronze_Production_Lakehouse].[Equip].[ArMaster_Customer] am
            INNER JOIN [Bronze_Production_Lakehouse].[Equip].[Invoice] i
                ON i.bill_to_acc = am.Customer_No
               AND i.invo_type IN ('C', 'I') AND i.module_type = 'W'
        WHERE i.invo_datetime IS NOT NULL

        UNION ALL

        SELECT am.Customer_No, CAST(i.invo_datetime AS date)
        FROM [Bronze_Production_Lakehouse].[Equip].[ArMaster_Customer] am
            INNER JOIN [Bronze_Production_Lakehouse].[Equip].[Invoice] i
                ON i.bill_to_acc = am.Customer_No
               AND i.invo_type IN ('C', 'I')
            INNER JOIN [Bronze_Production_Lakehouse].[Equip].[Rental_History] rh
                ON i.document_no = rh.Invoice_No
        WHERE i.invo_datetime IS NOT NULL
    ) tx
    GROUP BY acc_no
),

/* ═══════════════════════════════════════════════════════
   TIER 2 — Master Contact Base
   ═══════════════════════════════════════════════════════ */

active_contacts AS (
    SELECT
        c.contact_code,
        c.Business_Individual,
        c.Ckc_Id,
        c.Creation_Date,
        NULLIF(LTRIM(RTRIM(c.[name])),          '') AS first_name,
        NULLIF(LTRIM(RTRIM(c.surname)),         '') AS last_name,
        NULLIF(LTRIM(RTRIM(c.company_name)),    '') AS company_name,
        NULLIF(LTRIM(RTRIM(c.email_address)),   '') AS email,
        NULLIF(LTRIM(RTRIM(c.BusinessPhone)),   '') AS biz_phone,
        NULLIF(LTRIM(RTRIM(c.PrivatePhone)),    '') AS priv_phone,
        NULLIF(LTRIM(RTRIM(c.MobilePhone)),     '') AS mob_phone,
        NULLIF(LTRIM(RTRIM(c.street)),          '') AS street,
        NULLIF(LTRIM(RTRIM(c.city)),            '') AS city,
        NULLIF(LTRIM(RTRIM(c.state)),           '') AS state,
        NULLIF(LTRIM(RTRIM(c.pcode)),           '') AS pcode,
        NULLIF(LTRIM(RTRIM(c.country)),         '') AS country,  -- no US default; applied only where needed
        NULLIF(LTRIM(RTRIM(c.title)),           '') AS title,
        NULLIF(LTRIM(RTRIM(c.Generation)),      '') AS generation,
        NULLIF(LTRIM(RTRIM(c.Suffix)),          '') AS suffix,
        am.Customer_No                               AS acc_no,
        NULLIF(LTRIM(RTRIM(am.TERRITORY)),      '') AS branch
    FROM [Bronze_Production_Lakehouse].[Equip].[contact] c
        LEFT JOIN [Bronze_Production_Lakehouse].[Equip].[WKMECHFL] wk
            ON wk.[Code] = c.contact_code
        LEFT JOIN [Bronze_Production_Lakehouse].[Equip].[VhSalman] vs
            ON vs.[CODE] = c.contact_code
        LEFT JOIN [Bronze_Production_Lakehouse].[Equip].[ArMaster_Customer] am
            ON am.contact_code = c.contact_code
    WHERE ISNULL(c.Inactive_Indicator, 'A') <> 'I'
      AND wk.[Code] IS NULL
      AND vs.[CODE] IS NULL
),
contact_enriched AS (
    SELECT
        ac.*,
        CASE
            WHEN ac.acc_no IS NULL                                             THEN 'No Account'
            WHEN lt.last_tx_date IS NULL                                       THEN 'Never Transacted'
            WHEN lt.last_tx_date >= DATEADD(YEAR, -1, CAST(GETDATE() AS date)) THEN '0-1yr'
            WHEN lt.last_tx_date >= DATEADD(YEAR, -2, CAST(GETDATE() AS date)) THEN '1-2yr'
            WHEN lt.last_tx_date >= DATEADD(YEAR, -3, CAST(GETDATE() AS date)) THEN '2-3yr'
            WHEN lt.last_tx_date >= DATEADD(YEAR, -4, CAST(GETDATE() AS date)) THEN '3-4yr'
            WHEN lt.last_tx_date >= DATEADD(YEAR, -5, CAST(GETDATE() AS date)) THEN '4-5yr'
            ELSE                                                                    '5+yr'
        END AS staleness_bucket,
        CASE
            WHEN ac.acc_no IS NULL        THEN 'Unranked'
            WHEN rr.AccountNumber IS NULL THEN 'Unranked'
            ELSE 'D' + CAST(rr.RawDecile AS VARCHAR(2))
        END AS sales_decile,
        CASE
            WHEN ac.Creation_Date IS NULL              THEN 'Unknown'
            WHEN YEAR(ac.Creation_Date) < 2016         THEN 'Pre-2015'
            WHEN YEAR(ac.Creation_Date) <= 2020        THEN '2016-2020'
            WHEN YEAR(ac.Creation_Date) <= 2025        THEN '2021-2025'
            ELSE                                            '2026+'
        END AS creation_cohort
    FROM active_contacts ac
        LEFT JOIN last_tx lt        ON lt.acc_no        = ac.acc_no
        LEFT JOIN revenue_ranked rr ON rr.AccountNumber = ac.acc_no
),

/* ═══════════════════════════════════════════════════════
   TIER 3 — Population Subsets
   ═══════════════════════════════════════════════════════ */

contact_linkage AS (
    SELECT
        ce.contact_code,
        ce.Business_Individual,
        ce.Ckc_Id,
        ce.sales_decile,
        ce.staleness_bucket,
        ce.branch,
        ce.creation_cohort,
        xr.entity_id,
        xr.contact_id,
        CASE WHEN xr.cross_ref_number IS NOT NULL THEN 1 ELSE 0 END AS is_linked
    FROM contact_enriched ce
        LEFT JOIN [Bronze_Production_Lakehouse].[DDP].[customer_cross_ref] xr
            ON UPPER(xr.cross_ref_number) = UPPER(ce.contact_code)
           AND xr.entity_id <> 999999998
           AND xr.cross_ref_description = 'HUTSON INC Dealer XREF'
),
unlinked_enriched AS (
    SELECT ce.*
    FROM contact_enriched ce
    WHERE NOT EXISTS (
        SELECT 1
        FROM [Bronze_Production_Lakehouse].[DDP].[customer_cross_ref] xr
        WHERE UPPER(xr.cross_ref_number) = UPPER(ce.contact_code)
          AND xr.entity_id <> 999999998
          AND xr.cross_ref_description = 'HUTSON INC Dealer XREF'
    )
),
active_linked AS (
    SELECT
        ce.contact_code,
        ce.Business_Individual,
        ce.sales_decile,
        ce.staleness_bucket,
        ce.branch,
        ce.creation_cohort,
        ce.company_name,
        ce.first_name,
        ce.last_name,
        ce.email,
        ce.biz_phone,
        ce.priv_phone,
        ce.mob_phone,
        ce.street,
        ce.city,
        ce.state,
        ce.pcode,
        ce.country,
        NULLIF(LTRIM(RTRIM(cp.nm1_txt)),             '') AS reg_company_name,
        NULLIF(LTRIM(RTRIM(cp.first_nm)),            '') AS reg_first_name,
        NULLIF(LTRIM(RTRIM(cp.last_nm)),             '') AS reg_last_name,
        NULLIF(LTRIM(RTRIM(cp.email_addr_txt)),      '') AS reg_email,
        NULLIF(LTRIM(RTRIM(cp.work_area_cd)),        '') AS reg_biz_area,
        NULLIF(LTRIM(RTRIM(cp.work_phone_num)),      '') AS reg_biz_num,
        NULLIF(LTRIM(RTRIM(cp.home_area_cd)),        '') AS reg_priv_area,
        NULLIF(LTRIM(RTRIM(cp.home_phone_num)),      '') AS reg_priv_num,
        NULLIF(LTRIM(RTRIM(cp.mobile_area_cd)),      '') AS reg_mob_area,
        NULLIF(LTRIM(RTRIM(cp.mobile_phone_num)),    '') AS reg_mob_num,
        NULLIF(LTRIM(RTRIM(cp.phys_street1_txt)),    '') AS reg_street,
        NULLIF(LTRIM(RTRIM(cp.phys_city)),           '') AS reg_city,
        NULLIF(LTRIM(RTRIM(cp.phys_state_prov_cd)), '') AS reg_state,
        NULLIF(LTRIM(RTRIM(cp.phys_postal_cd)),      '') AS reg_pcode,
        NULLIF(LTRIM(RTRIM(cp.phys_iso2_cntry_cd)), '') AS reg_country,
        cp.phys_postal_certified,
        cp.phys_undeliverable_ind,
        cp.mail_undeliverable_ind,
        cp.out_of_busn_ind,
        cp.descd_ind
    FROM contact_enriched ce
        INNER JOIN [Bronze_Production_Lakehouse].[DDP].[customer_cross_ref] xr
            ON UPPER(xr.cross_ref_number) = UPPER(ce.contact_code)
           AND xr.entity_id <> 999999998
           AND xr.cross_ref_description = 'HUTSON INC Dealer XREF'
        INNER JOIN [Bronze_Production_Lakehouse].[DDP].[customer_profile] cp
            ON cp.entity_id  = xr.entity_id
           AND cp.contact_id = xr.contact_id
),
inactive_linked AS (
    -- Linked inactive contacts — for equip_inactive_reason_mismatch only.
    -- Validate Inactive_Reason column name against Equip.contact schema before running.
    SELECT
        c.contact_code,
        c.Business_Individual,
        NULLIF(LTRIM(RTRIM(c.Inactive_Reason)), '') AS inactive_reason,
        cp.out_of_busn_ind,
        cp.descd_ind,
        CASE
            WHEN c.Creation_Date IS NULL              THEN 'Unknown'
            WHEN YEAR(c.Creation_Date) < 2016         THEN 'Pre-2015'
            WHEN YEAR(c.Creation_Date) <= 2020        THEN '2016-2020'
            WHEN YEAR(c.Creation_Date) <= 2025        THEN '2021-2025'
            ELSE                                           '2026+'
        END AS creation_cohort,
        NULLIF(LTRIM(RTRIM(am.TERRITORY)), '') AS branch,
        'Inactive'                             AS sales_decile,
        'Inactive'                             AS staleness_bucket
    FROM [Bronze_Production_Lakehouse].[Equip].[contact] c
        LEFT JOIN [Bronze_Production_Lakehouse].[Equip].[WKMECHFL] wk
            ON wk.[Code] = c.contact_code
        LEFT JOIN [Bronze_Production_Lakehouse].[Equip].[VhSalman] vs
            ON vs.[CODE] = c.contact_code
        LEFT JOIN [Bronze_Production_Lakehouse].[Equip].[ArMaster_Customer] am
            ON am.contact_code = c.contact_code
        INNER JOIN [Bronze_Production_Lakehouse].[DDP].[customer_cross_ref] xr
            ON UPPER(xr.cross_ref_number) = UPPER(c.contact_code)
           AND xr.entity_id <> 999999998
           AND xr.cross_ref_description = 'HUTSON INC Dealer XREF'
        INNER JOIN [Bronze_Production_Lakehouse].[DDP].[customer_profile] cp
            ON cp.entity_id  = xr.entity_id
           AND cp.contact_id = xr.contact_id
    WHERE c.Inactive_Indicator = 'I'
      AND wk.[Code] IS NULL
      AND vs.[CODE] IS NULL
),
field_parity AS (
    SELECT 'company_name' AS field_name, Business_Individual AS contact_type,
           sales_decile, staleness_bucket, branch, creation_cohort,
           CASE
               WHEN company_name IS NULL     AND reg_company_name IS NULL     THEN 'both_null'
               WHEN company_name IS NOT NULL AND reg_company_name IS NULL     THEN 'equip_only'
               WHEN company_name IS NULL     AND reg_company_name IS NOT NULL THEN 'registry_only'
               WHEN UPPER(company_name) = UPPER(reg_company_name)             THEN 'match'
               ELSE 'mismatch'
           END AS parity_result
    FROM active_linked WHERE Business_Individual = 'B'

    UNION ALL

    SELECT 'first_name', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE
               WHEN first_name IS NULL     AND reg_first_name IS NULL     THEN 'both_null'
               WHEN first_name IS NOT NULL AND reg_first_name IS NULL     THEN 'equip_only'
               WHEN first_name IS NULL     AND reg_first_name IS NOT NULL THEN 'registry_only'
               WHEN UPPER(first_name) = UPPER(reg_first_name)             THEN 'match'
               ELSE 'mismatch'
           END
    FROM active_linked WHERE Business_Individual IN ('I', 'C')

    UNION ALL

    SELECT 'last_name', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE
               WHEN last_name IS NULL     AND reg_last_name IS NULL     THEN 'both_null'
               WHEN last_name IS NOT NULL AND reg_last_name IS NULL     THEN 'equip_only'
               WHEN last_name IS NULL     AND reg_last_name IS NOT NULL THEN 'registry_only'
               WHEN UPPER(last_name) = UPPER(reg_last_name)             THEN 'match'
               ELSE 'mismatch'
           END
    FROM active_linked WHERE Business_Individual IN ('I', 'C')

    UNION ALL

    SELECT 'email', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE
               WHEN email IS NULL     AND reg_email IS NULL     THEN 'both_null'
               WHEN email IS NOT NULL AND reg_email IS NULL     THEN 'equip_only'
               WHEN email IS NULL     AND reg_email IS NOT NULL THEN 'registry_only'
               WHEN LOWER(email) = LOWER(reg_email)             THEN 'match'
               ELSE 'mismatch'
           END
    FROM active_linked

    UNION ALL

    SELECT 'business_phone', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE
               WHEN biz_phone IS NULL AND reg_biz_area IS NULL AND reg_biz_num IS NULL THEN 'both_null'
               WHEN biz_phone IS NOT NULL AND reg_biz_area IS NULL AND reg_biz_num IS NULL THEN 'equip_only'
               WHEN biz_phone IS NULL AND (reg_biz_area IS NOT NULL OR reg_biz_num IS NOT NULL) THEN 'registry_only'
               WHEN biz_phone = ISNULL(reg_biz_area, '') + ISNULL(reg_biz_num, '') THEN 'match'
               ELSE 'mismatch'
           END
    FROM active_linked

    UNION ALL

    SELECT 'private_phone', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE
               WHEN priv_phone IS NULL AND reg_priv_area IS NULL AND reg_priv_num IS NULL THEN 'both_null'
               WHEN priv_phone IS NOT NULL AND reg_priv_area IS NULL AND reg_priv_num IS NULL THEN 'equip_only'
               WHEN priv_phone IS NULL AND (reg_priv_area IS NOT NULL OR reg_priv_num IS NOT NULL) THEN 'registry_only'
               WHEN priv_phone = ISNULL(reg_priv_area, '') + ISNULL(reg_priv_num, '') THEN 'match'
               ELSE 'mismatch'
           END
    FROM active_linked

    UNION ALL

    SELECT 'mobile_phone', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE
               WHEN mob_phone IS NULL AND reg_mob_area IS NULL AND reg_mob_num IS NULL THEN 'both_null'
               WHEN mob_phone IS NOT NULL AND reg_mob_area IS NULL AND reg_mob_num IS NULL THEN 'equip_only'
               WHEN mob_phone IS NULL AND (reg_mob_area IS NOT NULL OR reg_mob_num IS NOT NULL) THEN 'registry_only'
               WHEN mob_phone = ISNULL(reg_mob_area, '') + ISNULL(reg_mob_num, '') THEN 'match'
               ELSE 'mismatch'
           END
    FROM active_linked

    UNION ALL

    SELECT 'street', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE
               WHEN street IS NULL     AND reg_street IS NULL     THEN 'both_null'
               WHEN street IS NOT NULL AND reg_street IS NULL     THEN 'equip_only'
               WHEN street IS NULL     AND reg_street IS NOT NULL THEN 'registry_only'
               WHEN UPPER(street) = UPPER(reg_street)             THEN 'match'
               ELSE 'mismatch'
           END
    FROM active_linked

    UNION ALL

    SELECT 'city', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE
               WHEN city IS NULL     AND reg_city IS NULL     THEN 'both_null'
               WHEN city IS NOT NULL AND reg_city IS NULL     THEN 'equip_only'
               WHEN city IS NULL     AND reg_city IS NOT NULL THEN 'registry_only'
               WHEN UPPER(city) = UPPER(reg_city)             THEN 'match'
               ELSE 'mismatch'
           END
    FROM active_linked

    UNION ALL

    SELECT 'state', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE
               WHEN state IS NULL     AND reg_state IS NULL     THEN 'both_null'
               WHEN state IS NOT NULL AND reg_state IS NULL     THEN 'equip_only'
               WHEN state IS NULL     AND reg_state IS NOT NULL THEN 'registry_only'
               WHEN UPPER(state) = UPPER(reg_state)             THEN 'match'
               ELSE 'mismatch'
           END
    FROM active_linked

    UNION ALL

    SELECT 'zip', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE
               WHEN pcode IS NULL     AND reg_pcode IS NULL     THEN 'both_null'
               WHEN pcode IS NOT NULL AND reg_pcode IS NULL     THEN 'equip_only'
               WHEN pcode IS NULL     AND reg_pcode IS NOT NULL THEN 'registry_only'
               WHEN UPPER(pcode) = UPPER(reg_pcode)             THEN 'match'
               ELSE 'mismatch'
           END
    FROM active_linked

    UNION ALL

    SELECT 'country', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE
               WHEN country IS NULL     AND reg_country IS NULL     THEN 'both_null'
               WHEN country IS NOT NULL AND reg_country IS NULL     THEN 'equip_only'
               WHEN country IS NULL     AND reg_country IS NOT NULL THEN 'registry_only'
               WHEN UPPER(country) = UPPER(reg_country)             THEN 'match'
               ELSE 'mismatch'
           END
    FROM active_linked
),
linked_counts AS (
    SELECT
        Business_Individual,
        sales_decile,
        staleness_bucket,
        branch,
        creation_cohort,
        COUNT(*)                                                       AS total_linked,
        SUM(CASE WHEN phys_postal_certified = 'CERTIFIED' THEN 1 ELSE 0 END) AS certified_linked
    FROM active_linked
    GROUP BY Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort
),
dup_codes AS (
    SELECT UPPER(LTRIM(RTRIM(contact_code))) AS norm_code
    FROM contact_enriched
    GROUP BY UPPER(LTRIM(RTRIM(contact_code)))
    HAVING COUNT(*) > 1
),
fp_denominator AS (
    SELECT field_name, contact_type, sales_decile, staleness_bucket, branch, creation_cohort,
           COUNT(*) AS denominator
    FROM field_parity
    GROUP BY field_name, contact_type, sales_decile, staleness_bucket, branch, creation_cohort
),
fp_numerator AS (
    SELECT field_name, parity_result, contact_type, sales_decile, staleness_bucket, branch, creation_cohort,
           COUNT(*) AS numerator
    FROM field_parity
    GROUP BY field_name, parity_result, contact_type, sales_decile, staleness_bucket, branch, creation_cohort
),
parity_outcomes AS (
    SELECT 'match'         AS parity_result UNION ALL
    SELECT 'mismatch'                       UNION ALL
    SELECT 'equip_only'                     UNION ALL
    SELECT 'registry_only'                  UNION ALL
    SELECT 'both_null'
),
fp_spine AS (
    SELECT d.field_name, po.parity_result, d.contact_type,
           d.sales_decile, d.staleness_bucket, d.branch, d.creation_cohort,
           d.denominator
    FROM fp_denominator d
    CROSS JOIN parity_outcomes po
),
staleness_buckets AS (
    SELECT 'No Account'       AS staleness_bucket UNION ALL
    SELECT 'Never Transacted'                     UNION ALL
    SELECT '0-1yr'                                UNION ALL
    SELECT '1-2yr'                                UNION ALL
    SELECT '2-3yr'                                UNION ALL
    SELECT '3-4yr'                                UNION ALL
    SELECT '4-5yr'                                UNION ALL
    SELECT '5+yr'
),
s5_denominator AS (
    SELECT Business_Individual, sales_decile, branch, creation_cohort,
           COUNT(*) AS denominator
    FROM contact_enriched
    GROUP BY Business_Individual, sales_decile, branch, creation_cohort
),
s5_numerator AS (
    SELECT staleness_bucket, Business_Individual, sales_decile, branch, creation_cohort,
           COUNT(*) AS numerator
    FROM contact_enriched
    GROUP BY staleness_bucket, Business_Individual, sales_decile, branch, creation_cohort
),
s5_spine AS (
    SELECT d.Business_Individual, d.sales_decile, d.branch, d.creation_cohort,
           sb.staleness_bucket, d.denominator
    FROM s5_denominator d
    CROSS JOIN staleness_buckets sb
),
match_readiness_tiers AS (
    SELECT 1 AS tier, 'tier_1_strong'    AS metric_name UNION ALL
    SELECT 2,         'tier_2_partial'                  UNION ALL
    SELECT 3,         'tier_3_name_only'                UNION ALL
    SELECT 4,         'tier_4_no_name'
),
s6_tiered AS (
    SELECT
        Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
        CASE
            WHEN (Business_Individual IN ('I','C') AND (first_name IS NULL OR last_name IS NULL))
              OR (Business_Individual = 'B'        AND company_name IS NULL)
                THEN 4
            WHEN (street IS NOT NULL AND city IS NOT NULL AND state IS NOT NULL)
              OR (street IS NOT NULL AND pcode IS NOT NULL)
                THEN 1
            WHEN (street IS NOT NULL OR city IS NOT NULL OR state IS NOT NULL OR pcode IS NOT NULL)
              OR (biz_phone IS NOT NULL OR priv_phone IS NOT NULL OR mob_phone IS NOT NULL OR email IS NOT NULL)
                THEN 2
            ELSE 3
        END AS tier
    FROM unlinked_enriched
),
s6_denominator AS (
    SELECT Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           COUNT(*) AS denominator
    FROM unlinked_enriched
    GROUP BY Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort
),
s6_numerator AS (
    SELECT tier, Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           COUNT(*) AS numerator
    FROM s6_tiered
    GROUP BY tier, Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort
),
s6_spine AS (
    SELECT d.Business_Individual, d.sales_decile, d.staleness_bucket, d.branch, d.creation_cohort,
           t.tier, t.metric_name, d.denominator
    FROM s6_denominator d
    CROSS JOIN match_readiness_tiers t
)

/* ═══════════════════════════════════════════════════════
   SECTION 1 — Linkage Quality
   ═══════════════════════════════════════════════════════ */

SELECT
    CAST(GETDATE() AS date) AS snapshot_date,
    'linkage'               AS metric_category,
    'linked_count'          AS metric_name,
    Business_Individual     AS contact_type,
    sales_decile,
    staleness_bucket,
    branch,
    creation_cohort,
    SUM(is_linked)          AS numerator,
    COUNT(*)                AS denominator
FROM contact_linkage
GROUP BY Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort

UNION ALL

SELECT
    CAST(GETDATE() AS date), 'linkage', 'unlinked_count',
    Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
    SUM(1 - is_linked), COUNT(*)
FROM contact_linkage
GROUP BY Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort

UNION ALL

SELECT
    CAST(GETDATE() AS date), 'linkage', 'ckc_id_no_cross_ref',
    Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
    SUM(CASE WHEN Ckc_Id IS NOT NULL AND is_linked = 0 THEN 1 ELSE 0 END),
    SUM(CASE WHEN Ckc_Id IS NOT NULL THEN 1 ELSE 0 END)
FROM contact_linkage
GROUP BY Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort

UNION ALL

SELECT
    CAST(GETDATE() AS date), 'linkage', 'type_mismatch_linkage',
    Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
    SUM(CASE
        WHEN Business_Individual = 'C'         AND contact_id <> 0 THEN 1
        WHEN Business_Individual IN ('B', 'I') AND contact_id  = 0 THEN 1
        ELSE 0
    END),
    SUM(is_linked)
FROM contact_linkage
WHERE is_linked = 1
GROUP BY Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort

UNION ALL

SELECT
    CAST(GETDATE() AS date), 'linkage', 'duplicate_entity_id',
    'ALL', 'ALL', 'ALL', NULL, 'ALL',
    COUNT(*),
    (SELECT COUNT(DISTINCT entity_id) FROM contact_linkage WHERE is_linked = 1)
FROM (
    SELECT entity_id
    FROM contact_linkage
    WHERE is_linked = 1
    GROUP BY entity_id
    HAVING COUNT(*) > 1
) dups

UNION ALL

SELECT
    CAST(GETDATE() AS date), 'linkage', 'orphan_cross_ref',
    'ALL', 'ALL', 'ALL', NULL, 'ALL',
    COUNT(*),
    (SELECT COUNT(*) FROM [Bronze_Production_Lakehouse].[DDP].[customer_cross_ref]
     WHERE entity_id <> 999999998
       AND cross_ref_description = 'HUTSON INC Dealer XREF')
FROM [Bronze_Production_Lakehouse].[DDP].[customer_cross_ref] xr_all
WHERE xr_all.entity_id <> 999999998
  AND xr_all.cross_ref_description = 'HUTSON INC Dealer XREF'
  AND NOT EXISTS (
      SELECT 1 FROM contact_enriched ce
      WHERE UPPER(ce.contact_code) = UPPER(xr_all.cross_ref_number)
  )

/* ═══════════════════════════════════════════════════════
   SECTION 2 — Registry Parity
   ═══════════════════════════════════════════════════════ */

UNION ALL

SELECT
    CAST(GETDATE() AS date),
    'parity',
    fs.field_name + '_' + fs.parity_result,
    fs.contact_type,
    fs.sales_decile,
    fs.staleness_bucket,
    fs.branch,
    fs.creation_cohort,
    ISNULL(fn.numerator, 0),
    fs.denominator
FROM fp_spine fs
    LEFT JOIN fp_numerator fn
        ON  fn.field_name       = fs.field_name
        AND fn.parity_result    = fs.parity_result
        AND fn.contact_type     = fs.contact_type
        AND fn.sales_decile     = fs.sales_decile
        AND fn.staleness_bucket = fs.staleness_bucket
        AND ISNULL(fn.branch, '') = ISNULL(fs.branch, '')
        AND fn.creation_cohort  = fs.creation_cohort

UNION ALL

SELECT
    CAST(GETDATE() AS date), 'parity', 'phys_addr_certified_mismatch',
    al.Business_Individual, al.sales_decile, al.staleness_bucket, al.branch, al.creation_cohort,
    COUNT(*),
    MAX(lc.certified_linked)
FROM active_linked al
    INNER JOIN linked_counts lc
        ON  lc.Business_Individual = al.Business_Individual
        AND lc.sales_decile        = al.sales_decile
        AND lc.staleness_bucket    = al.staleness_bucket
        AND ISNULL(lc.branch, '') = ISNULL(al.branch, '')
        AND lc.creation_cohort     = al.creation_cohort
WHERE al.phys_postal_certified = 'CERTIFIED'
  AND (
       UPPER(ISNULL(al.street, '')) <> UPPER(ISNULL(al.reg_street, ''))
    OR UPPER(ISNULL(al.city,   '')) <> UPPER(ISNULL(al.reg_city,   ''))
    OR UPPER(ISNULL(al.state,  '')) <> UPPER(ISNULL(al.reg_state,  ''))
    OR UPPER(ISNULL(al.pcode,  '')) <> UPPER(ISNULL(al.reg_pcode,  ''))
  )
GROUP BY al.Business_Individual, al.sales_decile, al.staleness_bucket, al.branch, al.creation_cohort

UNION ALL

SELECT
    CAST(GETDATE() AS date), 'parity', 'address_confirmed_undeliverable',
    al.Business_Individual, al.sales_decile, al.staleness_bucket, al.branch, al.creation_cohort,
    COUNT(*),
    MAX(lc.total_linked)
FROM active_linked al
    INNER JOIN linked_counts lc
        ON  lc.Business_Individual = al.Business_Individual
        AND lc.sales_decile        = al.sales_decile
        AND lc.staleness_bucket    = al.staleness_bucket
        AND ISNULL(lc.branch, '') = ISNULL(al.branch, '')
        AND lc.creation_cohort     = al.creation_cohort
WHERE al.phys_undeliverable_ind = 'Y'
   OR al.mail_undeliverable_ind = 'Y'
GROUP BY al.Business_Individual, al.sales_decile, al.staleness_bucket, al.branch, al.creation_cohort

UNION ALL

SELECT
    CAST(GETDATE() AS date), 'parity', 'registry_oob_equip_active',
    al.Business_Individual, al.sales_decile, al.staleness_bucket, al.branch, al.creation_cohort,
    COUNT(*),
    MAX(lc.total_linked)
FROM active_linked al
    INNER JOIN linked_counts lc
        ON  lc.Business_Individual = al.Business_Individual
        AND lc.sales_decile        = al.sales_decile
        AND lc.staleness_bucket    = al.staleness_bucket
        AND ISNULL(lc.branch, '') = ISNULL(al.branch, '')
        AND lc.creation_cohort     = al.creation_cohort
WHERE al.Business_Individual = 'B'
  AND al.out_of_busn_ind = 'Y'
GROUP BY al.Business_Individual, al.sales_decile, al.staleness_bucket, al.branch, al.creation_cohort

UNION ALL

SELECT
    CAST(GETDATE() AS date), 'parity', 'registry_deceased_equip_active',
    al.Business_Individual, al.sales_decile, al.staleness_bucket, al.branch, al.creation_cohort,
    COUNT(*),
    MAX(lc.total_linked)
FROM active_linked al
    INNER JOIN linked_counts lc
        ON  lc.Business_Individual = al.Business_Individual
        AND lc.sales_decile        = al.sales_decile
        AND lc.staleness_bucket    = al.staleness_bucket
        AND ISNULL(lc.branch, '') = ISNULL(al.branch, '')
        AND lc.creation_cohort     = al.creation_cohort
WHERE al.Business_Individual IN ('I', 'C')
  AND al.descd_ind = 'Y'
GROUP BY al.Business_Individual, al.sales_decile, al.staleness_bucket, al.branch, al.creation_cohort

UNION ALL

SELECT
    CAST(GETDATE() AS date), 'parity', 'equip_inactive_reason_mismatch',
    Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
    SUM(CASE
        WHEN inactive_reason = 'Out of Business' AND ISNULL(out_of_busn_ind, 'N') <> 'Y' THEN 1
        WHEN inactive_reason = 'Deceased'        AND ISNULL(descd_ind,       'N') <> 'Y' THEN 1
        ELSE 0
    END),
    COUNT(*)
FROM inactive_linked
GROUP BY Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort

/* ═══════════════════════════════════════════════════════
   SECTION 3 — Completeness
   Denominator = all contacts in scope for that metric × dim slice.
   ═══════════════════════════════════════════════════════ */

UNION ALL

SELECT
    CAST(GETDATE() AS date) AS snapshot_date,
    'completeness'          AS metric_category,
    sq.metric_name,
    sq.contact_type,
    sq.sales_decile,
    sq.staleness_bucket,
    sq.branch,
    sq.creation_cohort,
    SUM(sq.is_issue)        AS numerator,
    COUNT(*)                AS denominator
FROM (
    SELECT 'missing_first_name' AS metric_name, Business_Individual AS contact_type,
           sales_decile, staleness_bucket, branch, creation_cohort,
           CASE WHEN first_name IS NULL THEN 1 ELSE 0 END AS is_issue
    FROM contact_enriched WHERE Business_Individual IN ('I', 'C')

    UNION ALL

    SELECT 'missing_last_name', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE WHEN last_name IS NULL THEN 1 ELSE 0 END
    FROM contact_enriched WHERE Business_Individual IN ('I', 'C')

    UNION ALL

    SELECT 'missing_company_name', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE WHEN company_name IS NULL THEN 1 ELSE 0 END
    FROM contact_enriched WHERE Business_Individual = 'B'

    UNION ALL

    SELECT 'missing_street', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE WHEN street IS NULL THEN 1 ELSE 0 END
    FROM contact_enriched

    UNION ALL

    SELECT 'missing_city', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE WHEN city IS NULL THEN 1 ELSE 0 END
    FROM contact_enriched

    UNION ALL

    SELECT 'missing_state', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE WHEN state IS NULL THEN 1 ELSE 0 END
    FROM contact_enriched

    UNION ALL

    SELECT 'missing_zip', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE WHEN pcode IS NULL THEN 1 ELSE 0 END
    FROM contact_enriched

    UNION ALL

    SELECT 'missing_country', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE WHEN country IS NULL THEN 1 ELSE 0 END
    FROM contact_enriched

    UNION ALL

    SELECT 'missing_email', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE WHEN email IS NULL THEN 1 ELSE 0 END
    FROM contact_enriched

    UNION ALL

    SELECT 'missing_all_phones', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE WHEN biz_phone IS NULL AND priv_phone IS NULL AND mob_phone IS NULL THEN 1 ELSE 0 END
    FROM contact_enriched

    UNION ALL

    SELECT 'no_contact_info', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE WHEN biz_phone IS NULL AND priv_phone IS NULL AND mob_phone IS NULL AND email IS NULL THEN 1 ELSE 0 END
    FROM contact_enriched
) sq
GROUP BY sq.metric_name, sq.contact_type, sq.sales_decile, sq.staleness_bucket, sq.branch, sq.creation_cohort

/* ═══════════════════════════════════════════════════════
   SECTION 4 — Field Quality
   Denominator = contacts in scope for that metric × dim slice.
   WHERE clause in each inner entry defines the denominator population.
   ═══════════════════════════════════════════════════════ */

UNION ALL

SELECT
    CAST(GETDATE() AS date) AS snapshot_date,
    'field_quality'         AS metric_category,
    sq.metric_name,
    sq.contact_type,
    sq.sales_decile,
    sq.staleness_bucket,
    sq.branch,
    sq.creation_cohort,
    SUM(sq.is_issue)        AS numerator,
    COUNT(*)                AS denominator
FROM (

    -- ── Name: placeholder values ──────────────────────────────────────────────
    SELECT 'placeholder_name' AS metric_name, Business_Individual AS contact_type,
           sales_decile, staleness_bucket, branch, creation_cohort,
           CASE WHEN UPPER(first_name)  IN ('FIRSTNAME', 'FIRST NAME', 'FIRST', 'FNAME')
                  OR UPPER(last_name)   IN ('LASTNAME',  'LAST NAME',  'LAST',  'LNAME')
                THEN 1 ELSE 0 END AS is_issue
    FROM contact_enriched WHERE Business_Individual IN ('I', 'C')

    UNION ALL

    -- ── Name: all same character (I/C: first or last; B: company) ─────────────
    SELECT 'name_all_same_char', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE
               WHEN Business_Individual IN ('I', 'C') THEN
                   CASE WHEN (first_name   IS NOT NULL AND REPLACE(first_name,   LEFT(first_name,   1), '') = '')
                          OR (last_name    IS NOT NULL AND REPLACE(last_name,    LEFT(last_name,    1), '') = '')
                        THEN 1 ELSE 0 END
               WHEN Business_Individual = 'B' THEN
                   CASE WHEN  company_name IS NOT NULL AND REPLACE(company_name, LEFT(company_name, 1), '') = ''
                        THEN 1 ELSE 0 END
               ELSE 0
           END
    FROM contact_enriched

    UNION ALL

    -- ── Name: numeric only (I/C: first or last; B: company) ──────────────────
    SELECT 'name_numeric_only', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE
               WHEN Business_Individual IN ('I', 'C') THEN
                   CASE WHEN (first_name  IS NOT NULL AND PATINDEX('%[^0-9]%', first_name)  = 0)
                          OR (last_name   IS NOT NULL AND PATINDEX('%[^0-9]%', last_name)   = 0)
                        THEN 1 ELSE 0 END
               WHEN Business_Individual = 'B' THEN
                   CASE WHEN  company_name IS NOT NULL AND PATINDEX('%[^0-9]%', company_name) = 0
                        THEN 1 ELSE 0 END
               ELSE 0
           END
    FROM contact_enriched

    UNION ALL

    -- ── Name: status / alert text in first or last name ──────────────────────
    SELECT 'status_text_in_name', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE WHEN
               first_name LIKE '%DECEASED%'       OR first_name LIKE '%OUT OF BUSINESS%'
            OR first_name LIKE '%DO NOT USE%'     OR first_name LIKE '%DONT USE%'
            OR first_name LIKE '%DON''T USE%'     OR first_name LIKE '% USE %'
            OR first_name LIKE '%INACTIVE%'       OR first_name LIKE '%CLOSED%'
            OR first_name LIKE '%FARM PLAN%'
            OR last_name  LIKE '%DECEASED%'       OR last_name  LIKE '%OUT OF BUSINESS%'
            OR last_name  LIKE '%DO NOT USE%'     OR last_name  LIKE '%DONT USE%'
            OR last_name  LIKE '%DON''T USE%'     OR last_name  LIKE '% USE %'
            OR last_name  LIKE '%INACTIVE%'       OR last_name  LIKE '%CLOSED%'
            OR last_name  LIKE '%FARM PLAN%'
           THEN 1 ELSE 0 END
    FROM contact_enriched WHERE Business_Individual IN ('I', 'C')

    UNION ALL

    -- ── Name: status / alert text in company name ─────────────────────────────
    SELECT 'status_text_in_company', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE WHEN
               company_name LIKE '%DECEASED%'     OR company_name LIKE '%OUT OF BUSINESS%'
            OR company_name LIKE '%DO NOT USE%'   OR company_name LIKE '%DONT USE%'
            OR company_name LIKE '%DON''T USE%'   OR company_name LIKE '% USE %'
            OR company_name LIKE '%INACTIVE%'     OR company_name LIKE '%CLOSED%'
            OR company_name LIKE '%FARM PLAN%'    OR company_name LIKE '% OOB %'
           THEN 1 ELSE 0 END
    FROM contact_enriched WHERE Business_Individual = 'B'

    UNION ALL

    -- ── Name: status / alert text in street ──────────────────────────────────
    SELECT 'status_text_in_street', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE WHEN
               street LIKE '%DECEASED%'       OR street LIKE '%OUT OF BUSINESS%'
            OR street LIKE '%DO NOT USE%'     OR street LIKE '%DONT USE%'
            OR street LIKE '%DON''T USE%'     OR street LIKE '%INACTIVE%'
            OR street LIKE '%CLOSED%'
           THEN 1 ELSE 0 END
    FROM contact_enriched

    UNION ALL

    -- ── Address: placeholder street ───────────────────────────────────────────
    SELECT 'placeholder_street', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE WHEN UPPER(LTRIM(RTRIM(street))) IN ('N/A','NA','NONE','UNKNOWN','UNK','TBD','NO ADDRESS','ADDRESS','NO STREET','-')
                THEN 1 ELSE 0 END
    FROM contact_enriched WHERE street IS NOT NULL

    UNION ALL

    -- ── Address: placeholder city ─────────────────────────────────────────────
    SELECT 'placeholder_city', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE WHEN UPPER(LTRIM(RTRIM(city))) IN ('N/A','NA','NONE','UNKNOWN','UNK','TBD','NO CITY','CITY','-')
                THEN 1 ELSE 0 END
    FROM contact_enriched WHERE city IS NOT NULL

    UNION ALL

    -- ── Address: placeholder state ────────────────────────────────────────────
    SELECT 'placeholder_state', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE WHEN UPPER(LTRIM(RTRIM(state))) IN ('N/A','NA','NONE','UNKNOWN','UNK','XX','ZZ')
                THEN 1 ELSE 0 END
    FROM contact_enriched WHERE state IS NOT NULL

    UNION ALL

    -- ── Company: DBA pattern ──────────────────────────────────────────────────
    SELECT 'dba_in_company_name', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE WHEN company_name LIKE '%DBA %' OR company_name LIKE '%D/B/A%' OR company_name LIKE '%DOING BUSINESS AS%'
                THEN 1 ELSE 0 END
    FROM contact_enriched WHERE Business_Individual = 'B'

    UNION ALL

    -- ── Test / dummy records ──────────────────────────────────────────────────
    SELECT 'test_record', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE WHEN
               (first_name    IS NOT NULL AND UPPER(first_name)    IN ('TEST','TESTING','TEMP','DUMMY','SAMPLE'))
            OR (last_name     IS NOT NULL AND UPPER(last_name)     IN ('TEST','TESTING','TEMP','DUMMY','SAMPLE'))
            OR (company_name  IS NOT NULL AND UPPER(company_name)  IN ('TEST','TESTING','DUMMY','SAMPLE','TEMP'))
           THEN 1 ELSE 0 END
    FROM contact_enriched

    UNION ALL

    -- ── Contact type / field mismatch ─────────────────────────────────────────
    SELECT 'contact_type_field_mismatch', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE WHEN
               (Business_Individual = 'B'          AND (first_name IS NOT NULL OR last_name IS NOT NULL) AND company_name IS NULL)
            OR (Business_Individual IN ('I', 'C')  AND company_name IS NOT NULL AND first_name IS NULL AND last_name IS NULL)
           THEN 1 ELSE 0 END
    FROM contact_enriched

    UNION ALL

    -- ── Name: prefix in first_name ────────────────────────────────────────────
    SELECT 'prefix_in_name', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE WHEN
               first_name LIKE 'MR.%'   OR first_name LIKE 'MR %'
            OR first_name LIKE 'MRS.%'  OR first_name LIKE 'MRS %'
            OR first_name LIKE 'MS.%'   OR first_name LIKE 'MS %'
            OR first_name LIKE 'DR.%'   OR first_name LIKE 'DR %'
            OR first_name LIKE 'REV.%'  OR first_name LIKE 'REV %'
            OR first_name LIKE 'PROF.%' OR first_name LIKE 'PROF %'
           THEN 1 ELSE 0 END
    FROM contact_enriched WHERE Business_Individual IN ('I', 'C')

    UNION ALL

    -- ── Name: suffix in last_name ─────────────────────────────────────────────
    SELECT 'suffix_in_surname', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE WHEN
               last_name LIKE '% JR'  OR last_name LIKE '% JR.'
            OR last_name LIKE '% SR'  OR last_name LIKE '% SR.'
            OR last_name LIKE '% II'  OR last_name LIKE '% III'
            OR last_name LIKE '% IV'  OR last_name LIKE '% V'
            OR last_name LIKE '% MD'  OR last_name LIKE '% PHD'
            OR last_name LIKE '% CPA' OR last_name LIKE '% ESQ'
            OR last_name LIKE '% DDS' OR last_name LIKE '% DO'
           THEN 1 ELSE 0 END
    FROM contact_enriched WHERE Business_Individual IN ('I', 'C')

    UNION ALL

    -- ── Name: combined names in first_name ────────────────────────────────────
    SELECT 'combined_names_in_name', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE WHEN
               first_name LIKE '%&%'     OR first_name LIKE '% AND %'
            OR first_name LIKE '%/%'     OR first_name LIKE '% OR %'
           THEN 1 ELSE 0 END
    FROM contact_enriched WHERE Business_Individual IN ('I', 'C')

    UNION ALL

    -- ── Name: familiar name pattern "(Nick)" in first_name ───────────────────
    SELECT 'familiar_name_pattern', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE WHEN first_name LIKE '%(%)%' THEN 1 ELSE 0 END
    FROM contact_enriched WHERE Business_Individual IN ('I', 'C')

    UNION ALL

    -- ── Email: invalid format (no @ or no dot after @) ───────────────────────
    SELECT 'email_invalid_format', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE WHEN email IS NOT NULL AND email NOT LIKE '%@%.%' THEN 1 ELSE 0 END
    FROM contact_enriched

    UNION ALL

    -- ── Email: placeholder domain ─────────────────────────────────────────────
    SELECT 'email_placeholder', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE WHEN
               LOWER(email) LIKE 'noemail@%'       OR LOWER(email) LIKE 'test@test%'
            OR LOWER(email) LIKE 'none@none%'       OR LOWER(email) LIKE 'nomail@%'
            OR LOWER(email) LIKE 'donotcontact@%'   OR LOWER(email) LIKE 'noreply@%'
           THEN 1 ELSE 0 END
    FROM contact_enriched WHERE email IS NOT NULL

    UNION ALL

    -- ── Phone: biz sequential ────────────────────────────────────────────────
    SELECT 'biz_phone_sequential', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE WHEN biz_phone = '1234567890' THEN 1 ELSE 0 END
    FROM contact_enriched WHERE biz_phone IS NOT NULL

    UNION ALL

    -- ── Phone: biz repeated digit ────────────────────────────────────────────
    SELECT 'biz_phone_repeated_digit', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE WHEN LEN(biz_phone) = 10 AND biz_phone = REPLICATE(LEFT(biz_phone, 1), 10) THEN 1 ELSE 0 END
    FROM contact_enriched WHERE biz_phone IS NOT NULL

    UNION ALL

    -- ── Phone: biz wrong length ───────────────────────────────────────────────
    SELECT 'biz_phone_wrong_length', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE WHEN LEN(biz_phone) NOT IN (10, 11) THEN 1 ELSE 0 END
    FROM contact_enriched WHERE biz_phone IS NOT NULL

    UNION ALL

    -- ── Phone: priv sequential ───────────────────────────────────────────────
    SELECT 'priv_phone_sequential', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE WHEN priv_phone = '1234567890' THEN 1 ELSE 0 END
    FROM contact_enriched WHERE priv_phone IS NOT NULL

    UNION ALL

    -- ── Phone: priv repeated digit ───────────────────────────────────────────
    SELECT 'priv_phone_repeated_digit', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE WHEN LEN(priv_phone) = 10 AND priv_phone = REPLICATE(LEFT(priv_phone, 1), 10) THEN 1 ELSE 0 END
    FROM contact_enriched WHERE priv_phone IS NOT NULL

    UNION ALL

    -- ── Phone: priv wrong length ──────────────────────────────────────────────
    SELECT 'priv_phone_wrong_length', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE WHEN LEN(priv_phone) NOT IN (10, 11) THEN 1 ELSE 0 END
    FROM contact_enriched WHERE priv_phone IS NOT NULL

    UNION ALL

    -- ── Phone: mob sequential ────────────────────────────────────────────────
    SELECT 'mob_phone_sequential', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE WHEN mob_phone = '1234567890' THEN 1 ELSE 0 END
    FROM contact_enriched WHERE mob_phone IS NOT NULL

    UNION ALL

    -- ── Phone: mob repeated digit ────────────────────────────────────────────
    SELECT 'mob_phone_repeated_digit', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE WHEN LEN(mob_phone) = 10 AND mob_phone = REPLICATE(LEFT(mob_phone, 1), 10) THEN 1 ELSE 0 END
    FROM contact_enriched WHERE mob_phone IS NOT NULL

    UNION ALL

    -- ── Phone: mob wrong length ───────────────────────────────────────────────
    SELECT 'mob_phone_wrong_length', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE WHEN LEN(mob_phone) NOT IN (10, 11) THEN 1 ELSE 0 END
    FROM contact_enriched WHERE mob_phone IS NOT NULL

    UNION ALL

    -- ── Address: state not 2 chars ────────────────────────────────────────────
    SELECT 'state_not_2char', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE WHEN LEN(state) <> 2 THEN 1 ELSE 0 END
    FROM contact_enriched WHERE state IS NOT NULL

    UNION ALL

    -- ── Address: country not 2 chars ──────────────────────────────────────────
    SELECT 'country_not_2char', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE WHEN LEN(country) <> 2 THEN 1 ELSE 0 END
    FROM contact_enriched WHERE country IS NOT NULL

    UNION ALL

    -- ── Address: zip not 5-digit (US only) ───────────────────────────────────
    SELECT 'zip_not_5digits', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE WHEN pcode NOT LIKE '[0-9][0-9][0-9][0-9][0-9]'
                 AND pcode NOT LIKE '[0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]'
                THEN 1 ELSE 0 END
    FROM contact_enriched
    WHERE pcode IS NOT NULL
      AND ISNULL(country, 'US') = 'US'

    UNION ALL

    -- ── Coded fields: generation unrecognized ─────────────────────────────────
    SELECT 'generation_unrecognized', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE WHEN UPPER(LTRIM(RTRIM(generation))) NOT IN ('JR','JR.','JUNIOR','SR','SR.','SENIOR','II','III','IV','V')
                THEN 1 ELSE 0 END
    FROM contact_enriched
    WHERE Business_Individual IN ('I', 'C')
      AND generation IS NOT NULL

    UNION ALL

    -- ── Coded fields: title unrecognized ─────────────────────────────────────
    SELECT 'title_unrecognized', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE WHEN UPPER(LTRIM(RTRIM(title))) NOT IN (
               'MR','MR.','MRS','MRS.','MS','MS.','MISS',
               'DR','DR.','REV','REV.','PROF','PROF.',
               'CAPT','CAPT.','SGT','SGT.','COL','COL.',
               'MAJ','MAJ.','GEN','GEN.','HON','HON.'
           ) THEN 1 ELSE 0 END
    FROM contact_enriched
    WHERE Business_Individual IN ('I', 'C')
      AND title IS NOT NULL

    UNION ALL

    -- ── Coded fields: suffix unrecognized ─────────────────────────────────────
    SELECT 'suffix_unrecognized', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE WHEN UPPER(LTRIM(RTRIM(suffix))) NOT IN (
               'MD','DO','DDS','DMD','DVM','PHD','PH.D.','JD','CPA',
               'RN','NP','PA','PE','ESQ','ESQ.','MBA','CFA','CFP',
               'LCSW','CPCU','FACP','FACS'
           ) THEN 1 ELSE 0 END
    FROM contact_enriched
    WHERE Business_Individual IN ('I', 'C')
      AND suffix IS NOT NULL

    UNION ALL

    -- ── Branch: invalid / closed branch code ──────────────────────────────────
    SELECT 'invalid_branch', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE WHEN branch IN ('07','13','52','55','61','63','64','67','70','71')
                THEN 1 ELSE 0 END
    FROM contact_enriched WHERE branch IS NOT NULL

    UNION ALL

    -- ── contact_code: whitespace ──────────────────────────────────────────────
    SELECT 'contact_code_has_whitespace', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE WHEN PATINDEX('%[' + CHAR(32) + CHAR(9) + CHAR(10) + CHAR(13) + ']%', contact_code) > 0
                THEN 1 ELSE 0 END
    FROM contact_enriched

    UNION ALL

    -- ── contact_code: non-alphanumeric characters ─────────────────────────────
    SELECT 'contact_code_non_alphanumeric', Business_Individual, sales_decile, staleness_bucket, branch, creation_cohort,
           CASE WHEN PATINDEX('%[^A-Za-z0-9]%', contact_code) > 0 THEN 1 ELSE 0 END
    FROM contact_enriched

) sq
GROUP BY sq.metric_name, sq.contact_type, sq.sales_decile, sq.staleness_bucket, sq.branch, sq.creation_cohort

UNION ALL

-- ── contact_code: normalized duplicates — left join so every dim slice emits a row ──
SELECT
    CAST(GETDATE() AS date), 'field_quality', 'contact_code_duplicate_normalized',
    ce.Business_Individual, ce.sales_decile, ce.staleness_bucket, ce.branch, ce.creation_cohort,
    SUM(CASE WHEN dc.norm_code IS NOT NULL THEN 1 ELSE 0 END),
    COUNT(*)
FROM contact_enriched ce
    LEFT JOIN dup_codes dc ON dc.norm_code = UPPER(LTRIM(RTRIM(ce.contact_code)))
GROUP BY ce.Business_Individual, ce.sales_decile, ce.staleness_bucket, ce.branch, ce.creation_cohort

/* ═══════════════════════════════════════════════════════
   SECTION 5 — Staleness
   metric_name IS the bucket; staleness_bucket column = 'ALL'.
   Spine: all 8 buckets × every dim slice so denominators are uniform
   when Power BI rolls up — missing buckets get numerator = 0.
   ═══════════════════════════════════════════════════════ */

UNION ALL

SELECT
    CAST(GETDATE() AS date)      AS snapshot_date,
    'staleness'                  AS metric_category,
    ss.staleness_bucket          AS metric_name,
    ss.Business_Individual       AS contact_type,
    ss.sales_decile,
    'ALL'                        AS staleness_bucket,
    ss.branch,
    ss.creation_cohort,
    ISNULL(sn.numerator, 0)      AS numerator,
    ss.denominator
FROM s5_spine ss
    LEFT JOIN s5_numerator sn
        ON  sn.staleness_bucket    = ss.staleness_bucket
        AND sn.Business_Individual = ss.Business_Individual
        AND sn.sales_decile        = ss.sales_decile
        AND ISNULL(sn.branch, '')  = ISNULL(ss.branch, '')
        AND sn.creation_cohort     = ss.creation_cohort

/* ═══════════════════════════════════════════════════════
   SECTION 6 — Match Readiness
   Scope: unlinked active non-employee contacts only.
   Spine: all 4 tiers × every dim slice so denominators are uniform
   when Power BI rolls up — missing tiers get numerator = 0.
   ═══════════════════════════════════════════════════════ */

UNION ALL

SELECT
    CAST(GETDATE() AS date)      AS snapshot_date,
    'match_readiness'            AS metric_category,
    ss.metric_name,
    ss.Business_Individual       AS contact_type,
    ss.sales_decile,
    ss.staleness_bucket,
    ss.branch,
    ss.creation_cohort,
    ISNULL(sn.numerator, 0)      AS numerator,
    ss.denominator
FROM s6_spine ss
    LEFT JOIN s6_numerator sn
        ON  sn.tier                = ss.tier
        AND sn.Business_Individual = ss.Business_Individual
        AND sn.sales_decile        = ss.sales_decile
        AND sn.staleness_bucket    = ss.staleness_bucket
        AND ISNULL(sn.branch, '')  = ISNULL(ss.branch, '')
        AND sn.creation_cohort     = ss.creation_cohort

ORDER BY metric_category, metric_name, contact_type, sales_decile, staleness_bucket, branch, creation_cohort;
