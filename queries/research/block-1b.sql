-- Block 1b: ArMaster to contact cardinality
-- Confirm whether each ArMaster account maps to exactly one contact code.

SELECT
    contact_code_count,
    COUNT(ACC_NO) AS account_count
FROM (
    SELECT contact_code, COUNT(ACC_NO) AS contact_code_count
    FROM Equip.ArMaster
    GROUP BY contact_code
) t
GROUP BY contact_code_count
ORDER BY contact_code_count
