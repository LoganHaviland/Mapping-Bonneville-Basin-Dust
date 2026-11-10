# Annual Maximum Water Levels at Great Salt Lake Gages (1998–2024)

Uses R Version 4.4.3 and the 'dataRetrieval' package version 2.7.23

Retrieve_USGS_Water_Levels.R downloads USGS data for seven Great Salt Lake gages and returns, for each site and year, the annual maximum and the date it occurred for:

| Variable                            | Parameter code |
|-------------------------------------|----------------|
| Water-surface elevation (elevation) | 62614          |
| Discharge (discharge)               | 00060          |
| Gage height (gage_height)           | 00065          |

Not every site has every variable; missing ones are left blank. The maximum date anchors the GEE model window (date ± 30 days).

## How to run

Run the whole script from the top (after a restart, always from the top):

``` r
source("Retrieve_USGS_Water_Levels.R")
```

No API key is needed.

## Output

`output/gsl_annual_max.csv` has one row per site-year:

| Column | Description |
|------------------------------------|------------------------------------|
| SiteNumber | USGS site number. |
| Year | 1998–2024. |
| elevation_Max, elevation_Date | Annual max water-surface elevation and its date. |
| discharge_Max, discharge_Date | Annual max discharge and its date. |
| gage_height_Max, gage_height_Date | Annual max gage height and its date. |

If the maximum occurs on more than one day, the earliest date is reported. The same table is left in R as lakelevel_results. Any site with no data at all is listed in the console.

## Missing years: Saltair fallback

If a region's gage has no data for a given year, that year's maximum and date from **Saltair (site 10010000)** are used instead.

## How it works

1.  **Daily values.** One read_waterdata_daily() request per site gets the daily means (statistic 00003) of all three parameters for 1998–2024. Sites or parameters without data just return nothing.
2.  **Continuous values.** For site-parameters listed in uv_series (default: discharge at 410401112134801, which has only 15-minute data), read_waterdata_continuous() is called once per year. The service allows at most 3 years per request.
3.  **Annual maxima.** For each site, parameter, and year, the script takes the maximum and its date. If both daily and continuous data exist, the daily value is used.
4.  **Reshape and save.** One row per site-year, with a max and date column for each variable, written to CSV.

If a download fails, the script prints a message naming the site and keeps going.

## Settings (top of the script)

| Setting | Meaning |
|------------------------------------|------------------------------------|
| sites | USGS site numbers. |
| pcodes | Parameter codes. The names become column prefixes. |
| years | Years to report (1998:2024). |
| tz | Time zone for continuous data (America/Denver). |
| uv_series | Site-parameter pairs to pull from continuous data. Add a row if another site only has 15-minute data. |
| out_file | Output path. |

## Notes

-   **Daily means.** Daily-based maxima are the highest daily mean, as in the original script. Change statistic_id to 00001 in get_daily() for the daily maximum.
-   **Continuous maxima** are the highest single 15-minute reading in the year.
-   **Data access.** USGS data only comes from its web services. dataRetrieval calls them for you; no API key is required.
