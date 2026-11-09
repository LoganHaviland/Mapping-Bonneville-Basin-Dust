################################################################################
#   Wind-erosion-prone soil polygons of the Bonneville Basin, Utah
#   Soil Survey Geographic Database (SSURGO) attribute filtering (Part 1)
#   and regional refinement (Part 2)
################################################################################
# Purpose: select SSURGO soil map-unit polygons that are likely sources of fine
#          (PM10 / PM2.5) wind-blown dust and divide them into four regional
#          areas of interest (AOIs).
#
# Authors: Kylie Hansen and Steve Wilcox
#
# See README.md for setup instructions, the folder layout, input and output
# files, shapefile field names, and a section-by-section explanation of the
# methods and decisions. Before running, set the working directory to the
# folder that holds this script and the data folder. Outputs are written to
# data/outputs/.
################################################################################

# Setup ----

## Packages ----
want <- c("sf", "dplyr", "stringr", "mapview")
need <- want[!(want %in% installed.packages()[, "Package"])]
if (length(need)) install.packages(need)
invisible(lapply(want, library, character.only = TRUE))
rm(want, need)

# mapview: layer control top left; basemaps that need no API key
mapviewOptions(fgb = FALSE, layers.control.pos = "topleft",
               basemaps = c("OpenStreetMap", "Esri.WorldImagery", "OpenTopoMap"))

## Paths ----
# Set the working directory to the folder holding this script and data/
# (RStudio: Session > Set Working Directory > To Source File Location)
dir <- list()
dir$root    <- getwd()
dir$inputs  <- file.path(dir$root, "data", "inputs")
dir$outputs <- file.path(dir$root, "data", "outputs")

if (!dir.exists(dir$inputs)) {
  stop("Folder not found: ", dir$inputs, "\n",
       "Set the working directory to the folder that holds this script ",
       "and the data folder, then run again.")
}
dir.create(dir$outputs, showWarnings = FALSE)

################################################################################
# PART 1  Filter SSURGO map units on soil attributes ----
################################################################################

## 1.1 Read the county map-unit polygons ----

# SSURGO map-unit polygons for the ten study counties
wss.counties <- st_read(file.path(dir$inputs, "wss.counties.shp"))

## 1.2 Read the SSURGO Portal ratings and build one ratings table ----

# SSURGO Portal database (README 1.2)
file_path <- file.path(dir$inputs, "GSLSSURGODatabase.gpkg")

# All layers available in the database
layers <- st_layers(file_path)
print(layers)

# Layers used: map-unit polygons (carry mukey) and the five ratings; _SL = surface layer
layers_used <- c(
  "mupolygon",
  "rating_PondFCls_DCD_jan_dec",  # ponding frequency class, January-December
  "rating_EcoSiteNm_DCD",         # NRCS ecological site name (ESD)
  "rating_SurfSeal_DCD",          # surface sealing (crusting)
  "rating_SurfText_DCD_SL",       # surface texture
  "rating_OrgMatter_DCD_SL")      # organic matter, %

# Read each layer as a plain data frame (geometry dropped)
layer_tables <- list()
for (layer_name in layers_used) {
  layer_data <- st_read(file_path, layer = layer_name)
  layer_tables[[layer_name]] <- st_drop_geometry(layer_data)}

# Map-unit table (provides mukey) and the rating layers
mupolygon <- layer_tables[["mupolygon"]]
rating_layers <- setdiff(layers_used, "mupolygon")

# Attach mukey to each rating table (one-to-one joins)
rating_tables <- list()
for (layer_name in rating_layers) {
  rating_tables[[layer_name]] <- mupolygon %>%
    left_join(layer_tables[[layer_name]], by = c("areasymbol", "musym"))
}

# Combine into one table keyed by mukey; duplicated columns get the suffix .x
ratingstable <- rating_tables[[1]]
for (tbl in rating_tables[-1]) {
  ratingstable <- left_join(ratingstable, tbl, by = "mukey")
}

