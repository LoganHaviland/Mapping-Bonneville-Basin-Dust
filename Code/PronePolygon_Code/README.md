# README for PronePolygons_workflow.R

**Wind-erosion-prone soil polygons of the Bonneville Basin, Utah**  
Soil Survey Geographic Database (SSURGO) attribute filtering (Part 1) and
regional refinement (Part 2)

Authors: Kylie Hansen and Steve Wilcox

## Contents

- 1. Purpose
- 2. Files in this folder
- 3. Setup and how to run
- 4. What produces the deliverables
- 5. Input files
- 6. SSURGO ratings used in the filters
- 7. Output files
- 8. Field names in the shapefiles
- 9. The script, section by section
- 10. Software

## 1. Purpose

`PronePolygons_workflow.R` selects SSURGO soil map-unit polygons that are likely
sources of fine (PM10 / PM2.5) wind-blown dust, then divides the result into
four regional areas of interest (AOIs) used in later stages of the project. This
script investigates the larger Bonneville Basin while the area directly around
the Great Salt Lake was filtered for susceptibility in a different script.

Part 1 filters SSURGO map units on soil attributes and writes an intermediate
shapefile. Part 2 re-reads that shapefile and applies region-by-region edits
based on site knowledge, writing the four final AOI shapefiles.

## 2. Files in this folder

Keep the folder layout exactly as distributed.

Contents of `PronePolygon_Code/`:

| Item                       | Description                                                  |
|----------------------------|--------------------------------------------------------------|
| `PronePolygons_workflow.R` | the script                                                   |
| `README.md`                | this file                                                    |
| `data/inputs/`             | everything the script reads (section 5)                      |
| `data/outputs/`            | everything the script writes; created if missing (section 7) |

## 3. Setup and how to run

1. Install R (4.1 or later); RStudio is recommended but not required. The script
   installs the R packages it needs the first time it runs: sf, dplyr, stringr,
   mapview.
2. Download or unzip the `PronePolygon_Code` folder to any location. Do not
   rename or move anything inside `data/inputs/`.
3. Set the working directory to the `PronePolygon_Code` folder, so that
   `data/inputs/` and `data/outputs/` can be found. In RStudio, open
   `PronePolygons_workflow.R` and choose Session > Set Working Directory > To
   Source File Location. Otherwise run `setwd()` with the path to the folder.
4. Open `PronePolygons_workflow.R` and run it top to bottom. The whole script
   runs in about a minute; the SSURGO GeoPackage is about 300 MB but only six of
   its layers are read. Calls to `mapview()` open interactive maps in the
   RStudio Viewer; they are visual checks only and do not change any output. Use
   the layer control in the top-left corner of a map to switch basemaps or
   toggle layers.
5. Results appear in `data/outputs/`: the intermediate file from Part 1 and the
   four final AOI shapefiles from Part 2.

### Running Part 2 on its own

Part 2 reads `data/outputs/PronePolygons_county_GZ_NR_ESDs.shp`, which Part 1
writes. To run Part 2 without Part 1, place that shapefile (all four files: .shp
.shx .dbf .prj) in `data/outputs/`, run the Setup section of the script, then
continue from section 2.0.

## 4. What produces the deliverables

The intermediate file written at the end of Part 1 is produced solely by the
filter in section 1.5. Sections 1.3 and 1.4 are the two earlier, stricter drafts
of that filter: they define the lists it uses and show how the criteria were
relaxed; their own results appear only in the comparison map at the end of
section 1.5.

Small scattered polygons are removed in Part 2 with the hand-drawn
`TinyPolygons.shp`.

Part 2 deliberately re-reads the shapefile written by Part 1 instead of using
the in-memory object. Two things depend on that round trip:
- (a) writing to ESRI Shapefile abbreviates field names (section 8) and Part 2
  refers to the abbreviated names;
- (b) the polygon feature IDs used in section 2.4 are row numbers of the re-read
  file.

Part 2 uses planar (GEOS) geometry operations, `sf_use_s2(FALSE)`; see the notes
on section 2.0 below.

## 5. Input files

All in `data/inputs/`; spatial files are in WGS 84, EPSG:4326.

### Part 1

- **`GSLSSURGODatabase.gpkg`**: SSURGO data for the ten study counties exported
  from the NRCS SSURGO Portal, including rating tables aggregated by dominant
  condition. Only the map-unit polygon layer and the five rating tables listed
  under section 1.2 are read. Section 6 describes these ratings and the Portal
  settings used to generate them.
