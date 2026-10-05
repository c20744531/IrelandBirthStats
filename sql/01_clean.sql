-- 01_clean.sql
-- Cleans the raw CSO baby names tables (VSA50 boys, VSA60 girls).
-- The raw tables are loaded as-is by analysis.py into raw_boys and raw_girls.

DROP TABLE IF EXISTS names;
DROP VIEW IF EXISTS names_merged;

-- 1. One tidy table: year, sex, name, babies.
--    Each raw table has two statistics per name (a count and a rank); keep
--    the count only, and drop the blank rows CSO uses for "fewer than 3".
CREATE TABLE names AS
SELECT CAST(year AS INTEGER)           AS year,
       'boys'                          AS sex,
       TRIM(name)                      AS name,
       CAST(CAST(value AS REAL) AS INTEGER) AS babies
FROM raw_boys
WHERE statistic_label NOT LIKE '%Rank'
  AND unit = 'Number'
  AND TRIM(value) <> ''
UNION ALL
SELECT CAST(year AS INTEGER),
       'girls',
       TRIM(name),
       CAST(CAST(value AS REAL) AS INTEGER)
FROM raw_girls
WHERE statistic_label NOT LIKE '%Rank'
  AND unit = 'Number'
  AND TRIM(value) <> '';

CREATE INDEX idx_names ON names (sex, year, name);

-- 2. The CSO data only records fadas from 2018, so "Seán" before then is
--    stored as "Sean". For comparisons across years, fold every spelling to
--    an unaccented key so Rían and Rian count as one name.
CREATE VIEW names_merged AS
SELECT year,
       sex,
       REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
       REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(name,
         'á','a'),'é','e'),'í','i'),'ó','o'),'ú','u'),
         'Á','A'),'É','E'),'Í','I'),'Ó','O'),'Ú','U') AS name_key,
       name,
       babies
FROM names;
