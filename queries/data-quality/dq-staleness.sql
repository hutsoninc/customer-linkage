-- Section 5: Account Staleness
-- data-quality-plan.md § 5
-- Output conforms to data_quality_snapshot schema:
--   snapshot_date, metric_category, metric_name, contact_type,
--   sales_decile, staleness_bucket (dim), branch, creation_cohort, numerator, denominator
--
-- Combines R60 revenue decile (account-sales-decile.sql) with last transaction date
-- across all departments (last-invoice-dates.sql pattern).
-- module_type = 'I' for Parts, 'W' for Service.
-- metric_name = specific staleness bucket; rows broken out by contact_type × sales_decile × creation_cohort.

WITH

/* ── Rolling 60-month revenue window ────────────────────────────────── */
date_range AS (
    SELECT CAST(EOMONTH(DATEADD(MONTH, -1, GETDATE())) AS date) AS EndDate
),
dr AS (
    SELECT
        EndDate,
        CAST(DATEADD(MONTH, -59, DATEFROMPARTS(YEAR(EndDate), MONTH(EndDate), 1)) AS date) AS StartDate
    FROM date_range
),

/* ── R60 revenue by account → decile ─────────────────────────────── */
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
            AS DECIMAL(12, 2)) AS CompleteGoods,
            CAST(0 AS DECIMAL(12, 2)) AS Parts,
            CAST(0 AS DECIMAL(12, 2)) AS Service,
            CAST(0 AS DECIMAL(12, 2)) AS Rental
        FROM [Bronze_Production_Lakehouse].[Equip].[ArMaster_Customer] am
            INNER JOIN [Bronze_Production_Lakehouse].[Equip].[VhStock] vhs
                ON vhs.Owner = am.contact_code
        WHERE vhs.SALESDATE BETWEEN (SELECT StartDate FROM dr) AND (SELECT EndDate FROM dr)
        GROUP BY vhs.NO, am.Customer_No

        UNION ALL

        SELECT am.Customer_No,
            CAST(0 AS DECIMAL(12, 2)),
            CAST(SUM(ISNULL(i.parts_sale_val, 0)) AS DECIMAL(12, 2)),
            CAST(0 AS DECIMAL(12, 2)),
            CAST(0 AS DECIMAL(12, 2))
        FROM [Bronze_Production_Lakehouse].[Equip].[ArMaster_Customer] am
            INNER JOIN [Bronze_Production_Lakehouse].[Equip].[Invoice] i
                ON i.bill_to_acc = am.Customer_No
               AND i.invo_type IN ('C', 'I')
               AND i.module_type = 'I'
        WHERE i.invo_datetime BETWEEN (SELECT StartDate FROM dr) AND (SELECT EndDate FROM dr)
        GROUP BY am.Customer_No

        UNION ALL

        SELECT am.Customer_No,
            CAST(0 AS DECIMAL(12, 2)),
            CAST(0 AS DECIMAL(12, 2)),
            CAST(SUM(
                ISNULL(i.parts_sale_val,  0) + ISNULL(i.labour_sale_val, 0)
                + ISNULL(i.sublet_sal_val, 0) + ISNULL(i.other_sale_val,  0)
            ) AS DECIMAL(12, 2)),
            CAST(0 AS DECIMAL(12, 2))
        FROM [Bronze_Production_Lakehouse].[Equip].[ArMaster_Customer] am
            INNER JOIN [Bronze_Production_Lakehouse].[Equip].[Invoice] i
                ON i.bill_to_acc = am.Customer_No
               AND i.invo_type IN ('C', 'I')
               AND i.module_type = 'W'
        WHERE i.invo_datetime BETWEEN (SELECT StartDate FROM dr) AND (SELECT EndDate FROM dr)
        GROUP BY am.Customer_No

        UNION ALL

        SELECT am.Customer_No,
            CAST(0 AS DECIMAL(12, 2)),
            CAST(0 AS DECIMAL(12, 2)),
            CAST(0 AS DECIMAL(12, 2)),
            CAST(SUM(ISNULL(rh.Value, 0)) AS DECIMAL(12, 2))
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

