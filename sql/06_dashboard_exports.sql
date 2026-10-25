-- 06_dashboard_exports.sql
-- The result sets behind the dashboard. src/export_dashboard.py runs each query
-- (the "-- name:" line gives the key it is saved under) and writes docs/data.js.

-- name: kpis
SELECT
    COUNT(*)                                            AS incidents,
    SUM(caused_delay)                                   AS delayed_incidents,
    ROUND(SUM(min_delay) / 60.0, 0)                     AS delay_hours,
    ROUND(1.0 * SUM(min_delay) / SUM(caused_delay), 1)  AS avg_minutes_per_delay,
    MIN(delay_date)                                     AS first_date,
    MAX(delay_date)                                     AS last_date
FROM delays;

-- name: yearly
SELECT
    year,
    COUNT(*)                         AS incidents,
    ROUND(SUM(min_delay) / 60.0, 0)  AS delay_hours,
    CASE WHEN year = 2026 THEN 1 ELSE 0 END AS partial_year
FROM delays
GROUP BY year
ORDER BY year;

-- name: hourly
SELECT
    hour,
    ROUND(SUM(min_delay) / 60.0, 0)  AS delay_hours,
    COUNT(*)                         AS incidents
FROM delays
WHERE year BETWEEN 2019 AND 2025
GROUP BY hour
ORDER BY hour;

-- name: monthly
WITH daily AS (
    SELECT delay_date, month, SUM(min_delay) AS minutes
    FROM delays
    WHERE year BETWEEN 2019 AND 2025
    GROUP BY delay_date, month
)
SELECT month, ROUND(AVG(minutes), 1) AS avg_delay_minutes_per_day
FROM daily
GROUP BY month
ORDER BY month;

-- name: weekday_hour
WITH days AS (
    SELECT weekday, COUNT(DISTINCT delay_date) AS n_days
    FROM delays
    WHERE year BETWEEN 2019 AND 2025
    GROUP BY weekday
)
SELECT
    d.weekday,
    d.hour,
    -- incidents per day rather than minutes: a handful of storm days
    -- (ice, snow) inflate the minutes average and hide the normal pattern
    ROUND(1.0 * COUNT(*) / days.n_days, 2) AS avg_incidents
FROM delays d
JOIN days ON days.weekday = d.weekday
WHERE d.year BETWEEN 2019 AND 2025
GROUP BY d.weekday, d.hour;

-- name: top_stations
SELECT
    d.station,
    ROUND(SUM(d.min_delay) / 60.0, 0) AS delay_hours,
    COUNT(*)                          AS incidents
FROM delays d
JOIN station_dim s ON s.station = d.station
WHERE d.year BETWEEN 2019 AND 2025
GROUP BY d.station
ORDER BY SUM(d.min_delay) DESC
LIMIT 15;

-- name: lines
SELECT
    line,
    ROUND(SUM(min_delay) / 60.0, 0)                    AS delay_hours,
    COUNT(*)                                           AS incidents,
    ROUND(1.0 * SUM(min_delay) / SUM(caused_delay), 1) AS avg_minutes_per_delay
FROM delays
WHERE year BETWEEN 2019 AND 2025
  AND line IN ('Line 1 Yonge-University', 'Line 2 Bloor-Danforth',
               'Line 3 Scarborough RT', 'Line 4 Sheppard')
GROUP BY line
ORDER BY SUM(min_delay) DESC;

-- name: causes_by_year
SELECT
    year,
    category,
    ROUND(SUM(min_delay) / 60.0, 0) AS delay_hours
FROM delays
WHERE year BETWEEN 2019 AND 2025
  AND category <> 'Other'
GROUP BY year, category
ORDER BY year, category;

-- name: top_causes
SELECT
    code_description AS cause,
    ROUND(SUM(min_delay) / 60.0, 0) AS delay_hours,
    COUNT(*)                        AS incidents
FROM delays
WHERE year BETWEEN 2019 AND 2025
GROUP BY code, code_description
ORDER BY SUM(min_delay) DESC
LIMIT 10;
