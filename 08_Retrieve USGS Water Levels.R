# Name: 08_Retrive USGS Water Levels.R
# Logan Haviland
# RStudio - R version 4.4.1
# Date: January 6th, 2025

# Purpose: To obtain the maximum level of the Great Salt Lake from 1998-2024
# for 4 quadrants of the GSL Split in half North to South by the Causeway.
# Output and results are used to as the maximum water level date to restrict our GEE model
# around that date +- 30 days about.

#### Packages ####
install.packages("dataRetrieval")

library(dataRetrieval)
library(dplyr)
##### Preliminary Checks ####
# See what dates are available from each monitoring site and what parameters are offered.
# Example is for Saltair, monitoring site 10010000

site <- "10010000" #410401112134801"
data_available <- whatNWISdata(siteNumber = site) 
### Important NWIS servers are slated for decommission. 
### Migrate to read_waterdata_ts_meta

data_available_NWIS <- data_available |> 
  select(data_type_cd, parm_cd, stat_cd, 
         begin_date, end_date, count_nu) |> 
  filter(!data_type_cd %in% c("qw", "ad")) |> 
  arrange(data_type_cd)
##### Loop ####

# Create a list of siteNumbers
monitoringsite_numbers <- c("10010000", "10010024", "410401112134801", "10010100", "10010027", "10010060", "10126000")
monitoringsite_numbers <- c("10010000")

# Create a empty data frame to store the results
lakelevel_results <- data.frame(SiteNumber = character(), Year = character(), Maximum_Height = numeric(), Date = as.Date(character()))
# Create my parameters

### Parameters
## 62614 - This is water surface elevation
## 00065 - Gage Height
## 00060 - Discharge
## Some site only have some parameters for certain years or at all.

parameterCd <- "62614" # Water surface Elevation
start_year <- "1998"
end_year <- "2024"

# Loop over the monitoring sites
for (siteNumber in monitoringsite_numbers) {
  # Loop over the years of 1998-2024
  for (year in start_year:end_year) {
    startDate <- paste0(year,"-01-01")
    endDate <- paste0(year, "-12-31")
    
    # Feed them into one
    lakeData <- readNWISdv(siteNumber, parameterCd, startDate, endDate)
    
    # Find the maximum height and corresponding day
    maxRow <- lakeData[which.max(lakeData$X_62614_00003), ]
    maxHeight <- maxRow$X_62614_00003
    maxDate <- maxRow$Date 
    
    # Put results into the Lake data frame
    lakelevel_results <- rbind(lakelevel_results, 
                               data.frame(SiteNumber = siteNumber, Year = year, Maximum_Height = maxHeight, Date = maxDate))
  }
}
# print(lakelevel_results)
siteNumber <- "1001000"
startDate <- "1998-01-01"
endDate <- "2024-12-31"
##### End Code Block

########
# For Parameter Code 00065 - Gage Height
# Create a list of siteNumbers
monitoringsite_numbers <- c("410401112134801")

# Create a empty data frame to store the results
lakelevel_results <- data.frame(SiteNumber = character(), Year = character(), Maximum_Height = numeric(), Date = as.Date(character()))
# Create my parameters
parameterCd <- "00060" # Discharge
start_year <- "2003"
end_year <- "2024"

# Loop over the monitoring sites
for (siteNumber in monitoringsite_numbers) {
  # Loop over the years of 1998-2024
  for (year in start_year:end_year) {
    startDate <- paste0(year,"-01-01")
    endDate <- paste0(year, "-12-31")
    
    # Feed them into one
    lakeData <- readNWISuv(siteNumber, parameterCd, startDate, endDate)
    
    # Find the maximum height and corresponding day
    maxRow <- lakeData[which.max(lakeData$X_00060_00000), ]
    maxHeight <- maxRow$X_00060_00000
    maxDate <- maxRow$dateTime  
    
    # Put results into the Lake data frame
    lakelevel_results <- rbind(lakelevel_results, 
                               data.frame(SiteNumber = siteNumber, Year = year, Maximum_Height = maxHeight, Date = maxDate))
  }
}

########