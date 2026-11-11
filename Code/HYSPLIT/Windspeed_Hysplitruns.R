# Author: Logan Haviland
# Purpose:Run HYSPLIT Model
# ------------------------------------
#########################Preliminaries##########################################
rm(list = ls())

### Packages (load all of them at the beginning)
want <- c("dplyr", "tidyr", "foreach", "doParallel", "parallel")

# install it if you don't have it
need <- want[!(want %in% installed.packages()[, "Package"])]
if (length(need)) install.packages(need)

# require what you want
sapply(want, function(i) require(i, character.only = TRUE))

# clean up
rm(need, want)
options(timeout = 10000)

#########################Settings###############################################
# Region-year to run
RUN_YEAR   <- 2024
RUN_REGION <- "utt_west"

# Folder paths are read from environment variables (set them in a .Renviron
# file, see README), so no machine-specific paths are stored in this script.
get_path <- function(var) {
  p <- Sys.getenv(var)
  if (p == "") stop(var, " is not set. Add it to your .Renviron file (see README).", call. = FALSE)
  sub("/+$", "", p)  # drop any trailing slash
}

MET_DIR    <- get_path("HYSPLIT_MET_DIR")     # folder with wrf_<YEAR>.ARL files
POINTS_DIR <- get_path("HYSPLIT_POINTS_DIR")  # folder with <YEAR>_<REGION>_finalpoints.csv
WORK_ROOT  <- get_path("HYSPLIT_WORK_DIR")    # each run goes in <WORK_ROOT>/<YEAR>_<REGION>/

RUN_NAME   <- paste0(RUN_YEAR, "_", RUN_REGION)
WORK_DIR   <- file.path(WORK_ROOT, RUN_NAME)
OUTPUT_DIR <- file.path(WORK_DIR, "s")
POINTS_CSV <- file.path(POINTS_DIR, paste0(RUN_NAME, "_finalpoints.csv"))
MET_FILE   <- paste0("wrf_", RUN_YEAR, ".ARL")

dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)

#############Parallel Final Version#############################################

#Set working directories
setwd(WORK_DIR)


# Read in final points which are a 5% sample from all the GEE generated points originally
finalpoints <- read.csv(POINTS_CSV)
finalpoints <- finalpoints[, !grepl("^ws10", names(finalpoints))]

# Filter windspeed columns
ws_cols <- grep("^ws\\d{6}$", names(finalpoints), value = TRUE)

cat("There are", nrow(finalpoints), "files in the bin.\n")

# Pivot to long format
long_df <- finalpoints %>%
  select(pnt_id, region, year, LAT, LON, all_of(ws_cols)) %>%
  pivot_longer(
    cols = all_of(ws_cols),
    names_to = "ws_time",
    values_to = "wind_speed"
  ) %>%
  filter(!is.na(wind_speed), wind_speed >= 7.00, wind_speed < 104)

cat("There are", nrow(long_df), "files in the bin.\n")

list.files()
# Delete old ASCDATA.CFG if it exists
if (file.exists("ASCDATA.CFG")) file.remove("ASCDATA.CFG")

ascdata <- c(
  "-90.0   -180.0  lat/lon of lower left corner",
  "1.0     1.0     lat/lon spacing in degrees",
  "180     360     lat/lon number of data points",
  "2               default land use category",
  "0.2             default roughness length (m)",
  paste0(WORK_DIR, "/bdyfiles/  directory of files")
)
writeLines(ascdata, "ASCDATA.CFG")
list.files()
# Parallel
num_cores <- min(detectCores() - 1,96)
#print(num_cores)
cl <- makeCluster(num_cores)
registerDoParallel(cl)

# Parallel For Loop 
foreach(i = 1:nrow(long_df), .packages = c("dplyr")) %dopar% {
  row <- long_df[i, ]
  
  LAT <- row$LAT
  LON <- row$LON
  PtID <- row$pnt_id
  REG <- row$region
  YEAR <- row$year
  SYR <- substr(YEAR, 3, 4)
  MMDDHH <- sub("^ws", "", row$ws_time)
  SMO <- substr(MMDDHH, 1, 2)
  SDA <- substr(MMDDHH, 3, 4)
  SHR <- substr(MMDDHH, 5, 6)
  WS <- row$wind_speed
  LVL <- "10.0"
  RUN <- "144"
  TOP <- "10000.0"
  MET <- paste0(MET_DIR, "/")  # HYSPLIT needs the trailing slash
  DAT <- MET_FILE
  WRK <- WORK_DIR
  
  suffix <- paste0(PtID, "_", MMDDHH)
  output_dir <- paste0(OUTPUT_DIR, "/")  # HYSPLIT needs the trailing slash
  
  # Create isolated temp folder for HYSPLIT config files
  temp_dir <- file.path(WRK, "temp", suffix)
  dir.create(temp_dir, recursive = TRUE, showWarnings = FALSE)
  
  # Copy ASCDATA.CFG if needed
  file.copy(file.path(WRK, "ASCDATA.CFG"), file.path(temp_dir, "ASCDATA.CFG"), overwrite = TRUE)
  
  # Write CONTROL file
  control_file <- file.path(temp_dir, "CONTROL")
  control_content <- c(
    paste(SYR, SMO, SDA, SHR),
    "1",
    paste(LAT, LON, LVL),
    RUN,
    "0",
    TOP,
    "1",
    MET,
    DAT,
    output_dir,
    paste0("traj_", YEAR, "_", REG, "_", PtID, "_", SMO, SDA, SHR, "_", WS, ".csv")
  )
  writeLines(control_content, control_file)
  
  # HYSPLIT run from temp dir
  old_wd <- getwd()
  setwd(temp_dir)
  system2("hyts_std", stdin = "CONTROL")
  setwd(old_wd)
  
  # Cleanup temp dir (optional)
  unlink(temp_dir, recursive = TRUE)
}

stopCluster(cl)
# End