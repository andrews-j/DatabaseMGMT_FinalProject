# We are using UTM 19N, or 32619 for this project

## Import Vectors:
# Navigate to Shapefiles folder
# And pipe a vector into a .sql command file
shp2pgsql -s 32619 -I census2010.shp public.census2010 > vectorImport.sql

shp2pgsql -s 32619 -I LE_tracts.shp public.le_tracts > vectorImport.sql


# Then call that command
psql -d finalProj -U postgres -p 5433 -f vectorImport.sql

# Batch version:
for shapefile in ./*.shp; do
    
    filename=$(basename "$shapefile" .shp)
    
    shp2pgsql -s 32619 -I "$shapefile" "$schema_name.$filename" >> vectorImport.sql
done


# Then call that command the same way, it will import all vectors in the folder where it ran

# Import Rasters:
# Navigate to Images folder
# Create .sql raster import command
raster2pgsql -s 32619 -I -C -M NDVI_2007.tif  public.NDVI_2007 > rasterImport.sql

# Call that command
psql -d finalProj -U postgres -p 5433 -f raster_import.sql

# or pipe it all at once, without creating a .sql script
raster2pgsql -s 32619 -I test.tiff public.test | psql -U postgres -p5433 -d finalProj

# Even better, create a script to import all the .tif files in your folder in one fell swoop
for raster in ./*.tif; do
    
    filename=$(basename "$raster" .tif)
    
    raster2pgsql -s 32619 -I -C -M "$raster" "$schema_name.$filename" >> rasterImport.sql
done


# Enter SQL shell:
psql -d finalProj -U postgres -p 5433