# Attributes of interest with their dominant-condition percentages (pctMU_*)
refined_ratingstablewithpct <- ratingstable %>%
  group_by(mukey) %>%
  select(mukey, musym.x, areasymbol.x, areaname.x, muname.x,
         EcoSiteNm_DCD, pctMU_EcoSiteNm_DCD,
         SurfSeal_DCD, pctMU_SurfSeal_DCD,
         SurfText_DCD_SL, pctMU_SurfText_DCD_SL,
         PondFCls_DCD_jan_dec, pctMU_PondFCls_DCD_jan_dec,
         OrgMatter_DCD_SL, pctMU_OrgMatter_DCD_SL)

## 1.3 The "not rated" rule (draft: PronePolygons_county_NR) ----

# Strict first-draft filter with the "not rated" rule (README 1.3)
PMhigh_NR <- refined_ratingstablewithpct %>%
  filter(
    mukey == 482188 | # add polygon next to salt flats
    (
      (SurfText_DCD_SL != "Sandy loam" | SurfText_DCD_SL %in% c("Not rated") | is.na(SurfText_DCD_SL)) &
      (OrgMatter_DCD_SL <= 2 | OrgMatter_DCD_SL == "Not rated" | is.na(OrgMatter_DCD_SL)) &
      (PondFCls_DCD_jan_dec == "Frequent" | PondFCls_DCD_jan_dec == "Not rated" | is.na(PondFCls_DCD_jan_dec)) &
      (SurfSeal_DCD == "Low" | SurfSeal_DCD == "Not rated" | is.na(SurfSeal_DCD)) &

      # require at least one rated attribute
      ((!is.na(SurfText_DCD_SL) & SurfText_DCD_SL != "Not rated") |
       (!is.na(OrgMatter_DCD_SL) & OrgMatter_DCD_SL != "Not rated") |
       (!is.na(PondFCls_DCD_jan_dec) & PondFCls_DCD_jan_dec != "Not rated") |
       (!is.na(SurfSeal_DCD) & SurfSeal_DCD != "Not rated"))
    ))

PronePolygons_county_NR <- merge(wss.counties, PMhigh_NR, by.x = "MUKEY", by.y = "mukey")

## 1.4 Gray zones around the most susceptible polygons (draft: PronePolygons_county_GZ_NR) ----

# Accepted surface textures (fine and very fine particle classes); used in 1.4 and 1.5
soil_txt <- c("Clay", "Loam", "Silty clay loam", "Silt loam", "Stratified fine sandy loam to silty clay",
              "Very fine sandy loam", "Clay loam", "Stratified silty clay to silt loam to very fine sand",
              "Silty clay", "Sandy clay loam", "Stratified silty clay loam to silt loam to sand",
              "Stratified silty clay loam to silt loam to very fine sand")

# Map-unit names excluded regardless of ratings
bad_munames <- c("Water", "saline", "Gravel pits", "Miscellaneous water", "Rock land",
                 "Saxby-Very stony land association", "Very stony land", "Water",
                 "Stony colluvial land", "Borrow pits", "Pits", "Lava flows",
                 "Stony terrace escarpments", "Needle Peak-Saltair families complex , 0 to 2 percent slopes")

# Gray-zone filter (README 1.4)
PMmid_NR <- refined_ratingstablewithpct %>%
  filter(
    mukey == 482188 | # add polygon next to salt flats
    (
      (SurfText_DCD_SL %in% soil_txt | SurfText_DCD_SL %in% c("Not rated") | is.na(SurfText_DCD_SL)) &
      (OrgMatter_DCD_SL <= 2 | OrgMatter_DCD_SL == "Not rated" | is.na(OrgMatter_DCD_SL)) &
      (SurfSeal_DCD %in% c("Low", "Moderate") | SurfSeal_DCD == "Not rated" | is.na(SurfSeal_DCD)) &
      !muname.x %in% bad_munames &
      !str_detect(muname.x, str_c(c("Rock outcrop", "Rock land"), collapse = "|")) &

      # require at least one rated attribute
      ((!is.na(SurfText_DCD_SL) & SurfText_DCD_SL != "Not rated") |
       (!is.na(OrgMatter_DCD_SL) & OrgMatter_DCD_SL != "Not rated") |
       (!is.na(PondFCls_DCD_jan_dec) & !PondFCls_DCD_jan_dec %in% c("Not rated", "None")) |
       (!is.na(SurfSeal_DCD) & SurfSeal_DCD != "Not rated"))
    ))

