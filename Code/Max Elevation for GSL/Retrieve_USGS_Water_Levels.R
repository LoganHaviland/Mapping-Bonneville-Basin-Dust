# Name: Retrieve_USGS_Water_Levels.R
# Author: Logan Haviland
# RStudio - R version 4.4.3
# Last Updated: November 8, 2026
# Updated: October 28th, 2026 - simplified rewrite using dataRetrieval's new
#   read_waterdata_* functions (dataRetrieval >= 2.7.23). See README.md.

# Purpose: Annual maximum (and its date) of water-surface elevation (62614),
# discharge (00060) and gage height (00065) at Great Salt Lake gages,
# 1998-2024. The max date restricts our GEE model to that date +- 30 days.

#### Packages ####
library(dataRetrieval)   # needs >= 2.7.23
library(dplyr)
library(tidyr)
stopifnot(packageVersion("dataRetrieval") >= "2.7.23")

#### Settings ####
#USGS Monitoring Site Numbers
sites  <- c("10010000", "10010024", "410401112134801", "10010100",
            "10010027", "10010060", "10126000")
pcodes <- c(elevation = "62614", discharge = "00060", gage_height = "00065")
years  <- 1998:2024
tz     <- "America/Denver"

# Site-parameters with only 15-minute (continuous) data, no daily values
uv_series <- data.frame(site = "410401112134801", pcode = "00060")

out_file <- file.path("output", "gsl_annual_max.csv")

#### Download functions ####
# Daily means for one site, all three parameters, 1998-2024 (one request).
get_daily <- function(site) tryCatch(
  read_waterdata_daily(monitoring_location_id = paste0("USGS-", site),
                       parameter_code = unname(pcodes),
                       statistic_id   = "00003",
                       time           = paste0(range(years), c("-01-01", "-12-31")),
                       skipGeometry   = TRUE),
  error = function(e) { message("daily ", site, ": ", conditionMessage(e)); NULL })

# Continuous data for one site-parameter-year
get_continuous <- function(site, pcode, year) tryCatch(
  read_waterdata_continuous(monitoring_location_id = paste0("USGS-", site),
                            parameter_code = pcode,
                            time = as.POSIXct(paste0(year, c("-01-01 00:00", "-12-31 23:59")), tz = tz)),
  error = function(e) { message("continuous ", site, " ", year, ": ", conditionMessage(e)); NULL })

# Annual maximum and its date (earliest if tied) per site, parameter and year.
annual_max <- function(df) {
  if (!NROW(df)) return(NULL)
  if (inherits(df$time, "POSIXct")) attr(df$time, "tzone") <- tz   
  df |>
    mutate(value = as.numeric(value), Year = as.integer(format(time, "%Y"))) |>
    filter(!is.na(value), Year %in% years) |>
    arrange(time) |>
    summarise(Max  = max(value),
              Date = as.Date(format(time[which.max(value)], "%Y-%m-%d")),
              .by  = c(monitoring_location_id, parameter_code, Year))
}

#### Download ####
daily <- bind_rows(Filter(NROW, lapply(sites, get_daily)))

uv_jobs    <- merge(uv_series, data.frame(year = years))   # every site-parameter x year
continuous <- bind_rows(Filter(NROW, Map(get_continuous, uv_jobs$site, uv_jobs$pcode, uv_jobs$year)))

#### Annual maximum: one row per site-year, a max + date per variable ####
lakelevel_results <- bind_rows(annual_max(daily), annual_max(continuous)) |>
  distinct(monitoring_location_id, parameter_code, Year, .keep_all = TRUE) |>   # daily wins
  mutate(SiteNumber = sub("^USGS-", "", monitoring_location_id),
         Variable   = factor(names(pcodes)[match(parameter_code, pcodes)], levels = names(pcodes))) |>
  pivot_wider(id_cols = c(SiteNumber, Year), names_from = Variable,
              values_from = c(Max, Date), names_glue = "{Variable}_{.value}",
              names_vary = "slowest", names_sort = TRUE, names_expand = TRUE) |>
  arrange(SiteNumber, Year)

#### Save ####
dir.create(dirname(out_file), recursive = TRUE, showWarnings = FALSE)
write.csv(lakelevel_results, out_file, row.names = FALSE, na = "")

print(lakelevel_results)
