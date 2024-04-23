-- Once you have imported rasters and vectors into your SQL database:
-- Rasters need to be converted to vectors, for [easier] analysis in SQL

-- This command does one at a time
CREATE	TABLE ndvi_2007_points AS
SELECT	CAST((ST_PixelAsPoints(rast)).val AS DECIMAL) AS float_val, 
		(ST_PixelAsPoints(rast)).*
FROM	ndbi_2007;


-- Use this nifty script to iterate through every file that begins with either ndvi, ndbi, or uvi and run the transformation on them
-- File name will be {filename}_points
DO $$
DECLARE
    raster_table_name TEXT;
    vector_table_name TEXT;
BEGIN
    FOR raster_table_name IN SELECT table_name FROM information_schema.tables WHERE table_name LIKE 'ndvi_%' OR table_name LIKE 'ndbi_%' OR table_name LIKE 'uvi_%' LOOP
        vector_table_name := raster_table_name || '_points';
        EXECUTE FORMAT('CREATE TABLE %I AS 
                        SELECT CAST((ST_PixelAsPoints(rast)).val AS DECIMAL) AS float_val, 
                               (ST_PixelAsPoints(rast)).*
                        FROM %I;', vector_table_name, raster_table_name);
    END LOOP;
END $$;


-- Important:
-- Even converted to vector, these files can behave very strangely in pgAdmin, or however the table is being viewed.
-- Run this command on one of the _points table to verify. 
-- If in pgAdmin scrolling down will load more points
SELECT	*
FROM	ndbi_2007_points
WHERE	NULLIF(val, 'NaN') IS NOT NULL;


-- Next, we need to standardize tract values
ALTER TABLE public.woo_poverty_2020
RENAME COLUMN "name" TO "tract";

-- Remove the string and space to the left of the number
UPDATE woo_poverty_2020
SET tract = REGEXP_REPLACE(tract, '[^0-9.]+', '', 'g');

-- Add .0 to numbers that don't have a decimal
UPDATE woo_poverty_2020
SET tract = tract || '.0'
WHERE tract !~ '[.]';

ALTER TABLE woo_poverty_2020
ALTER COLUMN tract TYPE NUMERIC;

-- Alter 'tract' column to NUMERIC data type
ALTER TABLE woo_poverty_2020
ALTER COLUMN tract TYPE NUMERIC
USING tract::NUMERIC;

-- View 5 entries from this column:
SELECT tract
FROM woo_poverty_2020
LIMIT 5;

-- And do the same for woo_education_2020
ALTER TABLE public.woo_education_2020
RENAME COLUMN "name" TO "tract";

-- Remove the string and space to the left of the number
UPDATE woo_education_2020
SET tract = REGEXP_REPLACE(tract, '[^0-9.]+', '', 'g');

-- Alter 'tract' column to NUMERIC data type
ALTER TABLE woo_education_2020
ALTER COLUMN tract TYPE NUMERIC
USING tract::NUMERIC;

-- Add .0 to numbers that don't have a decimal
UPDATE woo_education_2020
SET tract = tract || '.0'
WHERE tract !~ '[.]';

-- Also make sure that le_tract 'tract' column is numeric
ALTER TABLE le_tracts
ALTER COLUMN tract TYPE NUMERIC
USING tract::NUMERIC;

-- ALso, the life expectancy column in le_tracts has a space in it. that's not cool. Lets fix that
-- Change the name of the column from 'life expec' to 'LifeExp'
ALTER TABLE le_tracts
RENAME COLUMN "life expec" TO life_exp;


-- And combine the relevant columns to a new table:
CREATE TABLE hdi_calc AS
SELECT
    l.tract,
    l.life_exp,
    p.povper,
    e.perbach,
    l.geom
FROM
    le_tracts l
JOIN
    woo_poverty_2020 p ON l.tract = p.tract
JOIN
    woo_education_2020 e ON l.tract = e.tract;


SELECT 
    MIN(life_exp) AS min_life_exp,
    MAX(life_exp) AS max_life_exp,
    MIN(povper) AS min_povper,
    MAX(povper) AS max_povper,
    MIN(perbach) AS min_perbach,
    MAX(perbach) AS max_perbach
INTO 
    min_max_values
FROM 
    hdi_calc;

ALTER TABLE hdi_calc
ADD COLUMN pov_norm NUMERIC,
ADD COLUMN ed_norm NUMERIC,
ADD COLUMN le_norm NUMERIC;

UPDATE hdi_calc
SET 
    le_norm = (life_exp - (SELECT min_life_exp FROM min_max_values)) / 
                          ((SELECT max_life_exp FROM min_max_values) - (SELECT min_life_exp FROM min_max_values)),
    pov_norm = (povper - (SELECT min_povper FROM min_max_values)) / 
                        ((SELECT max_povper FROM min_max_values) - (SELECT min_povper FROM min_max_values)),
    ed_norm = (perbach - (SELECT min_perbach FROM min_max_values)) / 
                         ((SELECT max_perbach FROM min_max_values) - (SELECT min_perbach FROM min_max_values));

-- Ckeck out our table with normalized values
SELECT hdi_calc.*, 
       except geom
FROM hdi_calc
LIMIT 5;
