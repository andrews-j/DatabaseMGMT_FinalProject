## IDCE-376_FinalProject

### Jason Andrews, Clark University MSGIS, 2024
### IDCE 376, Spatial Database Management, Spring 2024
### Professor Jonathan Ocon and TA Kunal Malhan

This repository contains submissions pertaining to final project work for IDCE 376.

The assignment description can be viewed in the *Final_Project-Rubric.pdf* document.

For more information on how data was obtained, please see DataSources.md

My study will examine the relationship between urban greenery different economic and social measures in Worcester, Massachussets. The study area is the city limits of Worcester, and the spatial scale of the analysis will be the 44 census districts in Worcester, as visualized below:

![Screenshot 2024-04-14 at 9 27 33 PM](https://github.com/andrews-j/IDCE-376_FinalProject/assets/26927475/5a63beb5-057f-4372-af2c-cbc16d154f6a)

I have census layers from 2010 and 20209, with information about total population, and racial composition of each census tract. Subset of 2010 census data:

![Screenshot 2024-04-14 at 9 30 35 PM](https://github.com/andrews-j/IDCE-376_FinalProject/assets/26927475/7008a268-850c-4f0c-860a-d656f19596c2)

I also have two different layers containing information about nearly 10,000 trees planted in 2010-2010 through a Massachussets Department of Conservation and Recreation tree planting program.

![Screenshot 2024-04-14 at 9 35 29 PM](https://github.com/andrews-j/IDCE-376_FinalProject/assets/26927475/f1710f8f-d12c-4d8e-834c-b92846e08c8e)

Raster images include NDBI (Normalized Differenced Built Index), NDVI (Normalized Differenced Vegetation Index), and UVI (Urban Vegetation Index) from 5 different time points: 2007, 2011, 2015, 2019, and 2023, clipped to Worcester city limits. 

Raster images were aquired with PySTAC. Each is a median composite image between March 15 and September 15 of the chosen year. See Get_Images.ipynb.

All data is kept in, or reprojected to EPSG 32619 WGS 84/ UTM Zone 19N.

Examples:

**NDBI 2007**

![Screenshot 2024-04-14 at 9 42 27 PM](https://github.com/andrews-j/IDCE-376_FinalProject/assets/26927475/45c41895-83cd-4436-9c0f-aa02297040d5)

**NDVI 2015**

![Screenshot 2024-04-14 at 9 44 33 PM](https://github.com/andrews-j/IDCE-376_FinalProject/assets/26927475/c88b0a3a-00e9-4f8e-8cdc-a72ef3384706)

**UVI 2023**

![Screenshot 2024-04-14 at 9 45 19 PM](https://github.com/andrews-j/IDCE-376_FinalProject/assets/26927475/9b0eef3e-7da8-4072-a880-4ab88805d2b3)

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
