-- 05_causes.sql
-- Why do delays happen? Uses the delay code (and the category I rolled it up to
-- in 01_clean.sql). Full years 2019-2025 only.

-- Q1: delay minutes by category
SELECT
    category,
    COUNT(*)                                           AS incidents,
    SUM(min_delay)                                     AS delay_minutes,
    ROUND(100.0 * SUM(min_delay) / SUM(SUM(min_delay)) OVER (), 1) AS pct_of_minutes,
    ROUND(1.0 * SUM(min_delay) / SUM(caused_delay), 2) AS avg_minutes_per_delay
FROM delays
WHERE year BETWEEN 2019 AND 2025
GROUP BY category
ORDER BY delay_minutes DESC;

-- Q2: top 12 individual causes
SELECT
    code,
    code_description,
    COUNT(*)           AS incidents,
    SUM(min_delay)     AS delay_minutes,
    ROUND(100.0 * SUM(min_delay) / SUM(SUM(min_delay)) OVER (), 1) AS pct_of_minutes
FROM delays
WHERE year BETWEEN 2019 AND 2025
GROUP BY code, code_description
ORDER BY delay_minutes DESC
LIMIT 12;

-- Q3: how many codes does it take to explain 80% of all delay minutes?
WITH code_totals AS (
    SELECT code, SUM(min_delay) AS minutes
    FROM delays
    WHERE year BETWEEN 2019 AND 2025
    GROUP BY code
),
running AS (
    SELECT
        code,
        minutes,
        SUM(minutes) OVER (ORDER BY minutes DESC, code) * 1.0
            / SUM(minutes) OVER ()                         AS cum_share,
        ROW_NUMBER() OVER (ORDER BY minutes DESC, code)    AS rnk
    FROM code_totals
)
SELECT
    (SELECT COUNT(*) FROM code_totals)                     AS distinct_codes,
    MIN(rnk)                                               AS codes_needed_for_80_pct
FROM running
WHERE cum_share >= 0.8;

-- Q4: the average delay by cause, only for causes seen at least 200 times
SELECT
    code_description,
    COUNT(*)                                           AS incidents,
    ROUND(1.0 * SUM(min_delay) / SUM(caused_delay), 1) AS avg_minutes_when_delayed
FROM delays
WHERE year BETWEEN 2019 AND 2025
GROUP BY code, code_description
HAVING COUNT(*) >= 200 AND SUM(caused_delay) > 0
ORDER BY avg_minutes_when_delayed DESC
LIMIT 10;

-- Q5: cause mix by line (share of each line's minutes)
SELECT
    line,
    category,
    SUM(min_delay) AS delay_minutes,
    ROUND(100.0 * SUM(min_delay) / SUM(SUM(min_delay)) OVER (PARTITION BY line), 1) AS pct_of_line
FROM delays
WHERE year BETWEEN 2019 AND 2025
  AND line IN ('Line 1 Yonge-University', 'Line 2 Bloor-Danforth', 'Line 4 Sheppard')
GROUP BY line, category
ORDER BY line, delay_minutes DESC;

-- Q6: how the cause mix shifted from year to year
SELECT
    year,
    category,
    SUM(min_delay) AS delay_minutes,
    ROUND(100.0 * SUM(min_delay) / SUM(SUM(min_delay)) OVER (PARTITION BY year), 1) AS pct_of_year
FROM delays
WHERE year BETWEEN 2019 AND 2025
GROUP BY year, category
ORDER BY year, delay_minutes DESC;

-- Q7: the 10 worst single days and what caused most of the damage
WITH day_totals AS (
    SELECT delay_date, SUM(min_delay) AS day_minutes, COUNT(*) AS incidents
    FROM delays
    GROUP BY delay_date
),
worst AS (
    SELECT * FROM day_totals ORDER BY day_minutes DESC LIMIT 10
),
by_code AS (
    SELECT
        d.delay_date, d.code_description,
        SUM(d.min_delay) AS code_minutes,
        ROW_NUMBER() OVER (PARTITION BY d.delay_date ORDER BY SUM(d.min_delay) DESC) AS rnk
    FROM delays d
    JOIN worst w ON w.delay_date = d.delay_date
    GROUP BY d.delay_date, d.code_description
)
SELECT
    w.delay_date,
    w.day_minutes,
    w.incidents,
    b.code_description AS biggest_cause,
    b.code_minutes     AS minutes_from_that_cause
FROM worst w
JOIN by_code b ON b.delay_date = w.delay_date AND b.rnk = 1
ORDER BY w.day_minutes DESC;