PronePolygons_county_GZ_NR <- merge(wss.counties, PMmid_NR, by.x = "MUKEY", by.y = "mukey")

## 1.5 Remove vegetated ecological sites -> PronePolygons_county_GZ_NR_ESDs ----

# List of the ESDs in AOI
unique(PronePolygons_county_GZ_NR$EcoSiteNm_DCD)

# Vegetated ESDs to remove
vegetated_ESDs <- c(
  "Wet Fresh Meadow",
  "Semiwet Fresh Meadow",
  "Wet Fresh Streambank",
  "Loamy Bottom (Great Basin Wildrye)",
  "Semiwet Saline Meadow",
  "Mountain Loam (mountain big sagebrush)",
  "Mountain Clay (slender wheatgrass)",
  "Mountain Stony Loam (mountain big sagebrush)",
  "High Mountain Very Steep Stony Loam (Engelmann Spruce)",
  "Upland Loam (Wyoming Big Sagebrush)",
  "Upland Loam (Basin Big Sagebrush)",
  "Upland Loam (Bonneville Big Sagebrush) North",
  "Upland Gravelly Loam (Bonneville Big Sagebrush)")

# Final filter: gray-zone filter plus removal of the vegetated ESDs. Produces the exported file.
PMmid_NR_ESD <- refined_ratingstablewithpct %>%
  filter(
    mukey == 482188 | # add polygon next to salt flats
    (
      (SurfText_DCD_SL %in% soil_txt | SurfText_DCD_SL %in% c("Not rated") | is.na(SurfText_DCD_SL)) &
      (OrgMatter_DCD_SL <= 2 | OrgMatter_DCD_SL == "Not rated" | is.na(OrgMatter_DCD_SL)) &
      (SurfSeal_DCD %in% c("Low", "Moderate") | SurfSeal_DCD == "Not rated" | is.na(SurfSeal_DCD)) &
      !muname.x %in% bad_munames &
      !EcoSiteNm_DCD %in% vegetated_ESDs & # the ESD condition
      !str_detect(muname.x, str_c(c("Rock outcrop", "Rock land"), collapse = "|")) &

      # require at least one rated attribute
      ((!is.na(SurfText_DCD_SL) & SurfText_DCD_SL != "Not rated") |
       (!is.na(OrgMatter_DCD_SL) & OrgMatter_DCD_SL != "Not rated") |
       (!is.na(PondFCls_DCD_jan_dec) & !PondFCls_DCD_jan_dec %in% c("Not rated", "None")) |
       (!is.na(SurfSeal_DCD) & SurfSeal_DCD != "Not rated"))
    ))

PronePolygons_county_GZ_NR_ESDs <- merge(wss.counties, PMmid_NR_ESD, by.x = "MUKEY", by.y = "mukey")

# Maps comparing filters from section 1
mapview(PronePolygons_county_NR,
        col.regions = "darkred",
        color = "red",
        alpha.regions = 0.4,
        layer.name = "PronePolygons_county_NR") +

mapview(PronePolygons_county_GZ_NR,
          col.regions = "darkblue",
          color = "blue",
          alpha.regions = 0.4,
          layer.name = "PronePolygons_county_GZ_NR") +

mapview(PronePolygons_county_GZ_NR_ESDs,
          col.regions = "darkgreen",
          color = "green",
          alpha.regions = 0.4,
          layer.name = "PronePolygons_county_GZ_NR_ESDs")

