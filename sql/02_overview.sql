-- 02_overview.sql
-- Big picture: how many delays are there and how is that changing over time?
-- Note: 2026 only runs through the end of August, so full-year comparisons stop at 2025.

-- Q1: headline numbers
SELECT
    COUNT(*)                                   AS incidents_logged,
    SUM(caused_delay)                          AS incidents_with_delay,
    SUM(min_delay)                             AS total_delay_minutes,
    ROUND(SUM(min_delay) / 60.0, 0)            AS total_delay_hours,
    ROUND(1.0 * SUM(min_delay) / SUM(caused_delay), 2) AS avg_minutes_per_delay,
    MIN(delay_date)                            AS first_date,
    MAX(delay_date)                            AS last_date
FROM delays;

-- Q2: incidents and delay minutes per year
SELECT
    year,
    COUNT(*)                                   AS incidents_logged,
    SUM(caused_delay)                          AS incidents_with_delay,
    SUM(min_delay)                             AS delay_minutes,
    ROUND(1.0 * SUM(min_delay) / SUM(caused_delay), 2) AS avg_minutes_per_delay
FROM delays
GROUP BY year
ORDER BY year;

-- Q3: year over year change (full years only), using LAG
WITH yearly AS (
    SELECT year, COUNT(*) AS incidents, SUM(min_delay) AS delay_minutes
    FROM delays
    WHERE year <= 2025
    GROUP BY year
)
SELECT
    year,
    incidents,
    delay_minutes,
    ROUND(100.0 * (incidents - LAG(incidents) OVER (ORDER BY year))
          / LAG(incidents) OVER (ORDER BY year), 1)           AS incidents_change_pct,
    ROUND(100.0 * (delay_minutes - LAG(delay_minutes) OVER (ORDER BY year))
          / LAG(delay_minutes) OVER (ORDER BY year), 1)       AS minutes_change_pct
FROM yearly
ORDER BY year;

-- Q4: how much of the logged data is "zero minute" incidents?
SELECT
    year,
    ROUND(100.0 * SUM(1 - caused_delay) / COUNT(*), 1) AS pct_zero_minute_incidents
FROM delays
GROUP BY year
ORDER BY year;
