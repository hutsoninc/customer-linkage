let
    Source = Sql.Database(
        "26uvtcjpbewezphfsvea336vji-pzx7gvzmumzubkrzfqlfxchiaa.datawarehouse.fabric.microsoft.com",
        "Bronze_Production_Lakehouse",
        [CreateNavigationProperties = false]
    ),
    Result = Value.NativeQuery(
        Source,
        "
WITH active_contacts AS (
    SELECT
        c.contact_code,
        c.Business_Individual,
        c.Ckc_Id,
        CASE
            WHEN c.Creation_Date IS NULL              THEN 'Unknown'
            WHEN YEAR(c.Creation_Date) < 2015         THEN 'Pre-2015'
            WHEN YEAR(c.Creation_Date) < 2020         THEN '2015-2020'
            WHEN YEAR(c.Creation_Date) < 2025         THEN '2020-2025'
            ELSE                                           '2025+'
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
contact_linkage AS (
    SELECT
        ac.contact_code,
        ac.Business_Individual,
        ac.Ckc_Id,
        ac.creation_cohort,
        xr.entity_id,
        xr.contact_id,
        CASE WHEN xr.cross_ref_number IS NOT NULL THEN 1 ELSE 0 END AS is_linked
    FROM active_contacts ac
        LEFT JOIN [Bronze_Production_Lakehouse].[DDP].[customer_cross_ref] xr
            ON UPPER(xr.cross_ref_number) = UPPER(ac.contact_code)
           AND xr.entity_id <> 999999998
)
SELECT
    CAST(GETDATE() AS date) AS snapshot_date,
    'linkage'               AS metric_category,
    'linked_count'          AS metric_name,
    Business_Individual     AS contact_type,
    'ALL'                   AS sales_decile,
    'ALL'                   AS staleness_bucket,
    'ALL'                   AS branch,
    creation_cohort,
    SUM(is_linked)          AS numerator,
    COUNT(*)                AS denominator
FROM contact_linkage
GROUP BY Business_Individual, creation_cohort
UNION ALL
SELECT
    CAST(GETDATE() AS date), 'linkage', 'unlinked_count',
    Business_Individual, 'ALL', 'ALL', 'ALL', creation_cohort,
    SUM(1 - is_linked), COUNT(*)
FROM contact_linkage
GROUP BY Business_Individual, creation_cohort
UNION ALL
SELECT
    CAST(GETDATE() AS date), 'linkage', 'ckc_id_no_cross_ref',
    Business_Individual, 'ALL', 'ALL', 'ALL', creation_cohort,
    SUM(CASE WHEN Ckc_Id IS NOT NULL AND is_linked = 0 THEN 1 ELSE 0 END),
    SUM(CASE WHEN Ckc_Id IS NOT NULL THEN 1 ELSE 0 END)
FROM contact_linkage
GROUP BY Business_Individual, creation_cohort
UNION ALL
SELECT
    CAST(GETDATE() AS date), 'linkage', 'type_mismatch_linkage',
    Business_Individual, 'ALL', 'ALL', 'ALL', creation_cohort,
    SUM(CASE
        WHEN Business_Individual = 'C'         AND contact_id <> 0 THEN 1
        WHEN Business_Individual IN ('B', 'I') AND contact_id  = 0 THEN 1
        ELSE 0
    END),
    SUM(is_linked)
FROM contact_linkage
WHERE is_linked = 1
GROUP BY Business_Individual, creation_cohort
UNION ALL
SELECT
    CAST(GETDATE() AS date), 'linkage', 'duplicate_entity_id',
    'ALL', 'ALL', 'ALL', 'ALL', 'ALL',
    COUNT(*),
    (SELECT COUNT(*) FROM active_contacts)
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
    'ALL', 'ALL', 'ALL', 'ALL', 'ALL',
    COUNT(*),
    (SELECT COUNT(*) FROM [Bronze_Production_Lakehouse].[DDP].[customer_cross_ref]
     WHERE entity_id <> 999999998)
FROM [Bronze_Production_Lakehouse].[DDP].[customer_cross_ref] xr_all
WHERE xr_all.entity_id <> 999999998
  AND NOT EXISTS (
      SELECT 1
      FROM active_contacts ac
      WHERE UPPER(ac.contact_code) = UPPER(xr_all.cross_ref_number)
  )
",
        null,
        [EnableFolding = false]
    )
in
    Result