## 1.6 Export the intermediate shapefile ----

# Attributes needed in Part 2; field names are abbreviated on write (README 8)
PronePolygons_DraftOne <- PronePolygons_county_GZ_NR_ESDs[, c("MUKEY", "AREASYMBOL", "SPATIALVER", "MUSYM",
                                                              "areaname.x", "muname.x", "EcoSiteNm_DCD", "pctMU_EcoSiteNm_DCD",
                                                              "SurfSeal_DCD", "pctMU_SurfSeal_DCD", "SurfText_DCD_SL",
                                                              "pctMU_SurfText_DCD_SL", "PondFCls_DCD_jan_dec", "pctMU_PondFCls_DCD_jan_dec",
                                                              "OrgMatter_DCD_SL", "pctMU_OrgMatter_DCD_SL", "geometry")]

st_write(PronePolygons_DraftOne, file.path(dir$outputs, "PronePolygons_county_GZ_NR_ESDs.shp"), append = FALSE, delete_dsn = TRUE)

################################################################################
# PART 2  Regional refinement and the four final AOIs ----
################################################################################

## 2.0 Read the Part 1 output and the hand-drawn edit polygons ----

# Planar (GEOS) geometry for the regional edits (README 2.0)
sf_use_s2(FALSE)

# Part 1 output, re-read from file on purpose (README 4)
PronePolygons_county_GZ_NR_ESD <- st_read(file.path(dir$outputs, "PronePolygons_county_GZ_NR_ESDs.shp"))

# Manifest of the hand-drawn edit polygons: object, file, role, used_in, covers (README 5)
part2_inputs <- read.csv(file.path(dir$inputs, "part2_inputs.csv"), stringsAsFactors = FALSE)
print(part2_inputs[, c("object", "file", "role", "used_in")])

# Stop early if any file is missing
missing_files <- part2_inputs$file[!file.exists(file.path(dir$inputs, part2_inputs$file))]
if (length(missing_files)) {
  stop("Missing Part 2 input file(s) in ", dir$inputs, ": ", paste(missing_files, collapse = ", "))
}

# Read each file into the object named in the manifest
for (i in seq_len(nrow(part2_inputs))) {
  assign(part2_inputs$object[i], st_read(file.path(dir$inputs, part2_inputs$file[i]), quiet = TRUE))
}

## 2.1 North of I-80 and northern Utah ----

# Step 1: drop outlying polygons in northern Utah
PronePolygons_droppedN <- st_difference(PronePolygons_county_GZ_NR_ESD, northern_utah_area_to_drop)

# Step 2: AOI 1, north of I-80 and west of Great Salt Lake, minus tiny polygons
PronePolygons_Ni80_wTiny <- st_intersection(PronePolygons_droppedN, i80_north_gsl_grouping_poly)
PronePolygons_Ni80 <- st_difference(PronePolygons_Ni80_wTiny, PronePolygons_Tiny)
mapview(PronePolygons_Ni80)

# Step 3: drop overlaps with the Great Salt Lake sub-regions
gsl_all <- rbind(gsl_nw, gsl_ne, gsl_sw, gsl_se)
gsl_union <- st_union(gsl_all)

PronePolygons_droppedN_GSL <- st_difference(PronePolygons_droppedN, gsl_union)
mapview(PronePolygons_droppedN_GSL)

## 2.2 Salt Lake City urban area and Skull Valley ----

# Step 1: drop the Salt Lake City urban zone
PronePolygons_droppedN_GSL_Urb <- st_difference(PronePolygons_droppedN_GSL, slc_urban_exclude)

# Step 2: Skull Valley / Rush Valley drops, then AOI 2 (Skull Valley) from the keep extent
PronePolygons_droppedN_GSL_Urb_Scull_One <- st_difference(PronePolygons_droppedN_GSL_Urb, RemoveSkull)
PronePolygons_droppedN_GSL_Urb_Scull <- st_difference(PronePolygons_droppedN_GSL_Urb_Scull_One, RemoveFishCreek)

