-- 04_locations.sql
-- Where do delays happen? Lines and stations.
-- Stations come from the station_dim table (cleaned names only), lines from the
-- cleaned `line` column.

-- Q1: the four lines compared (full years only)
SELECT
    line,
    COUNT(*)                                          AS incidents,
    SUM(min_delay)                                    AS delay_minutes,
    ROUND(1.0 * SUM(min_delay) / SUM(caused_delay), 2) AS avg_minutes_per_delay,
    ROUND(100.0 * SUM(min_delay) / SUM(SUM(min_delay)) OVER (), 1) AS pct_of_all_minutes
FROM delays
WHERE year BETWEEN 2019 AND 2025
GROUP BY line
ORDER BY delay_minutes DESC;

-- Q2: top 15 stations by total delay minutes, with a running share (Pareto style)
WITH station_totals AS (
    SELECT d.station, COUNT(*) AS incidents, SUM(d.min_delay) AS delay_minutes
    FROM delays d
    JOIN station_dim s ON s.station = d.station
    WHERE d.year BETWEEN 2019 AND 2025
    GROUP BY d.station
)
SELECT
    station,
    incidents,
    delay_minutes,
    ROUND(100.0 * delay_minutes / SUM(delay_minutes) OVER (), 1) AS pct_of_station_minutes,
    ROUND(100.0 * SUM(delay_minutes) OVER (ORDER BY delay_minutes DESC)
          / SUM(delay_minutes) OVER (), 1)                     AS running_pct
FROM station_totals
ORDER BY delay_minutes DESC
LIMIT 15;

-- Q3: how concentrated is it? share of minutes held by the worst 10 stations
WITH station_totals AS (
    SELECT d.station, SUM(d.min_delay) AS delay_minutes
    FROM delays d
    JOIN station_dim s ON s.station = d.station
    WHERE d.year BETWEEN 2019 AND 2025
    GROUP BY d.station
),
ranked AS (
    SELECT station, delay_minutes,
           ROW_NUMBER() OVER (ORDER BY delay_minutes DESC) AS rnk,
           COUNT(*) OVER ()                                AS station_count
    FROM station_totals
)
SELECT
    MAX(station_count)                                    AS stations,
    ROUND(100.0 * SUM(CASE WHEN rnk <= 10 THEN delay_minutes END)
          / SUM(delay_minutes), 1)                        AS pct_minutes_top_10_stations
FROM ranked;

-- Q4: worst 3 stations in every year
WITH yearly AS (
    SELECT d.year, d.station, SUM(d.min_delay) AS delay_minutes
    FROM delays d
    JOIN station_dim s ON s.station = d.station
    GROUP BY d.year, d.station
),
ranked AS (
    SELECT year, station, delay_minutes,
           ROW_NUMBER() OVER (PARTITION BY year ORDER BY delay_minutes DESC) AS rnk
    FROM yearly
)
SELECT year, rnk AS rank, station, delay_minutes
FROM ranked
WHERE rnk <= 3
ORDER BY year, rnk;

-- Q5: stations that got worse or better, 2019 vs 2025 (minutes per year)
WITH yearly AS (
    SELECT d.station,
           SUM(CASE WHEN d.year = 2019 THEN d.min_delay ELSE 0 END) AS min_2019,
           SUM(CASE WHEN d.year = 2025 THEN d.min_delay ELSE 0 END) AS min_2025
    FROM delays d
    JOIN station_dim s ON s.station = d.station
    GROUP BY d.station
)
SELECT
    station,
    min_2019,
    min_2025,
    min_2025 - min_2019                                  AS change_minutes,
    ROUND(100.0 * (min_2025 - min_2019) / min_2019, 0)   AS change_pct
FROM yearly
WHERE min_2019 >= 300           -- skip stations with too little history to compare
  AND min_2025 > 0              -- the Scarborough RT stations closed in 2023, that's not "improving"
ORDER BY change_minutes DESC
LIMIT 10;

-- Q6: ...and the ones that improved the most
WITH yearly AS (
    SELECT d.station,
           SUM(CASE WHEN d.year = 2019 THEN d.min_delay ELSE 0 END) AS min_2019,
           SUM(CASE WHEN d.year = 2025 THEN d.min_delay ELSE 0 END) AS min_2025
    FROM delays d
    JOIN station_dim s ON s.station = d.station
    GROUP BY d.station
)
SELECT
    station,
    min_2019,
    min_2025,
    min_2025 - min_2019                                  AS change_minutes,
    ROUND(100.0 * (min_2025 - min_2019) / min_2019, 0)   AS change_pct
FROM yearly
WHERE min_2019 >= 300
  AND min_2025 > 0
ORDER BY change_minutes ASC
LIMIT 10;
