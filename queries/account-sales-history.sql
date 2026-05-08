SELECT
    [AccountNumber],
    [Year],
    [Month],
    SUM([CompleteGoods]) AS [CompleteGoods],
    SUM([CompleteGoodsCost]) AS [CompleteGoodsCost],
    SUM([Parts]) AS [Parts],
    SUM([PartsCost]) AS [PartsCost],
    SUM([Service]) AS [Service],
    SUM([ServiceCost]) AS [ServiceCost],
    SUM([Rental]) AS [Rental],
    SUM([RentalCost]) AS [RentalCost],
    SUM([CompleteGoodsUnits]) AS [CompleteGoodsUnits]
FROM (
    /* Sales */
    SELECT
        [ArMaster_Customer].[Customer_No] AS [AccountNumber],
        YEAR([VhStock].[SALESDATE]) AS [Year],
        MONTH([VhStock].[SALESDATE]) AS [Month],
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
        CAST(
            SUM(
                ISNULL([VhStock].[WHOLESALE], 0)
                    + ISNULL([VhStock].[RETAIL], 0)
                    + ISNULL([VhStock].[PREDEL_COST], 0)
                    + ISNULL([VhStock].[REPAIR_COST], 0)
                    + ISNULL([VhStock].[ACCESS_COST], 0)
                    + ISNULL([VhStock].[REGO_FEES], 0)
                    + ISNULL([VhStock].[LOT_FEES], 0)
                    + ISNULL([VhStock].[STAMP_DUTY], 0)
                    + ISNULL([VhStock].[TRANSFER_FEES], 0)
                    + ISNULL([VhStock].[OTHER_COST], 0)
                    + ISNULL([VhStock].[Option_Cost], 0)
                    + ISNULL([VhStock].[Paint_Cost], 0)
                    + ISNULL([VhStock].[Trim_Cost], 0)
                    + ISNULL([VhStock].[Charge_Cost], 0)
                    + ISNULL([VhStock].[After_Market_Cost], 0)
                    + ISNULL([VhStock].[Surcharge_Cost], 0)
            ) AS DECIMAL(12, 2)
        ) AS [CompleteGoodsCost],
        [Parts] = 0,
        [PartsCost] = 0,
        [Service] = 0,
        [ServiceCost] = 0,
        [Rental] = 0,
        [RentalCost] = 0,
        [CompleteGoodsUnits] = COUNT([VhStock].[NO])
    FROM [Bronze_Production_Lakehouse].[Equip].[ArMaster_Customer]
        INNER JOIN [Bronze_Production_Lakehouse].[Equip].[VhStock] ON [VhStock].[Owner] = [ArMaster_Customer].[contact_code]
    WHERE YEAR([VhStock].[SALESDATE]) >= 2021 AND YEAR([VhStock].[SALESDATE]) <= YEAR(GETDATE())
    GROUP BY
        [VhStock].[NO],
        [ArMaster_Customer].[Customer_No],
        YEAR([VhStock].[SALESDATE]),
        MONTH([VhStock].[SALESDATE])
    UNION ALL
    /* Parts */
    SELECT
        [ArMaster_Customer].[Customer_No] AS [AccountNumber],
        YEAR([Invoice].[invo_datetime]) AS [Year],
        MONTH([Invoice].[invo_datetime]) AS [Month],
        [CompleteGoods] = 0,
        [CompleteGoodsCost] = 0,
        CAST(
            SUM(
                ISNULL([Invoice].[parts_sale_val], 0)
            ) AS DECIMAL(12, 2)
        ) AS [Parts],
        CAST(
            SUM(
                ISNULL([Invoice].[parts_cost_val], 0)
            ) AS DECIMAL(12, 2)
        ) AS [PartsCost],
        [Service] = 0,
        [ServiceCost] = 0,
        [Rental] = 0,
        [RentalCost] = 0,
        [CompleteGoodsUnits] = 0
    FROM [Bronze_Production_Lakehouse].[Equip].[ArMaster_Customer]
        INNER JOIN [Bronze_Production_Lakehouse].[Equip].[Invoice] ON [Invoice].[bill_to_acc] = [ArMaster_Customer].[Customer_No] AND [Invoice].[invo_type] IN ('C', 'I') AND [Invoice].[module_type] = 'I'
    WHERE YEAR([Invoice].[invo_datetime]) >= 2021 AND YEAR([Invoice].[invo_datetime]) <= YEAR(GETDATE())
    GROUP BY
        [ArMaster_Customer].[Customer_No],
        YEAR([Invoice].[invo_datetime]),
        MONTH([Invoice].[invo_datetime])
    UNION ALL
    /* Service */
    SELECT
        [ArMaster_Customer].[Customer_No] AS [AccountNumber],
        YEAR([Invoice].[invo_datetime]) AS [Year],
        MONTH([Invoice].[invo_datetime]) AS [Month],
        [CompleteGoods] = 0,
        [CompleteGoodsCost] = 0,
        [Parts] = 0,
        [PartsCost] = 0,
        CAST(
            SUM(
                ISNULL([Invoice].[parts_sale_val], 0)
                    + ISNULL([Invoice].[labour_sale_val], 0)
                    + ISNULL([Invoice].[sublet_sal_val], 0)
                    + ISNULL([Invoice].[other_sale_val], 0)
            ) AS DECIMAL(12, 2)
        ) AS [Service],
        CAST(
            SUM(
                ISNULL([Invoice].[parts_cost_val], 0)
                + ISNULL([Invoice].[labour_cost_val], 0)
                + ISNULL([Invoice].[sublet_cost_val], 0)
            ) AS DECIMAL(12, 2)
        ) AS [ServiceCost],
        [Rental] = 0,
        [RentalCost] = 0,
        [CompleteGoodsUnits] = 0
    FROM [Bronze_Production_Lakehouse].[Equip].[ArMaster_Customer]
        INNER JOIN [Bronze_Production_Lakehouse].[Equip].[Invoice] ON [Invoice].[bill_to_acc] = [ArMaster_Customer].[Customer_No] AND [Invoice].[invo_type] IN ('C', 'I') AND [Invoice].[module_type] = 'W'
    WHERE YEAR([Invoice].[invo_datetime]) >= 2021 AND YEAR([Invoice].[invo_datetime]) <= YEAR(GETDATE())
    GROUP BY
        [ArMaster_Customer].[Customer_No],
        YEAR([Invoice].[invo_datetime]),
        MONTH([Invoice].[invo_datetime])
    UNION ALL
    /* Rental */
    SELECT
        [ArMaster_Customer].[Customer_No] AS [AccountNumber],
        YEAR([Invoice].[invo_datetime]) AS [Year],
        MONTH([Invoice].[invo_datetime]) AS [Month],
        [CompleteGoods] = 0,
        [CompleteGoodsCost] = 0,
        [Parts] = 0,
        [PartsCost] = 0,
        [Service] = 0,
        [ServiceCost] = 0,
        CAST(
            SUM(
                ISNULL([Rental_History].[Value], 0)
            ) AS DECIMAL(12, 2)
        ) AS [Rental],
        CAST(
            SUM(
                ISNULL([Rental_History].[Depr_Book_Value], 0)
            ) AS DECIMAL(12, 2)
        ) AS [Rental_Cost],
        [CompleteGoodsUnits] = 0
    FROM [Bronze_Production_Lakehouse].[Equip].[ArMaster_Customer]
        INNER JOIN [Bronze_Production_Lakehouse].[Equip].[Invoice] ON [Invoice].[bill_to_acc] = [ArMaster_Customer].[Customer_No] AND [Invoice].[invo_type] IN ('C', 'I')
        LEFT OUTER JOIN [Bronze_Production_Lakehouse].[Equip].[Rental_History] ON [Invoice].[document_no] = [Rental_History].[Invoice_No]
    WHERE YEAR([Invoice].[invo_datetime]) >= 2021 AND YEAR([Invoice].[invo_datetime]) <= YEAR(GETDATE())
    GROUP BY
        [ArMaster_Customer].[Customer_No],
        YEAR([Invoice].[invo_datetime]),
        MONTH([Invoice].[invo_datetime])
) sq
GROUP BY
    [AccountNumber],
    [Year],
    [Month]
ORDER BY
    [Year] DESC,
    [Month] DESC