SkullValley <- st_intersection(PronePolygons_droppedN_GSL_Urb, KeepSkull)
mapview(SkullValley)

## 2.3 South of I-80: re-add Blue Creek / Fish Springs and split off the Dugway region ----

# Blue Creek / Fish Springs polygons to add back (README 2.3)
AddedPolygons_BlueFish <- st_intersection(PronePolygons_BlueFish, Polygons_BlueFish)

# Match the column sets of the two layers (common attributes, missing as NA, same order) so rbind() works
AddedPolygons_BlueFish <- AddedPolygons_BlueFish %>%
  select("MUKEY", "AREASYM", "SPATIAL", "MUSYM", "arenm_x", "munam_x", "ESN_DCD", "SrS_DCD",
         "ST_DCD_", "PFC_DCD", "OM_DCD_", "geometry")

cols1 <- names(AddedPolygons_BlueFish)
cols2 <- names(PronePolygons_droppedN_GSL_Urb_Scull)

missing_in_PronePolygons_droppedN_GSL_Urb_Scull <- setdiff(cols1, cols2)
missing_in_AddedPolygons_BlueFish <- setdiff(cols2, cols1)

for (col in missing_in_PronePolygons_droppedN_GSL_Urb_Scull) {
  PronePolygons_droppedN_GSL_Urb_Scull[[col]] <- NA}

for (col in missing_in_AddedPolygons_BlueFish) {
  AddedPolygons_BlueFish[[col]] <- NA}

PronePolygons_droppedN_GSL_Urb_Scull <- PronePolygons_droppedN_GSL_Urb_Scull[, names(AddedPolygons_BlueFish)]
mapview(PronePolygons_droppedN_GSL_Urb_Scull)

# AOI 3: south of I-80 (Dugway area) plus the added polygons, minus tiny polygons
PronePolygons_Si80_noBlueFish <- st_intersection(PronePolygons_droppedN_GSL_Urb_Scull, i80_south_gsl_grouping_poly)
PronePolygons_Si80_wTiny <- rbind(PronePolygons_Si80_noBlueFish, AddedPolygons_BlueFish) # the added polygons from above
PronePolygons_Si80 <- st_difference(PronePolygons_Si80_wTiny, PronePolygons_Tiny)
mapview(PronePolygons_Si80)

## 2.4 Tule Valley, Sevier Lake and Delta region ----

# Polygons to keep inside the large drop area, selected by row number of the re-read Part 1 file (README 2.4)
PronePolygons_droppedN_GSL_Urb_Scull$mvFeatureId <- rownames(PronePolygons_droppedN_GSL_Urb_Scull)

target_mvFeatureId <- c("2049", "2424", "2278", "2265", "2058", "2030",
                        "2065", "2045", "333", "2080", "305")

PronePolygons_TuleScull <- PronePolygons_droppedN_GSL_Urb_Scull %>%
  dplyr::filter(mvFeatureId %in% target_mvFeatureId)

# Check that all eleven were found; expected map units are listed in README 2.4
stopifnot(nrow(PronePolygons_TuleScull) == length(target_mvFeatureId))
print(st_drop_geometry(PronePolygons_TuleScull)[, c("mvFeatureId", "MUKEY", "MUSYM", "munam_x")])

mapview(PronePolygons_TuleScull)

# Cut the kept polygons out of the drop area; one kept polygon lies outside it, hence the split
intersecting     <- PronePolygons_TuleScull[st_intersects(PronePolygons_TuleScull, east_to_NE_of_sevier_lake, sparse = FALSE), ]
non_intersecting <- PronePolygons_TuleScull[!st_intersects(PronePolygons_TuleScull, east_to_NE_of_sevier_lake, sparse = FALSE), ]

east_minus_intersecting <- st_difference(east_to_NE_of_sevier_lake, st_union(intersecting))

# Tule Valley extents
Tule_all <- rbind(TuleValArea_Isolated, TuleVal_Isolated)

