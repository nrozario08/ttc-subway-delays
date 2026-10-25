-- 03_timing.sql
-- When do delays happen? Hour of day, day of week and season.
-- Everything below uses full years 2019-2025 so seasons are not skewed by the
-- partial 2026 data.

-- Q1: delays by hour of day
SELECT
    hour,
    COUNT(*)                          AS incidents,
    SUM(min_delay)                    AS delay_minutes,
    ROUND(100.0 * SUM(min_delay) / SUM(SUM(min_delay)) OVER (), 1) AS pct_of_all_minutes
FROM delays
WHERE year BETWEEN 2019 AND 2025
GROUP BY hour
ORDER BY hour;

-- Q2: rush hour vs the rest of the day
SELECT
    CASE
        WHEN hour BETWEEN 6 AND 9   THEN 'AM rush (6-9)'
        WHEN hour BETWEEN 15 AND 18 THEN 'PM rush (15-18)'
        WHEN hour BETWEEN 10 AND 14 THEN 'Midday (10-14)'
        WHEN hour BETWEEN 19 AND 23 THEN 'Evening (19-23)'
        ELSE 'Overnight (0-5)'
    END                                              AS period,
    COUNT(*)                                         AS incidents,
    SUM(min_delay)                                   AS delay_minutes,
    ROUND(1.0 * SUM(min_delay) / SUM(caused_delay), 2) AS avg_minutes_per_delay
FROM delays
WHERE year BETWEEN 2019 AND 2025
GROUP BY period
ORDER BY delay_minutes DESC;

-- Q3: weekday vs weekend, per day so the 5 vs 2 day split doesn't mislead
WITH daily AS (
    SELECT delay_date, is_weekend, COUNT(*) AS incidents, SUM(min_delay) AS minutes
    FROM delays
    WHERE year BETWEEN 2019 AND 2025
    GROUP BY delay_date, is_weekend
)
SELECT
    CASE is_weekend WHEN 1 THEN 'Weekend' ELSE 'Weekday' END AS day_type,
    COUNT(*)                          AS days,
    ROUND(AVG(incidents), 1)          AS avg_incidents_per_day,
    ROUND(AVG(minutes), 1)            AS avg_delay_minutes_per_day
FROM daily
GROUP BY is_weekend;

-- Q4: day of week
WITH daily AS (
    SELECT delay_date, weekday, COUNT(*) AS incidents, SUM(min_delay) AS minutes
    FROM delays
    WHERE year BETWEEN 2019 AND 2025
    GROUP BY delay_date, weekday
)
SELECT
    weekday,
    ROUND(AVG(incidents), 1)  AS avg_incidents_per_day,
    ROUND(AVG(minutes), 1)    AS avg_delay_minutes_per_day
FROM daily
GROUP BY weekday
ORDER BY avg_delay_minutes_per_day DESC;

-- Q5: month of the year (average per day so shorter months aren't penalised)
WITH daily AS (
    SELECT delay_date, month, SUM(min_delay) AS minutes, COUNT(*) AS incidents
    FROM delays
    WHERE year BETWEEN 2019 AND 2025
    GROUP BY delay_date, month
)
SELECT
    month,
    ROUND(AVG(incidents), 1) AS avg_incidents_per_day,
    ROUND(AVG(minutes), 1)   AS avg_delay_minutes_per_day
FROM daily
GROUP BY month
ORDER BY month;

-- Q6: busiest hour on weekdays vs weekends, ranked with a window function
WITH by_hour AS (
    SELECT is_weekend, hour, SUM(min_delay) AS minutes
    FROM delays
    WHERE year BETWEEN 2019 AND 2025
    GROUP BY is_weekend, hour
),
ranked AS (
    SELECT
        is_weekend, hour, minutes,
        RANK() OVER (PARTITION BY is_weekend ORDER BY minutes DESC) AS rnk
    FROM by_hour
)
SELECT
    CASE is_weekend WHEN 1 THEN 'Weekend' ELSE 'Weekday' END AS day_type,
    rnk AS rank,
    hour,
    minutes
FROM ranked
WHERE rnk <= 3
ORDER BY is_weekend, rnk;
