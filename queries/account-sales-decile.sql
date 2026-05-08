-- Sales decile assignment for data quality snapshot
-- R60 = rolling 60 complete months (5-year window); D1 = highest revenue
-- Contacts with no account or no R60 revenue → Unranked

WITH date_range AS (
    SELECT
        CAST(EOMONTH(DATEADD(MONTH, -1, GETDATE())) AS date) AS [EndDate]
),
dr AS (
    SELECT
        [EndDate],
        CAST(DATEADD(MONTH, -59, DATEFROMPARTS(YEAR([EndDate]), MONTH([EndDate]), 1)) AS date) AS [StartDate]
    FROM date_range
),
account_revenue AS (
    SELECT
        [AccountNumber],
        SUM([CompleteGoods] + [Parts] + [Service] + [Rental]) AS [TotalRevenue]
    FROM (
        /* Complete Goods */
        SELECT
            [ArMaster_Customer].[Customer_No] AS [AccountNumber],
            CAST(
                (
                    SUM(ISNULL([VhStock].[SALES_VALUE], 0))
                        + ISNULL((
                            SELECT SUM(ISNULL([VhStockAccess].[Sale_Value], 0))
                            FROM [Bronze_Production_Lakehouse].[Equip].[VhStockAccess]
                            WHERE [VhStock].[NO] = [VhStockAccess].[Stock_No]
                        ), 0)
                ) AS DECIMAL(12, 2)
            ) AS [CompleteGoods],
            CAST(0 AS DECIMAL(12, 2)) AS [Parts],
            CAST(0 AS DECIMAL(12, 2)) AS [Service],
            CAST(0 AS DECIMAL(12, 2)) AS [Rental]
        FROM [Bronze_Production_Lakehouse].[Equip].[ArMaster_Customer]
            INNER JOIN [Bronze_Production_Lakehouse].[Equip].[VhStock]
                ON [VhStock].[Owner] = [ArMaster_Customer].[contact_code]
        WHERE [VhStock].[SALESDATE] BETWEEN (SELECT [StartDate] FROM dr) AND (SELECT [EndDate] FROM dr)
        GROUP BY
            [VhStock].[NO],
            [ArMaster_Customer].[Customer_No]

        UNION ALL

        /* Parts */
        SELECT
            [ArMaster_Customer].[Customer_No] AS [AccountNumber],
            CAST(0 AS DECIMAL(12, 2)) AS [CompleteGoods],
            CAST(SUM(ISNULL([Invoice].[parts_sale_val], 0)) AS DECIMAL(12, 2)) AS [Parts],
            CAST(0 AS DECIMAL(12, 2)) AS [Service],
            CAST(0 AS DECIMAL(12, 2)) AS [Rental]
        FROM [Bronze_Production_Lakehouse].[Equip].[ArMaster_Customer]
            INNER JOIN [Bronze_Production_Lakehouse].[Equip].[Invoice]
                ON [Invoice].[bill_to_acc] = [ArMaster_Customer].[Customer_No]
               AND [Invoice].[invo_type] IN ('C', 'I')
               AND [Invoice].[module_type] = 'I'
        WHERE [Invoice].[invo_datetime] BETWEEN (SELECT [StartDate] FROM dr) AND (SELECT [EndDate] FROM dr)
        GROUP BY
            [ArMaster_Customer].[Customer_No]

        UNION ALL

        /* Service */
        SELECT
            [ArMaster_Customer].[Customer_No] AS [AccountNumber],
            CAST(0 AS DECIMAL(12, 2)) AS [CompleteGoods],
            CAST(0 AS DECIMAL(12, 2)) AS [Parts],
            CAST(
                SUM(
                    ISNULL([Invoice].[parts_sale_val], 0)
                        + ISNULL([Invoice].[labour_sale_val], 0)
                        + ISNULL([Invoice].[sublet_sal_val], 0)
                        + ISNULL([Invoice].[other_sale_val], 0)
                ) AS DECIMAL(12, 2)
            ) AS [Service],
            CAST(0 AS DECIMAL(12, 2)) AS [Rental]
        FROM [Bronze_Production_Lakehouse].[Equip].[ArMaster_Customer]
            INNER JOIN [Bronze_Production_Lakehouse].[Equip].[Invoice]
                ON [Invoice].[bill_to_acc] = [ArMaster_Customer].[Customer_No]
               AND [Invoice].[invo_type] IN ('C', 'I')
               AND [Invoice].[module_type] = 'W'
        WHERE [Invoice].[invo_datetime] BETWEEN (SELECT [StartDate] FROM dr) AND (SELECT [EndDate] FROM dr)
        GROUP BY
            [ArMaster_Customer].[Customer_No]

        UNION ALL

        /* Rental */
        SELECT
            [ArMaster_Customer].[Customer_No] AS [AccountNumber],
            CAST(0 AS DECIMAL(12, 2)) AS [CompleteGoods],
            CAST(0 AS DECIMAL(12, 2)) AS [Parts],
            CAST(0 AS DECIMAL(12, 2)) AS [Service],
            CAST(SUM(ISNULL([Rental_History].[Value], 0)) AS DECIMAL(12, 2)) AS [Rental]
        FROM [Bronze_Production_Lakehouse].[Equip].[ArMaster_Customer]
            INNER JOIN [Bronze_Production_Lakehouse].[Equip].[Invoice]
                ON [Invoice].[bill_to_acc] = [ArMaster_Customer].[Customer_No]
               AND [Invoice].[invo_type] IN ('C', 'I')
            LEFT OUTER JOIN [Bronze_Production_Lakehouse].[Equip].[Rental_History]
                ON [Invoice].[document_no] = [Rental_History].[Invoice_No]
        WHERE [Invoice].[invo_datetime] BETWEEN (SELECT [StartDate] FROM dr) AND (SELECT [EndDate] FROM dr)
        GROUP BY
            [ArMaster_Customer].[Customer_No]
    ) sq
    GROUP BY [AccountNumber]
),
revenue_ranked AS (
    -- NTILE only on accounts with positive R60 revenue; zero/negative stay out → Unranked
    SELECT
        [AccountNumber],
        [TotalRevenue],
        NTILE(10) OVER (ORDER BY [TotalRevenue] DESC) AS [RawDecile]
    FROM account_revenue
    WHERE [TotalRevenue] > 0
),
active_contacts AS (
    -- All active non-employee contacts with their account number (NULL if no ArMaster record)
    SELECT
        c.[contact_code],
        c.[Business_Individual],
        am.[Customer_No] AS [AccountNumber]
    FROM [Bronze_Production_Lakehouse].[Equip].[contact] c
        LEFT JOIN [Bronze_Production_Lakehouse].[Equip].[ArMaster_Customer] am
            ON am.[contact_code] = c.[contact_code]
        LEFT JOIN [Bronze_Production_Lakehouse].[Equip].[WKMECHFL] wk
            ON wk.[Code] = c.[contact_code]
        LEFT JOIN [Bronze_Production_Lakehouse].[Equip].[VhSalman] vs
            ON vs.[CODE] = c.[contact_code]
    WHERE ISNULL(c.[Inactive_Indicator], 'A') <> 'I'
      AND wk.[Code] IS NULL
      AND vs.[CODE] IS NULL
)
SELECT
    ac.[contact_code],
    ac.[Business_Individual],
    ac.[AccountNumber],
    ISNULL(rr.[TotalRevenue], 0)                       AS [TotalRevenue_R60],
    CASE
        WHEN ac.[AccountNumber] IS NULL THEN 'Unranked'   -- no ArMaster record
        WHEN rr.[AccountNumber] IS NULL THEN 'Unranked'   -- no positive R60 revenue
        ELSE 'D' + CAST(rr.[RawDecile] AS VARCHAR(2))
    END                                                AS [SalesDecile],
    dr.[StartDate]                                     AS [R60_Start],
    dr.[EndDate]                                       AS [R60_End]
FROM active_contacts ac
    LEFT JOIN revenue_ranked rr ON rr.[AccountNumber] = ac.[AccountNumber]
    CROSS JOIN dr
ORDER BY
    ISNULL(rr.[TotalRevenue], 0) DESC;