- **`wss.counties.shp`**: SSURGO map-unit polygons for the ten counties (UT601,
  602, 607, 608, 611, 612, 617, 618, 626, 632), downloaded from Web Soil Survey
  and combined.

### Part 2

"GEE" = digitized by hand in Google Earth Engine from site knowledge. The files
are listed with their role in `data/inputs/part2_inputs.csv`.

### Roles used in `part2_inputs.csv`

| Role       | Meaning                                    |
|------------|--------------------------------------------|
| drop       | polygons inside it are removed             |
| add        | polygons inside it are added back          |
| AOI extent | the result is clipped to it to form an AOI |

## 6. SSURGO ratings used in the filters

### How the ratings were generated

The rating tables in `GSLSSURGODatabase.gpkg` were generated with the NRCS
SSURGO Portal, which runs the same attribute "ratings" as Soil Data Viewer and
stores each one as a table named

`rating_<attribute>_<aggregation>[_<option>]`

The suffixes record the Portal settings that were chosen:

- **DCD**: aggregation method "Dominant Condition" (see below)
- **SL**: depth qualifier "Surface Layer": the attribute is taken from the
  surface horizon of each soil component
- **`jan_dec`**: month range January to December (ponding only)

No component-percent cutoff was set for any rating, so every component of a map
unit takes part in the aggregation. The tie-break rule chosen for each rating is
given with the rating below.

Dominant Condition (NRCS definition, table sdvalgorithm): the components of a
map unit that share the same attribute value are grouped, the percent
composition of each group is summed, and the value of the group with the highest
cumulative percent is returned. If two groups tie, the attribute's tie-break
rule decides (for ponding, the more frequent class wins). The
`pctMU_<attribute>` column that accompanies each rating is that cumulative
percent, i.e. the share of the map unit that carries the reported value. In this
database it ranges from 30 to 100 percent (median 85).

Missing values: the surface-sealing interpretation returns the phrase "Not
rated" where it could not be run; the other four ratings return no value (NA)
where a map unit has no data. The filters treat the two cases the same way
(section 9, 1.3).

The definitions below are condensed from SSURGO's own metadata table
sdvattribute, which is included in the GeoPackage and can be read with:

```r
library(sf)
f <- "data/inputs/GSLSSURGODatabase.gpkg"
st_read(f, query = "SELECT attributename, attributetablename,
                           attributecolumnname, algorithmname,
                           depthqualifiermode, attributedescription
                    FROM sdvattribute
                    WHERE resultcolumnname IN ('PondFCls', 'EcoSiteNm',
                          'SurfSeal', 'SurfText', 'OrgMatter')")
st_read(f, query = "SELECT algorithmname, algorithmdescription
                    FROM sdvalgorithm")
```

### The five ratings

"Observed" gives counts of the 1323 map units in the ten-county database.

**Ponding Frequency Class** (table `rating_PondFCls_DCD_jan_dec`)

**SSURGO source:** comonth.pondfreqcl (component monthly data)

**Portal settings:** Dominant Condition; beginning month January, ending month
December; tie-break rule "More Frequent"

**Definition:** ponding is standing water in a closed depression, removed only
by deep percolation, transpiration or evaporation. Classes: None (chance of
ponding nearly 0 percent in any year); Rare (nearly 0 to 5 percent); Occasional
(5 to 50 percent, on average once or less in 2 years); Frequent (more than 50
percent, more than once in 2 years)

**Observed:** None 1268, Frequent 22, Occasional 9, Rare 2, no value 22

**Use in filters:** 1.3 requires Frequent. 1.4 and 1.5 do not require a ponding
class, but a class other than None counts as a rated attribute for the
at-least-one-rated rule

**NRCS Ecological Site Name** (table `rating_EcoSiteNm_DCD`)

**SSURGO source:** coecoclass.ecoclassname, restricted to NRCS Rangeland Site
and NRCS Forestland Site classes

**Portal settings:** Dominant Condition; tie-break rule "Lower"

**Definition:** an ecological site is the product of all the environmental
factors responsible for its development: characteristic soils, hydrology and
plant community (kind and amount of vegetation). Site descriptions are in the
NRCS Field Office Technical Guide

**Observed:** 117 distinct site names

**Use in filters:** 1.5 removes map units whose dominant site is one of the 13
well-vegetated sites listed in the script (`vegetated_ESDs`)

**Soil Surface Sealing** (table `rating_SurfSeal_DCD`)

