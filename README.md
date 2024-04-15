# IDCE-376 FinalProject: Green Space and Demographics in Worcester, MA

### Jason Andrews, Clark University MSGIS, 2024
### IDCE 376, Spatial Database Management, Spring 2024
### Professor Jonathan Ocon and TA Kunal Malhan

This repository contains submissions pertaining to final project work for IDCE 376.

The assignment description can be viewed in the *Final_Project-Rubric.pdf* document.

For more information on how data was obtained, please see DataSources.md

## Part 1: Importing and Processing Data

This study will examine the relationship between urban greenery/canopy cover and certain economic and social measures in Worcester, Massachussets. 

#### Vector layers

The study area is the city limits of Worcester, and the spatial scale of the analysis will be the 44 census districts in Worcester, as visualized below:

![Screenshot 2024-04-14 at 9 27 33 PM](https://github.com/andrews-j/IDCE-376_FinalProject/assets/26927475/5a63beb5-057f-4372-af2c-cbc16d154f6a)

Census layers from 2010 and 2020, with information about total population, and racial composition of each census tract. This is a subset of the 2010 census data:

![Screenshot 2024-04-14 at 9 30 35 PM](https://github.com/andrews-j/IDCE-376_FinalProject/assets/26927475/7008a268-850c-4f0c-860a-d656f19596c2)

Two different layers containing information about nearly 10,000 trees planted in Worcester County in 2010-2012 through a Massachussets Department of Conservation and Recreation (MA DCR) tree planting program.

![Screenshot 2024-04-14 at 9 35 29 PM](https://github.com/andrews-j/IDCE-376_FinalProject/assets/26927475/f1710f8f-d12c-4d8e-834c-b92846e08c8e)

Worcester canopy cover vector layers from 2008, 2010, and 2015.

Canopy cover 2010 detail:

<img width="609" alt="Screenshot 2024-04-15 at 1 38 04 PM" src="https://github.com/andrews-j/IDCE-376_FinalProject/assets/26927475/a1878029-529c-48d9-a247-01cd1bda83af">


#### Raster Layers

Raster images include NDBI (Normalized Differenced Built Index), NDVI (Normalized Differenced Vegetation Index), and UVI (Urban Vegetation Index) from 5 different time points: 2007, 2011, 2015, 2019, and 2023, clipped to Worcester city limits. 

Raster images were aquired with PySTAC. Each is a median composite image between March 15 and September 15 of the chosen year. See GetWorcesterImages.ipynb.

All data is kept in, or reprojected to EPSG 32619 WGS 84/ UTM Zone 19N.

Examples:

**NDBI 2007**

![Screenshot 2024-04-14 at 9 42 27 PM](https://github.com/andrews-j/IDCE-376_FinalProject/assets/26927475/45c41895-83cd-4436-9c0f-aa02297040d5)

**NDVI 2015**

![Screenshot 2024-04-14 at 9 44 33 PM](https://github.com/andrews-j/IDCE-376_FinalProject/assets/26927475/c88b0a3a-00e9-4f8e-8cdc-a72ef3384706)

**UVI 2023**

![Screenshot 2024-04-14 at 9 45 19 PM](https://github.com/andrews-j/IDCE-376_FinalProject/assets/26927475/9b0eef3e-7da8-4072-a880-4ab88805d2b3)

#### Importing data to SQL

This is the script I used in CLI to batch import vector files into my database, which is called finalProj:

```bash

for shapefile in ./*.shp; do
    
    filename=$(basename "$shapefile" .shp)
    
    shp2pgsql -s 32619 -I "$shapefile" "$schema_name.$filename" >> vectorImport.sql
done

```


This is the script I used in CLI to batch import raster files into my database, which is called finalProj:

```bash

for raster in ./*.tif; do
    
    filename=$(basename "$raster" .tif)
    
    raster2pgsql -s 32619 -I -C -M "$raster" "$schema_name.$filename" >> rasterImport.sql
done

```

Once the rasters are added to the database they must be converted to vector. This is the SQL batch command used to convert all ndbi, ndvi, and uvi images in the database to points.
See finalProj_SQL.sql for more details.

```sql
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
```

The result, at this point, is that we have quite a lot of tables, 38 to be exact.
<img width="360" alt="Screenshot 2024-04-15 at 1 30 11 PM" src="https://github.com/andrews-j/IDCE-376_FinalProject/assets/26927475/7032f3a3-8734-4241-9992-31bc9049d365">



