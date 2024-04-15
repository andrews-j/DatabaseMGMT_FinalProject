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