**SSURGO source:** soil interpretation "SOH - Soil Surface Sealing" (cointerp)

**Portal settings:** Dominant Condition; tie-break rule "Higher" (the more
susceptible class wins a tie)

**Definition:** surface sealing is the orientation and packing of dispersed soil
particles after aggregates break up under raindrop impact, clogging surface
pores; it is the first stage of crust formation. The interpretation rates the
susceptibility of the surface layer from exchangeable sodium, a silt/crusting
index, water-dispersible clay and organic matter on an index from 0 to 1: Low
(index 0), Moderate (between 0 and 1), High (index 1)

**Observed:** Moderate 537, Low 425, High 257, Not rated 104

**Use in filters:** 1.3 requires Low; 1.4 and 1.5 accept Low or Moderate

**Surface Texture** (table `rating_SurfText_DCD_SL`)

**SSURGO source:** chtexturegrp.texdesc, the representative texture

**Portal settings:** Dominant Condition; layer option "Surface Layer"; tie-break
rule "Lower"

**Definition:** USDA texture class of the fraction under 2 mm (for example loam
is 7 to 27 percent clay, 28 to 50 percent silt and under 52 percent sand), with
a modifier such as "gravelly" when 15 percent or more of the material is coarser
than sand

**Observed:** 64 distinct classes; most common Silt loam 262, Loam 172, Gravelly
loam 121; no value 99

**Use in filters:** 1.3 excludes Sandy loam. 1.4 and 1.5 accept only the twelve
fine-textured classes in `soil_txt`: Clay, Loam, Silty clay loam, Silt loam,
Very fine sandy loam, Clay loam, Silty clay, Sandy clay loam, and four
stratified classes (fine sandy loam to silty clay; silty clay to silt loam to
very fine sand; silty clay loam to silt loam to sand; silty clay loam to silt
loam to very fine sand)

**Organic Matter** (table `rating_OrgMatter_DCD_SL`)

**SSURGO source:** `chorizon.om_r`, the representative organic matter

**Portal settings:** layer option "Surface Layer"; Dominant Condition; tie-break
rule "Higher"; "Interpret Nulls as Zero" set to No, so map units without a value
stay empty rather than becoming 0. (SSURGO's default for this attribute is
Dominant Component over a depth range; both were changed.)

**Definition:** plant and animal residue at various stages of decomposition, as
a percentage by weight of the soil material under 2 mm

**Observed:** 0 to 85 percent, median 2.0; no value 102

**Use in filters:** 2 percent or less in 1.3, 1.4 and 1.5

### Ratings in the GeoPackage that the script does not read

The Portal run also produced ratings that were considered during development but
are not used by any filter, among them drainage class, electrical conductivity,
clay, silt and sand percentages, wind erodibility group and index, surface
salinity, hydrologic group, and monthly ponding classes. They remain in the
GeoPackage for reference.

## 7. Output files

Written to `data/outputs/`.

- **`PronePolygons_county_GZ_NR_ESDs.shp`**: intermediate (end of Part 1)
- **`PronePolygons_Ni80.shp`**: AOI 1: north of I-80, west of GSL
- **`PronePolygons_SkullValley.shp`**: AOI 2: Skull Valley
- **`PronePolygons_Si80.shp`**: AOI 3: south of I-80, west of GSL, excluding
  Tule Valley / Sevier Lake
- **`PronePolygons_TuleValley_SevierLake_Delta.shp`**: AOI 4: Tule Valley,
  Sevier Lake and Delta areas

## 8. Field names in the shapefiles

ESRI Shapefile limits field names to 10 characters, so sf abbreviates them on
write. DCD = dominant condition, SL = surface layer, pctMU = percent of the map
unit in the dominant condition.

| Shapefile | Full name                    | Meaning                               |
|-----------|------------------------------|---------------------------------------|
| MUKEY     | MUKEY                        | SSURGO map-unit key                   |
| AREASYM   | AREASYMBOL                   | soil survey area symbol               |
| SPATIAL   | SPATIALVER                   | spatial data version                  |
| MUSYM     | MUSYM                        | map-unit symbol                       |
| `arenm_x` | areaname                     | soil survey area name                 |
| `munam_x` | muname                       | map-unit name                         |
| `ESN_DCD` | `EcoSiteNm_DCD`              | ecological site name                  |
| `pMU_ESN` | `pctMU_EcoSiteNm_DCD`        | percent of map unit with that site    |
| `SrS_DCD` | `SurfSeal_DCD`               | surface sealing class                 |
| `pMU_SS_` | `pctMU_SurfSeal_DCD`         | percent of map unit with that class   |
| `ST_DCD_` | `SurfText_DCD_SL`            | surface texture                       |
| `pMU_ST_` | `pctMU_SurfText_DCD_SL`      | percent of map unit with that texture |
| `PFC_DCD` | `PondFCls_DCD_jan_dec`       | ponding frequency class, Jan-Dec      |
| `pMU_PFC` | `pctMU_PondFCls_DCD_jan_dec` | percent of map unit with that class   |
| `OM_DCD_` | `OrgMatter_DCD_SL`           | organic matter, percent               |
| `pMU_OM_` | `pctMU_OrgMatter_DCD_SL`     | percent of map unit with that value   |

