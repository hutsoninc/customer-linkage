-- Block 1a: Contact type breakdown
-- Distribution of active vs. inactive contacts by type (B/I/C),
-- and how many have Ckc_Id and Cmp_Ckc_Id populated.

SELECT
    Business_Individual,
    ISNULL(Inactive_Indicator, 'A')         AS status,
    COUNT(*)                                 AS total,
    COUNT(Ckc_Id)                            AS has_ckc_id,
    SUM(CASE WHEN Cmp_Ckc_Id IS NULL THEN 1 ELSE 0 END)   AS cmp_null,
    SUM(CASE WHEN Cmp_Ckc_Id = 0    THEN 1 ELSE 0 END)    AS cmp_zero,
    SUM(CASE WHEN Cmp_Ckc_Id > 0    THEN 1 ELSE 0 END)    AS cmp_populated
FROM Equip.contact
GROUP BY Business_Individual, ISNULL(Inactive_Indicator, 'A')
ORDER BY Business_Individual, status
