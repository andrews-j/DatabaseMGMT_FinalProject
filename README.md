# Urban Greenery and Demographics in Worcester, MA

### IDCE 376, Spatial Database Management, Spring 2024
#### Jason Andrews, Clark University MSGIS, 2024

This repository contains submissions pertaining to final project work for IDCE 376.

The assignment description can be viewed in the *Final_Project-Rubric.pdf* document.

# Introduction

### Objective: 
Combine infomation from census and ASC data to create an HDI by census tract layer for Worcester, and compare this to metrics of urban canopy/greenness.

### Research Questions:
- How does urban canopy correlate with our combined measure of economic mobility, educational attainment, and population health?
- Has this relationship changed over time?

### Study Area:

The study area is the city limits of Worcester, and the spatial scale of the analysis will be the 44 census tracts in Worcester, as visualized below:

![Screenshot 2024-04-14 at 9 27 33 PM](https://github.com/andrews-j/IDCE-376_FinalProject/assets/26927475/5a63beb5-057f-4372-af2c-cbc16d154f6a)

## Part 1: Data Aquisition

For  information on where data was obtained, please see DataSources.md

### Vector Layers:

**2010 and 2020 Census**

These layers contain information about total population, and racial composition for each census tract. 

See **Cenus2010_cleaning.ipynb** and **Cenus2020_cleaning.ipynb** in the Scripts folder.

This is a subset of the 2010 census data:

![Screenshot 2024-04-14 at 9 30 35 PM](https://github.com/andrews-j/IDCE-376_FinalProject/assets/26927475/7008a268-850c-4f0c-860a-d656f19596c2)

**CDC Life Expectancy by Census Tract**

See **CDC_LE_Processing.ipynb**

<img width="988" alt="Screenshot 2024-04-23 at 5 24 03 PM" src="https://github.com/andrews-j/IDCE-376_FinalProject/assets/26927475/518b066e-ffc0-4c58-8fdc-acd15e518d1d">

**American Community Survey-- Percent of Population with Income below Federal Poverty Line**

Both ASC layers were manually cleaned in QGIS, with further cleaning in python. The most tedious part of this entire process was merging census areas that were split betwen the 2010 and 2020 census.

See **ACS_2020_Merge.ipynb**

<img width="907" alt="Screenshot 2024-04-23 at 5 28 13 PM" src="https://github.com/andrews-j/IDCE-376_FinalProject/assets/26927475/fec9c855-032f-4ec7-b7f4-874d48ad379d">

**American Community Survey-- Percent of Population with Bachelor's Degrees**

<img width="885" alt="Screenshot 2024-04-23 at 5 27 22 PM" src="https://github.com/andrews-j/IDCE-376_FinalProject/assets/26927475/44e13066-00a2-4863-8861-f135bee7ee15">

**Tree Planting Points**

Point layer of nearly 10,000 trees planted in Worcester County in 2010-2012 through a Massachussets Department of Conservation and Recreation (MA DCR) tree planting program.

![Screenshot 2024-04-14 at 9 35 29 PM](https://github.com/andrews-j/IDCE-376_FinalProject/assets/26927475/f1710f8f-d12c-4d8e-834c-b92846e08c8e)

**Canopy Cover Maps**

Worcester canopy cover vector layers from 2008, 2010, and 2015. See DataSources.md for information on how these were created. 

Canopy cover 2015:

<img width="863" alt="Screenshot 2024-05-02 at 1 02 25 PM" src="https://github.com/andrews-j/IDCE-376_FinalProject/assets/26927475/a6580457-e629-4d79-863d-6a21710b7e64">

Canopy Cover 2015 detail:

<img width="844" alt="Screenshot 2024-05-02 at 1 03 43 PM" src="https://github.com/andrews-j/IDCE-376_FinalProject/assets/26927475/bba5ab87-a17f-4ab6-ad5b-cdb49bdefaf7">

### Raster Layers:

Raster images include NDBI (Normalized Differenced Built Index), NDVI (Normalized Differenced Vegetation Index), and UVI (Urban Vegetation Index) from 5 different time points: 2007, 2011, 2015, 2019, and 2023, clipped to Worcester city limits. 

Raster images were aquired with PySTAC. Each is a median composite image between March 15 and September 15 of the chosen year. See GetWorcesterImages.ipynb.

All data is kept in, or reprojected to EPSG 32619 WGS 84/ UTM Zone 19N.

Examples:

**NDBI 2007**

<img width="637" alt="Screenshot 2024-05-02 at 2 31 19 PM" src="https://github.com/andrews-j/IDCE-376_FinalProject/assets/26927475/d53fd787-772e-418d-a5aa-624f806ac45c">

**NDVI 2007**

<img width="635" alt="Screenshot 2024-05-02 at 2 35 19 PM" src="https://github.com/andrews-j/IDCE-376_FinalProject/assets/26927475/1b80456a-d100-4fc5-b000-c588108a8ead">

## Part 2: Importing Data to SQL

**See *ShellCommands.sh* for more details**

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

The result, at this point, is that we have quite a lot of tables, 41 to be exact.

<img width="354" alt="Screenshot 2024-04-23 at 6 09 33 PM" src="https://github.com/andrews-j/IDCE-376_FinalProject/assets/26927475/5f62c549-f437-4ccc-99a9-492039556156">

## Part 3: Create Composite HDI

Now we are going to use the life expectancy estimate, percent of population in poverty, and percent of population with a bachelor's degree to create an HDI measure for each tract. To do this we will normalize each measure to an index between 0 and 1, which will then be used to weight each evenly in our final composite index.

See FinalProj_SQL.sql for more details, but here is the fun part, combining the relevant columns to a single table:

```SQL
CREATE TABLE hdi_calc AS
SELECT
    l.tract,
    l."life expec",
    p.povper,
    e.perbach
FROM
    le_tracts l
JOIN
    woo_poverty_2020 p ON l.tract = p.tract
JOIN
    woo_education_2020 e ON l.tract = e.tract;
```
This is what our table looks like:

<img width="1017" alt="Screenshot 2024-04-23 at 7 21 02 PM" src="https://github.com/andrews-j/IDCE-376_FinalProject/assets/26927475/06fc47c8-6b8f-4a87-9338-e0e91ff07fb7">


Now we will calculate a 0-1 normalized value for each
```SQL
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
```
Which brings us to here:

<img width="1033" alt="Screenshot 2024-04-24 at 8 46 46 PM" src="https://github.com/andrews-j/IDCE-376_FinalProject/assets/26927475/9b0b7359-a081-4633-b0a3-4777d4526080">

Notice that there are a few tracts without life expectancy data. We will subsitute an average value in those cases.

One thing we need to do is reverse the poverty index. Poverty is bad, higher rates bring down HDI. 

```SQL
-- Update the hdi_calc table with reversed normalized poverty rates:
UPDATE hdi_calc AS h
SET 
    pov_norm = 1 - (h.pov_norm);
```

<img width="1044" alt="Screenshot 2024-04-24 at 10 41 45 PM" src="https://github.com/andrews-j/IDCE-376_FinalProject/assets/26927475/0332c189-1621-4b68-a465-beac622067c8">

Now lets calculate our HDI index by tract:
```sql
ALTER TABLE hdi_calc
ADD COLUMN hdi NUMERIC;

UPDATE hdi_calc
SET hdi = (pov_norm + ed_norm + le_norm) / 3;
```
<img width="1214" alt="Screenshot 2024-04-24 at 10 46 20 PM" src="https://github.com/andrews-j/IDCE-376_FinalProject/assets/26927475/95d4f811-d0db-4e8b-bc21-35a0d6eba322">

We now have HDI by tract calculated. Let's bring in canopy data. 

## Part 4: H Tree I:

Start by calculating percent canopy per tract, in a new table

```sql
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
```
And bring in tract area

```sql
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
```

And calculate percent canopy by tract
```sql
ALTER TABLE canopy_cover_by_tract
ADD COLUMN per_canopy NUMERIC;

-- Update the per_canopy column with the calculated percent canopy cover
UPDATE canopy_cover_by_tract
SET per_canopy = (total_canopy_area / tract_area) * 100;
```

<img width="501" alt="Screenshot 2024-04-24 at 10 55 41 PM" src="https://github.com/andrews-j/IDCE-376_FinalProject/assets/26927475/b78f4b7a-469b-43d3-a874-7cd28cb38598">

Now bring percent canopy in as a column in 'hdi_calc'
```sql
ALTER TABLE hdi_calc ADD COLUMN per_canopy NUMERIC;

UPDATE hdi_calc AS h
SET per_canopy = c.per_canopy
FROM canopy_cover_by_tract AS c
WHERE h.tract = c.tract;
```
And normalize it as a 0-1 index
```sql
SELECT
    MIN(per_canopy) AS min_per_canopy,
    MAX(per_canopy) AS max_per_canopy
INTO
    min_max_per_canopy
FROM
    canopy_cover_by_tract;

ALTER TABLE hdi_calc
ADD COLUMN per_canopy_norm NUMERIC;
```

Finally, use the percent canopy normalized index to creat H Tree I
```sql
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
```

Brilliant!

<img width="1257" alt="Screenshot 2024-04-24 at 10 59 54 PM" src="https://github.com/andrews-j/IDCE-376_FinalProject/assets/26927475/4285388c-c8d8-4296-ae4f-6fda7c4bcc5d">




## Part 5: Visualize and Analyze

HDI

![Screenshot 2024-04-24 at 10 12 02 PM](https://github.com/andrews-j/IDCE-376_FinalProject/assets/26927475/c2cddbef-93c8-412b-8504-16057ff5edb4)

Versus H Tree I

![Screenshot 2024-04-24 at 10 11 18 PM](https://github.com/andrews-j/IDCE-376_FinalProject/assets/26927475/00052bb6-a787-4ca7-a61f-96ae9ed1eb76)

HDI Diff

This image depicts which how the index for each tract changed with the addition of canopy as 1/4 of the composite index.

![Screenshot 2024-04-24 at 11 26 51 PM](https://github.com/andrews-j/IDCE-376_FinalProject/assets/26927475/b056eb15-233f-42fa-8fce-4fc843fdf617)

Comparing this map to HDI (sans canopy) seems to suggest that areas with low initial HDI actually drop when adding the canopy index. 

Let's check out a regression between HDI and HDI change:

![Screenshot 2024-04-25 at 1 20 02 PM](https://github.com/andrews-j/IDCE-376_FinalProject/assets/26927475/6f8bf1f6-a55d-4c39-aa04-1e5b850d9d21)

And our initial impression is, on average, correct. Or in other words, as initial HDI increases, so does the amount that the composite index increases when you add canopy cover. 

This suggests that canopy cover is more unequal than the population level metrics of well being that comprise HDI, on average. 

## Further questions:

### How to measure well being

How do we measure well-being, socio-economic or otherwise, by census tract? What do we care about? Environmental justice criteria are often used in this way. According to [mass.gov](https://www.mass.gov/info-details/environmental-justice-populations-in-massachusetts), Environmental Justice communities are defined as a community where one or more of the following criteria are met:

- The annual median household income is 65 percent or less of the statewide annual median household income
- Minorities make up 40 percent or more of the population
- 25 percent or more of households identify as speaking English less than "very well"
- Minorities make up 25 percent or more of the population and the annual median household income of the municipality in which the neighborhood is located does not exceed 150 percent of the statewide annual median household income.

I am curious to what extent this lense on well being would correlate with the HDI measure that I calculated here. There is also the CDC's social vulerability index, which includes as many as 15 different metrics. It is a complex sociological question to consider which of these is the most 'valid' measure of community level well being, or even more generally what metrics we care about most and how we measure them. I want to keep thinking about this. 

### Increase statistical robustness

The biggest adjustment that I could make to my statistical methods to increase the robustness of this analysis is using z-scores (0-1 indexes) from a wider dataset than just Worcester. For example:
The canopy index here compares only Worcester cenusus tracts with other Worcester census tracts. However, Worcester may have a higher canopy cover percentage than most comparable cities. In which case a canopy index score on the low end of this analysis may not be so bad, when stacked up against other cities, particularly controlling for HDI. 

In other words, low HDI areas that dropped even more when the local canopy z-score was factored in, may in fact be more leafy than comparable neighborhoods in other cities. An analysis bringing in data from other cities would contextualize the H Tree I index by comparing it to tracts beyond just Worcester.

### Work out SQL raster issues

I've been largely stymied in my attempts to directly analyze rasters in SQL. Null values pop up where there are in fact valid values in the pre-import raster. Being able to use rasters in this analysis would be illuminating, particularly being able to compare how closely NDBI, NDVI, or UVI lines up with canopy cover percentage, and potentially combining these into a composite urban greenery index.