## 9. The script, section by section

### Setup

Packages: sf, dplyr, stringr and mapview are installed if missing and attached.
mapview is set to put the layer control in the top left so layers can be
toggled, as in GEE, and to use three basemaps that need no API key
(OpenStreetMap, Esri.WorldImagery, OpenTopoMap); the CARTO basemaps in mapview's
default list now require an API key and render as blank tiles.

Paths: the working directory must be the `PronePolygon_Code` folder (section 3,
step 3). Inputs are read from `data/inputs/` and everything the script writes
goes to `data/outputs/`, which is created if missing.

### Part 1: Filter SSURGO map units on soil attributes

#### 1.1 Read the county map-unit polygons

`wss.counties.shp` holds the SSURGO map-unit polygons for all ten study
counties. The filtered attribute table built in 1.2 to 1.5 is joined back to
this layer by MUKEY.

#### 1.2 Read the SSURGO Portal ratings and build one ratings table

`GSLSSURGODatabase.gpkg` was built with the NRCS SSURGO Portal. It contains
ratings of soil attributes aggregated by dominant condition (DCD). The Portal
was preferred over the tabular SSURGO download because it gives control over the
aggregation (dominant condition, surface layer, month range for ponding). The
ratings used, their Portal settings and their class definitions are described in
section 6.

Layers read: the map-unit polygon layer (mupolygon, which carries mukey) and
five dominant-condition ratings (`_SL` = surface layer):

| Layer                         | Rating                                    |
|-------------------------------|-------------------------------------------|
| `rating_PondFCls_DCD_jan_dec` | ponding frequency class, January-December |
| `rating_EcoSiteNm_DCD`        | NRCS ecological site name (ESD)           |
| `rating_SurfSeal_DCD`         | surface sealing (crusting)                |
| `rating_SurfText_DCD_SL`      | surface texture                           |
| `rating_OrgMatter_DCD_SL`     | organic matter, %                         |

The database also holds ratings that were considered but are not used in any
filter (drainage class, electrical conductivity, clay, silt, sand); they are not
read.

The rating tables exported by the Portal carry areasymbol and musym but not
mukey; the Portal recommends joining them to mupolygon on (areasymbol, musym).
In this database every areasymbol-musym pair is a single map unit, so these
joins are one-to-one. The five joined tables are then combined into one table
keyed by mukey, in the order listed above. Each table also carries areasymbol,
spatialver, musym, areaname and muname, so after the joins those columns appear
several times; the first copy gets the suffix ".x" (musym.x, areaname.x,
muname.x) and is the one used from here on. The attributes of interest are kept
together with their dominant-condition percentages (`pctMU_*` columns).

#### 1.3 The "not rated" rule (draft: `PronePolygons_county_NR`)

The strict first-draft filter kept map units with a surface texture other than
sandy loam, organic matter of 2% or less, frequent ponding, and low surface
sealing. The salt flats were dropped by that filter only because their
surface-sealing rating is "Not rated". That is likely true of other areas too,
so from here on a map unit is kept when an attribute is not rated (or NA), as
long as at least one of the attributes IS rated; without that last condition,
water and other wholly unrated map units would be kept as well.

The categorical ratings (texture, sealing, ponding, ESD) use the string "Not
rated" for unrated map units, while `OrgMatter_DCD_SL` is numeric and is simply
NA when unrated. Both cases are allowed for in the filters.

One map unit next to the salt flats is added back explicitly by its mukey
(482188). The result, `PronePolygons_county_NR`, is the first-draft selection
with the not-rated rule applied and can be considered the most susceptible
polygons in the study area. It is not exported; it appears in the comparison map
at the end of 1.5.

#### 1.4 Gray zones around the most susceptible polygons (draft: `PronePolygons_county_GZ_NR`)

