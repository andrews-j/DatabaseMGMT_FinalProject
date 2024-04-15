
-- Navigate to Images folder
-- Create .sql raster import command
raster2pgsql -s 32619 -I -C -M NDVI_2007.tif  public.NDVI_2007 > rasterImport.sql

raster2pgsql -s 4326 -I -C -M NDBI_2007_4326.tif  public.NDVI_2007_4326 > rasterImport.sql


-- Call that command
psql -d finalProj -U postgres -p 5433 -f raster_import.sql

-- or try it all at once
raster2pgsql -s 32619 -I test.tiff public.test | psql -U postgres -p5433 -d finalProj

for raster in ./*.tif; do
    
    filename=$(basename "$raster" .tif)
    
    raster2pgsql -s 32619 -I -C -M "$raster" "$schema_name.$filename" >> rasterImport.sql
done



-- For vectors, go to shapefiles folder
-- We are using UTM 19N, or 32619 for this project
shp2pgsql -s 32619 -I census2010Selected.shp public.census2010 > vectorImport.sql


psql -d finalProj -U postgres -p 5433 -f vectorImport.sql

-- Alternatively, run this to import all the shapefiles in a folder at once:

for shapefile in ./*.shp; do
    
    filename=$(basename "$shapefile" .shp)
    
    shp2pgsql -s 32619 -I "$shapefile" "$schema_name.$filename" >> vectorImport.sql
done
*/



-- Once you have a .tif:
-- convert it to a vector, for easier analysis in SQL
CREATE	TABLE ndvi_2007_points AS
SELECT	CAST((ST_PixelAsPoints(rast)).val AS DECIMAL) AS float_val, 
		(ST_PixelAsPoints(rast)).*
FROM	ndbi_2007;


-- Use this nifty script to iterate through every file that begins with either ndvi, ndbi, or uvi and run the transformation on them
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