/* ── Last transaction date per account (all departments) ─────────── */
last_tx AS (
    SELECT acc_no, MAX(tx_date) AS last_tx_date
    FROM (
        -- Complete goods (VhStock joins via contact_code; resolve to Customer_No)
        SELECT am.Customer_No AS acc_no, CAST(vhs.SALESDATE AS date) AS tx_date
        FROM [Bronze_Production_Lakehouse].[Equip].[ArMaster_Customer] am
            INNER JOIN [Bronze_Production_Lakehouse].[Equip].[VhStock] vhs
                ON vhs.Owner = am.contact_code
        WHERE vhs.SALESDATE IS NOT NULL

        UNION ALL

        -- Parts (module_type = 'I')
        SELECT am.Customer_No, CAST(i.invo_datetime AS date)
        FROM [Bronze_Production_Lakehouse].[Equip].[ArMaster_Customer] am
            INNER JOIN [Bronze_Production_Lakehouse].[Equip].[Invoice] i
                ON i.bill_to_acc = am.Customer_No
               AND i.invo_type IN ('C', 'I')
               AND i.module_type = 'I'
        WHERE i.invo_datetime IS NOT NULL

        UNION ALL

        -- Service (module_type = 'W')
        SELECT am.Customer_No, CAST(i.invo_datetime AS date)
        FROM [Bronze_Production_Lakehouse].[Equip].[ArMaster_Customer] am
            INNER JOIN [Bronze_Production_Lakehouse].[Equip].[Invoice] i
                ON i.bill_to_acc = am.Customer_No
               AND i.invo_type IN ('C', 'I')
               AND i.module_type = 'W'
        WHERE i.invo_datetime IS NOT NULL

        UNION ALL

        -- Rental (must have matching Rental_History row)
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

/* ── Active contacts ─────────────────────────────────────────────── */
active_contacts AS (
    SELECT
        c.contact_code,
        c.Business_Individual,
        c.Creation_Date,
        am.Customer_No AS acc_no
    FROM [Bronze_Production_Lakehouse].[Equip].[contact] c
        LEFT JOIN [Bronze_Production_Lakehouse].[Equip].[WKMECHFL] wk ON wk.Code = c.contact_code
        LEFT JOIN [Bronze_Production_Lakehouse].[Equip].[VhSalman] vs ON vs.CODE = c.contact_code
        LEFT JOIN [Bronze_Production_Lakehouse].[Equip].[ArMaster_Customer] am ON am.contact_code = c.contact_code
    WHERE ISNULL(c.Inactive_Indicator, 'A') <> 'I'
      AND wk.Code IS NULL
      AND vs.CODE IS NULL
),

/* ── Enrich each contact with staleness bucket, decile, cohort ───── */
contact_enriched AS (
    SELECT
        ac.contact_code,
        ac.Business_Individual,
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
            WHEN ac.acc_no IS NULL         THEN 'Unranked'
            WHEN rr.AccountNumber IS NULL  THEN 'Unranked'
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
        LEFT JOIN last_tx lt           ON lt.acc_no         = ac.acc_no
        LEFT JOIN revenue_ranked rr    ON rr.AccountNumber  = ac.acc_no
)

SELECT
    CAST(GETDATE() AS date)  AS snapshot_date,
    'staleness'              AS metric_category,
    ce.staleness_bucket      AS metric_name,
    ce.Business_Individual   AS contact_type,
    ce.sales_decile,
    'ALL'                    AS staleness_bucket,
    'ALL'                    AS branch,
    ce.creation_cohort,
    COUNT(*)                 AS numerator,
    SUM(COUNT(*)) OVER (
        PARTITION BY ce.Business_Individual, ce.sales_decile, ce.creation_cohort
    )                        AS denominator
FROM contact_enriched ce
GROUP BY ce.staleness_bucket, ce.Business_Individual, ce.sales_decile, ce.creation_cohort
ORDER BY
    CASE ce.staleness_bucket
        WHEN 'No Account'       THEN 0
        WHEN 'Never Transacted' THEN 1
        WHEN '0-1yr'            THEN 2
        WHEN '1-2yr'            THEN 3
        WHEN '2-3yr'            THEN 4
        WHEN '3-4yr'            THEN 5
        WHEN '4-5yr'            THEN 6
        ELSE                         7
    END,
    ce.Business_Individual,
    ce.sales_decile;
