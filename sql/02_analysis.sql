-- 02_analysis.sql
-- Analysis queries. Each one starts with a "-- name:" line so analysis.py
-- can run them one by one. :sex, :last and :decade_ago are parameters.

-- name: years
SELECT MIN(year) AS first_year, MAX(year) AS last_year
FROM names
WHERE sex = :sex;

-- name: top10
-- Official ranking for the latest year: every spelling is its own name.
SELECT name, babies,
       RANK() OVER (ORDER BY babies DESC) AS rank
FROM names
WHERE sex = :sex AND year = :last
ORDER BY babies DESC, name
LIMIT 10;

-- name: number_ones
-- The most popular name in every year.
SELECT year, name, babies
FROM (
  SELECT year, name, babies,
         ROW_NUMBER() OVER (PARTITION BY year ORDER BY babies DESC, name) AS rn
  FROM names
  WHERE sex = :sex
)
WHERE rn = 1
ORDER BY year;

-- name: moves
-- Change over the last decade, with spellings merged. Only names that had
-- at least 100 babies in either year, so tiny names don't dominate.
WITH merged AS (
  SELECT name_key, year, SUM(babies) AS babies
  FROM names_merged
  WHERE sex = :sex AND year IN (:decade_ago, :last)
  GROUP BY name_key, year
),
label AS (
  -- show the most common spelling since fadas were recorded
  SELECT name_key, name
  FROM (
    SELECT name_key, name,
           ROW_NUMBER() OVER (PARTITION BY name_key ORDER BY SUM(babies) DESC) AS rn
    FROM names_merged
    WHERE sex = :sex AND year >= 2018
    GROUP BY name_key, name
  )
  WHERE rn = 1
)
SELECT COALESCE(l.name, m.name_key) AS name,
       SUM(CASE WHEN m.year = :decade_ago THEN m.babies ELSE 0 END) AS then_babies,
       SUM(CASE WHEN m.year = :last THEN m.babies ELSE 0 END)       AS now_babies
FROM merged m
LEFT JOIN label l USING (name_key)
GROUP BY m.name_key
HAVING MAX(then_babies, now_babies) >= 100;

-- name: diversity
-- Names in use, top-10 concentration and fada share, per year.
WITH ranked AS (
  SELECT year, name, babies,
         ROW_NUMBER() OVER (PARTITION BY year ORDER BY babies DESC, name) AS rn
  FROM names
  WHERE sex = :sex
)
SELECT year,
       COUNT(*)                                                    AS names,
       SUM(babies)                                                 AS babies,
       ROUND(100.0 * SUM(CASE WHEN rn <= 10 THEN babies END) / SUM(babies), 1) AS top10_share,
       CASE WHEN year >= 2018 THEN ROUND(100.0 * SUM(CASE
         WHEN name GLOB '*[áéíóúÁÉÍÓÚ]*' THEN babies ELSE 0 END) / SUM(babies), 1)
       END                                                         AS fada_share
FROM ranked
GROUP BY year
ORDER BY year;

-- name: trend
-- Babies per year for one name, spellings merged.
SELECT y.year, COALESCE(SUM(n.babies), 0) AS babies
FROM (SELECT DISTINCT year FROM names WHERE sex = :sex) y
LEFT JOIN names_merged n
  ON n.year = y.year AND n.sex = :sex AND n.name_key = :name_key
GROUP BY y.year
ORDER BY y.year;
