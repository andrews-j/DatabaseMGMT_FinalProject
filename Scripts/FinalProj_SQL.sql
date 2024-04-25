-- Once you have imported rasters and vectors into your SQL database:
-- Rasters need to be converted to vectors, for [easier] analysis in SQL

-- This command does one at a time
CREATE	TABLE ndvi_2007_points AS
SELECT	CAST((ST_PixelAsPoints(rast)).val AS DECIMAL) AS float_val, 
		(ST_PixelAsPoints(rast)).*
FROM	ndbi_2007;

-- Better yet, use this nifty script to iterate through every file that begins with either ndvi, ndbi, or uvi and run the transformation on them
-- Filename will be {filename}_points
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
-- Even as vector points, this data can behave very strangely in pgAdmin, it is hard to visualize/confirm you have valid values
-- Run this command on one of the _points tables to verify. 
-- If in pgAdmin scrolling down will load more points
SELECT	*
FROM	ndbi_2007_points
WHERE	NULLIF(val, 'NaN') IS NOT NULL;


-- Creating HDI index
-- First, we need to standardize tract values/column names, and data types

-- Alter 'tract' column to NUMERIC data type
ALTER TABLE woo_poverty_2020
ALTER COLUMN tract TYPE NUMERIC
USING tract::NUMERIC;

-- Alter 'tract' column to NUMERIC data type
ALTER TABLE woo_education_2020
ALTER COLUMN tract TYPE NUMERIC
USING tract::NUMERIC;

-- Also make sure that le_tract 'tract' column is numeric
ALTER TABLE le_tracts
ALTER COLUMN tract TYPE NUMERIC
USING tract::NUMERIC;

-- View 5 entries from this column:
SELECT tract
FROM le_tracts
LIMIT 5;

-- ALso, the life expectancy column in le_tracts has a space in it. That's not cool. Lets fix that.
-- Change the name of the column from 'life expec' to 'LifeExp'
ALTER TABLE le_tracts
RENAME COLUMN "life expec" TO life_exp;

--Combine the relevant columns to a new table:
CREATE TABLE hdi_calc AS
SELECT
    l.tract,
    l.life_exp,
    p.perpov,
    e.perbach,
    l.geom
FROM
    le_tracts l
JOIN
    woo_poverty_2020 p ON l.tract = p.tract
JOIN
    woo_education_2020 e ON l.tract = e.tract;


-- This section creates columns containing normalized 0-1 values for each metric
SELECT 
    MIN(life_exp) AS min_life_exp,
    MAX(life_exp) AS max_life_exp,
    MIN(perpov) AS min_perpov,
    MAX(perpov) AS max_perpov,
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
    pov_norm = (perpov - (SELECT min_perpov FROM min_max_values)) / 
                        ((SELECT max_perpov FROM min_max_values) - (SELECT min_perpov FROM min_max_values)),
    ed_norm = (perbach - (SELECT min_perbach FROM min_max_values)) / 
                         ((SELECT max_perbach FROM min_max_values) - (SELECT min_perbach FROM min_max_values));

-- Ckeck out our table with normalized values
SELECT
    tract,
    life_exp,
    perpov,
    perbach,
    pov_norm,
    ed_norm,
    le_norm
FROM
    hdi_calc
LIMIT 5;


-- Poverty is a bad thing so we need to reverse that index:

-- Update the hdi_calc table with reversed normalized poverty rates:
UPDATE hdi_calc AS h
SET 
    pov_norm = 1 - ((h.perpov - (SELECT min_perpov FROM min_max_values)) / 
                        NULLIF((SELECT max_perpov FROM min_max_values) - (SELECT min_perpov FROM min_max_values), 0));


ALTER TABLE hdi_calc
ADD COLUMN hdi NUMERIC;

UPDATE hdi_calc
SET hdi = (pov_norm + ed_norm + le_norm) / 3;

-- Check it out:
SELECT
    tract,
    life_exp,
    perpov,
    perbach,
    pov_norm,
    ed_norm,
    le_norm,
    per_canopy,
    hdi
FROM
    hdi_calc
LIMIT 5;


-- Now we bring in Canopy data
-- Adapted from Charlotte group project script
-- Get canopy area by tract in meters2
CREATE TABLE canopy_cover_by_tract AS
SELECT
    h.tract,
    SUM(ST_Area(ST_Intersection(h.geom, canopy.geom))) AS total_canopy_area
FROM
    hdi_calc h
LEFT JOIN
    canopy_2015 canopy ON ST_Intersects(h.geom, canopy.geom)
GROUP BY
    h.tract;

-- Nice. Check out a preview:
SELECT tract, total_canopy_area
FROM canopy_cover_by_tract
LIMIT 5;

-- Create tract_area column in our new table with on the fly area calculation from hdi_calc 'geom'
UPDATE canopy_cover_by_tract AS c
SET tract_area = h.area_sqm
FROM (
    SELECT 
        tract,
        ST_Area(geom) AS area_sqm
    FROM 
        hdi_calc
) AS h
WHERE c.tract = h.tract;

SELECT tract, total_canopy_area, tract_area
FROM canopy_cover_by_tract
LIMIT 5;

-- Add a per_canopy column to the canopy_cover_by_tract table
ALTER TABLE canopy_cover_by_tract
ADD COLUMN per_canopy NUMERIC;

-- Update the per_canopy column with the calculated percent canopy cover
UPDATE canopy_cover_by_tract
SET per_canopy = (total_canopy_area / tract_area) * 100;

SELECT tract, total_canopy_area, tract_area, per_canopy
FROM canopy_cover_by_tract
LIMIT 5;

SELECT
    tract,
    life_exp,
    perpov,
    perbach,
    pov_norm,
    ed_norm,
    le_norm,
    per_canopy
FROM
    hdi_calc
LIMIT 5;

-- normalize per_canopy:
-- Calculate the minimum and maximum values of per_canopy
SELECT
    MIN(per_canopy) AS min_per_canopy,
    MAX(per_canopy) AS max_per_canopy
INTO
    min_max_per_canopy
FROM
    canopy_cover_by_tract;

ALTER TABLE hdi_calc
ADD COLUMN per_canopy_norm NUMERIC;


-- Update hdi_calc with normalized per_canopy values
UPDATE
    hdi_calc
SET
    per_canopy_norm = (per_canopy - (SELECT min_per_canopy FROM min_max_per_canopy)) /
                      ((SELECT max_per_canopy FROM min_max_per_canopy) - (SELECT min_per_canopy FROM min_max_per_canopy));

ALTER TABLE hdi_calc
ADD COLUMN h_tree_i NUMERIC;

UPDATE hdi_calc
SET h_tree_i = (pov_norm + ed_norm + le_norm+per_canopy_norm) / 4;

SELECT
    tract,
    pov_norm,
    ed_norm,
    le_norm,
    per_canopy,
    hdi,
    per_canopy_norm,
    h_tree_i
FROM
    hdi_calc
LIMIT 5;

ALTER TABLE hdi_calc
ADD COLUMN hdi_diff NUMERIC;

UPDATE hdi_calc
SET hdi_diff = (h_tree_i - hdi);

hti['hdi_diff'] = hti[''] - hti['hdi']