"Gray zones" are map units that are plausibly erodible but did not meet the
strict first-draft criteria; they are mostly in the "upper bathtub", the higher
ground around the basin floor. The not-rated rule is kept. Compared with 1.3:
the full list of fine textures is accepted, moderate surface sealing is allowed,
frequent ponding is no longer required, and unsuitable map-unit names are
excluded.

Two lists are defined here and used by the filters in 1.4 and 1.5:

- **`soil_txt`**: surface textures accepted (fine and very fine particle
  classes): clay, loam, silty clay loam, silt loam, very fine sandy loam, clay
  loam, silty clay, sandy clay loam, and the stratified fine-textured classes
- **`bad_munames`**: map-unit names excluded regardless of ratings: water,
  saline, gravel and borrow pits, rock land, very stony land, stony colluvial
  land, lava flows, stony terrace escarpments, and one complex next to the salt
  flats. Map units whose name contains "Rock outcrop" or "Rock land" are also
  excluded.

The result, `PronePolygons_county_GZ_NR`, contains the 1.3 polygons plus the
additional gray-zone polygons. It is not exported; it appears in the comparison
map at the end of 1.5.

#### 1.5 Remove vegetated ecological sites -> `PronePolygons_county_GZ_NR_ESDs`

THIS SECTION PRODUCES THE EXPORTED INTERMEDIATE FILE. The ecological site
descriptions (ESDs) present in the gray zones are listed and the well-vegetated
ones are removed: wet and semiwet meadows, wet streambank, loamy bottom (Great
Basin wildrye), semiwet saline meadow, the mountain loam, clay and stony loam
sites, high mountain spruce, and the upland sagebrush sites. The filter is the
1.4 gray-zone filter plus this ESD condition. A map compares the three Part 1
selections: 1.3, 1.4 and this one.

#### 1.6 Export the intermediate shapefile

Only the attributes needed in Part 2 are kept: MUKEY, AREASYMBOL, SPATIALVER,
MUSYM, areaname.x, muname.x, and the five ratings with their `pctMU_*`
percentages. sf abbreviates field names longer than ten characters when writing
to shapefile (section 8).

### Part 2: Regional refinement and the four final AOIs

The remaining edits apply site knowledge rather than soil criteria: whole
regions are dropped (well-vegetated rangeland, agriculture, urban area, high
ground) and what remains is grouped into four AOIs. Each step uses a polygon
digitized by hand in Google Earth Engine (section 5). The stage objects are
cumulative, and each AOI is taken from the stage shown, so the order of the
steps matters and the hand-drawn files are kept separate rather than merged:

- **stage 0** `PronePolygons_county_GZ_NR_ESD`: Part 1 output
- **stage 1** `PronePolygons_droppedN`: stage 0 minus
  `northern_utah_area_to_drop`
- **AOI 1** `PronePolygons_Ni80`: stage 1 within the `i80_north` extent, minus
  TinyPolygons
- **stage 2** `PronePolygons_droppedN_GSL`: stage 1 minus the four gsl
  sub-regions
- **stage 3** `PronePolygons_droppedN_GSL_Urb`: stage 2 minus
  `slc_urban_exclude`
- **AOI 2** SkullValley: stage 3 within the keepskull extent
- **stage 4** `PronePolygons_droppedN_GSL_Urb_Scull`: stage 3 minus RemoveSkull
  and RemoveFishCreek
- **AOI 3** `PronePolygons_Si80`: stage 4 within the `i80_south` extent, plus
  the Blue Creek / Fish Springs polygons, minus TinyPolygons
- **AOI 4** `TuleValley_SevierLake_Delta`: stage 4 minus
  `east_to_NE_of_sevier_lake` (except eleven kept polygons), minus RemovePolys,
  within the Tule extents

#### 2.0 Read the Part 1 output and the hand-drawn edit polygons

Geometry engine: the regional edits use planar (GEOS) geometry operations rather
than sf's default spherical (s2) operations, set with `sf_use_s2(FALSE)`. This
is how the published AOI shapefiles were produced. With s2 enabled the same
polygons, rows and attributes result, but polygon boundaries differ by small
slivers. Part 1 is unaffected by this setting.

The Part 1 output is re-read from the shapefile rather than taken from memory;
see section 4 for why.

The hand-drawn edit polygons are listed in `data/inputs/part2_inputs.csv` (see
section 5 for the roles). The script prints the manifest, stops if any file is
missing, and reads each file into the R object named in the manifest. The
geometry steps in 2.1 to 2.5 use those object names.

