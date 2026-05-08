-- Section 4g: Coded Field Value Surfacing (Suffix, Prefix/Title)
-- data-quality-plan.md § 4g
-- Run before defining valid value lists — surface what's actually in the data.
-- This is a diagnostic query; results are NOT appended to data_quality_snapshot.
-- Scope: active non-employee contacts (I, C types)

WITH active_IC AS (
    SELECT
        c.contact_code,
        c.Business_Individual,
        c.title,
        c.Generation,
        c.Suffix
    FROM [Bronze_Production_Lakehouse].[Equip].[contact] c
        LEFT JOIN [Bronze_Production_Lakehouse].[Equip].[WKMECHFL] wk
            ON wk.[Code] = c.contact_code
        LEFT JOIN [Bronze_Production_Lakehouse].[Equip].[VhSalman] vs
            ON vs.[CODE] = c.contact_code
    WHERE ISNULL(c.Inactive_Indicator, 'A') <> 'I'
      AND wk.[Code] IS NULL
      AND vs.[CODE] IS NULL
      AND c.Business_Individual IN ('I', 'C')
)

SELECT 'suffix' AS field_name, Suffix AS field_value, COUNT(*) AS contact_count
FROM active_IC
WHERE NULLIF(LTRIM(RTRIM(Suffix)), '') IS NOT NULL
GROUP BY Suffix

UNION ALL

SELECT 'title', title, COUNT(*)
FROM active_IC
WHERE NULLIF(LTRIM(RTRIM(title)), '') IS NOT NULL
GROUP BY title

ORDER BY field_name, contact_count DESC;
