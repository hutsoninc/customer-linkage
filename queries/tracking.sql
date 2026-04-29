-- tracking.sql: Linkage progress for the Hutson customer linkage project
--
-- Run any time to see current state and project-attributed linkages.
-- "Project start" = 2026-04-29. Anything created on or after that date
-- and attributable to a known upload batch is counted as project progress.
--
-- Usage:
--   python scripts/fabric_query.py --file queries/tracking.sql --block tracking

-- Section 1: Total linkages — baseline vs. current
SELECT
    'BASELINE (before 2026-04-29)'          AS period,
    COUNT(*)                                 AS linkage_count
FROM DDP.customer_cross_ref
WHERE acct_id = '034320'
  AND (cross_ref_created_ts < '2026-04-29' OR cross_ref_created_ts IS NULL)

UNION ALL

SELECT
    'PROJECT (2026-04-29 onward)'            AS period,
    COUNT(*)                                 AS linkage_count
FROM DDP.customer_cross_ref
WHERE acct_id = '034320'
  AND cross_ref_created_ts >= '2026-04-29'

UNION ALL

SELECT
    'TOTAL (all time)'                       AS period,
    COUNT(*)                                 AS linkage_count
FROM DDP.customer_cross_ref
WHERE acct_id = '034320'

ORDER BY period;

-- Section 2: Project linkages by date (shows daily progress since project start)
SELECT
    CAST(cross_ref_created_ts AS DATE)       AS created_date,
    COUNT(*)                                 AS new_linkages,
    SUM(COUNT(*)) OVER (
        ORDER BY CAST(cross_ref_created_ts AS DATE)
    )                                        AS project_running_total
FROM DDP.customer_cross_ref
WHERE acct_id = '034320'
  AND cross_ref_created_ts >= '2026-04-29'
GROUP BY CAST(cross_ref_created_ts AS DATE)
ORDER BY created_date;