# AOI 4: drop the surrounding area, drop the removal areas, clip to the Tule extents
TuleValley_SevierLake_Delta_One <- st_difference(PronePolygons_droppedN_GSL_Urb_Scull, east_minus_intersecting)
TuleValley_SevierLake_Delta_Two <- st_difference(TuleValley_SevierLake_Delta_One, TuleVal_SevierLake_DeltaReg)
TuleValley_SevierLake_Delta     <- st_intersection(TuleValley_SevierLake_Delta_Two, Tule_all)

# Helper column not needed in the output
TuleValley_SevierLake_Delta$mvFeatureId <- NULL

## 2.5 Match columns and map the four AOIs ----

# Match columns across the four AOIs so they can be combined
all_cols <- unique(c(
  names(PronePolygons_Ni80),
  names(SkullValley),
  names(PronePolygons_Si80),
  names(TuleValley_SevierLake_Delta)))

make_columns_match <- function(x, all_cols) {
  missing <- setdiff(all_cols, names(x))
  for (col in missing) x[[col]] <- NA
  x[, all_cols]}

PronePolygons_Ni80          <- make_columns_match(PronePolygons_Ni80, all_cols)
SkullValley                 <- make_columns_match(SkullValley, all_cols)
PronePolygons_Si80          <- make_columns_match(PronePolygons_Si80, all_cols)
TuleValley_SevierLake_Delta <- make_columns_match(TuleValley_SevierLake_Delta, all_cols)

# Map of the four AOIs with the Great Salt Lake sub-regions
mapview(PronePolygons_Si80,
        col.regions = "lightblue",
        color = "blue",
        alpha.regions = 0.4,
        layer.name = "i80 South") +

  mapview(PronePolygons_Ni80,
          col.regions = "green",
          color = "darkgreen",
          alpha.regions = 0.4,
          layer.name = "i80 North") +

  mapview(SkullValley,
          col.regions = "purple",
          color = "purple",
          alpha.regions = 0.4,
          layer.name = "Skull Valley") +

  mapview(TuleValley_SevierLake_Delta,
          col.regions = "red",
          color = "red",
          alpha.regions = 0.4,
          layer.name = "TuleValley SevierLake Delta") +

  mapview(gsl_all,
          col.regions = "yellow",
          color = "yellow",
          alpha.regions = 0.4,
          layer.name = "GSL Area")

## 2.6 Export the four AOI shapefiles and read them back ----

# 1) North of I-80, west of Great Salt Lake
st_write(PronePolygons_Ni80, file.path(dir$outputs, "PronePolygons_Ni80.shp"), append = FALSE, delete_dsn = TRUE)

# 2) Skull Valley
st_write(SkullValley, file.path(dir$outputs, "PronePolygons_SkullValley.shp"), append = FALSE, delete_dsn = TRUE)

# 3) South of I-80, west of Great Salt Lake, not including Tule Valley, Sevier Lake etc.
st_write(PronePolygons_Si80, file.path(dir$outputs, "PronePolygons_Si80.shp"), append = FALSE, delete_dsn = TRUE)

# 4) Tule Valley, Sevier Lake and the areas near Delta
st_write(TuleValley_SevierLake_Delta, file.path(dir$outputs, "PronePolygons_TuleValley_SevierLake_Delta.shp"), append = FALSE, delete_dsn = TRUE)

# Read the written files back as a check
PronePolygons_Ni80_test <- st_read(file.path(dir$outputs, "PronePolygons_Ni80.shp"))

PronePolygons_skull_test <- st_read(file.path(dir$outputs, "PronePolygons_SkullValley.shp"))

PronePolygons_Si80_test <- st_read(file.path(dir$outputs, "PronePolygons_Si80.shp"))

PronePolygons_TuleValley_SevierLake_Delta_test <- st_read(file.path(dir$outputs, "PronePolygons_TuleValley_SevierLake_Delta.shp"))

# Software versions
sessionInfo()

# End code ----