#### 2.1 North of I-80 and northern Utah

Step 1 drops outlying polygons in northern Utah. These have a suitable surface
texture but fall in well-vegetated ecological sites (dry rangeland and
agricultural land) or are scattered small polygons, and are qualitatively
different from the wind-erosion sources being modeled. Step 2 cuts AOI 1 (north
of I-80 and west of Great Salt Lake) from that result and removes tiny polygons.
Step 3 drops anything that overlaps the existing Great Salt Lake sub-regions.

#### 2.2 Salt Lake City urban area and Skull Valley

Step 1 drops polygons in the Salt Lake City urban zone. Step 2 handles Skull
Valley to Rush Valley: the larger polygons at the north end are kept as AOI 2
(`keepskull.shp`, cut from the stage after the urban drop), while the very small
polygons at the south end of Skull Valley, the cluster near Vernon at the south
end of Rush Valley (vegetated rangeland), the small polygons just south of the
Great Salt Lake shore, and the small polygons south-west of Fish Springs are
dropped (`RemoveSkull.shp`, `RemoveFishCreek.shp`).

#### 2.3 South of I-80: re-add Blue Creek / Fish Springs and split off the Dugway region

Polygons around Blue Lake (Blue Creek) and the wetland complex near Fish Springs
were dropped by the Part 1 filter but are wanted. They come from an earlier,
less restrictive draft of the filter (`PronePolygons_BlueFish.shp`) clipped to a
hand-drawn extent (`BlueFish.shp`). The imported layer has a different set of
columns, so before combining with `rbind()` the common attributes are kept,
missing columns are added as NA, and the columns are put in the same order. AOI
3 is then the large region south of I-80 in the Dugway area (not including Tule
Valley, Sevier Lake etc.), plus the added polygons, minus tiny polygons.

#### 2.4 Tule Valley, Sevier Lake and Delta region

This region needed the most judgment. `RemovePolys.shp` covers all the areas
recommended for removal (Ibapah; far west, immediately west, south and east of
Sevier Lake), and `east_to_NE_of_sevier_lake.shp` covers the large, mostly
agricultural and rangeland area between Sevier Lake and Utah Lake. A handful of
larger polygons inside that area, in the broader Delta region, are kept.

The polygons to keep were identified by their feature IDs in an interactive
mapview session. mapview numbers features by row, so these IDs are the row
numbers of the intermediate file read in 2.0, carried through the
`st_difference()` steps as row names. They are not a SSURGO attribute, and they
are only valid for a file with the same rows in the same order, which is why
Part 2 re-reads the shapefile written by Part 1. The script checks that all
eleven were found and prints them. Expected result:

| Row numbers                        | MUKEY   | MUSYM | Map unit                                      |
|------------------------------------|---------|-------|-----------------------------------------------|
| 305                                | 3183884 | 58    | Playas                                        |
| 333                                | 3183895 | 68    | Saltair-Yuba families complex, 0 to 8 percent |
| 2030, 2045, 2049, 2058, 2065, 2080 | 482409  | PM    | Playas                                        |
| 2265, 2278                         | 482417  | SA    | Saltair silt loam                             |
| 2424                               | 482429  | UL    | Uvada silt loam                               |

`east_to_NE_of_sevier_lake` is used to drop the surrounding area, so the kept
polygons must first be cut out of it. One kept polygon lies outside it, which
makes `st_intersection()` fail, so the kept polygons are split into those that
intersect it and those that do not, and only the intersecting ones are removed
from the drop area. AOI 4 is then the stage-4 result minus that reduced drop
area, minus RemovePolys, clipped to the two Tule Valley extents
(`TuleDraft.shp`, `TuleValley_WSev.shp`). The feature-ID helper column is
removed before export.

#### 2.5 Match columns and map the four AOIs

The four layers do not have identical columns (the Blue Creek / Fish Springs
step changed the column set), so columns are matched so that all four AOIs carry
the same fields. They are then shown together on one map with the Great Salt
Lake sub-regions as a visual check.

#### 2.6 Export the four AOI shapefiles and read them back

The four AOIs are written to `data/outputs/` (section 7) and read back from disk
as a check. The script ends by printing `sessionInfo()` so the software versions
used are recorded.

## 10. Software

R 4.1 or later with the packages sf, dplyr, stringr and mapview. The script
installs missing packages on first run and prints `sessionInfo()` at the end so
the versions used for a run are recorded.
