# Wind-Speed-Triggered HYSPLIT Trajectories

Windspeed_Hysplitruns.R runs forward HYSPLIT trajectories in parallel from a set of sample points. It starts one trajectory at each point for every hour when the wind speed there is at least 7 m/s.

## What it does

1.  Reads a CSV of sample points with hourly wind speeds for one region and year.
2.  Keeps every point-hour with wind speed of at least 7 m/s and below 104 m/s.
3.  Writes a HYSPLIT `CONTROL` file for each point-hour and runs `hyts_std`, spread across CPU cores.
4.  Saves one trajectory file per run.

## Requirements

-   [HYSPLIT](https://www.ready.noaa.gov/HYSPLIT.php), with `hyts_std` on your `PATH`
-   Meteorological data in ARL format, one file per year, named `wrf_<YEAR>.ARL`
-   HYSPLIT's `bdyfiles` folder (land-use and roughness files) inside the run folder
-   R with `dplyr`, `tidyr`, `foreach` and `doParallel` (installed automatically if missing)

## Setup

The script reads folder locations from environment variables, so no machine-specific paths are stored in the code. Add these lines to a file named `.Renviron` in your home directory, then restart R:

```         
HYSPLIT_MET_DIR=/path/to/met_data
HYSPLIT_POINTS_DIR=/path/to/finalpoints
HYSPLIT_WORK_DIR=/path/to/run_folders
```

| Variable | Folder that holds |
|----|----|
| `HYSPLIT_MET_DIR` | The `wrf_<YEAR>.ARL` meteorology files |
| `HYSPLIT_POINTS_DIR` | The `<YEAR>_<REGION>_finalpoints.csv` input files |
| `HYSPLIT_WORK_DIR` | One run folder per region-year, created as `<YEAR>_<REGION>/` |

If you keep `.Renviron` in the project folder instead, add it to `.gitignore`.

Then set the region and year at the top of the script:

``` r
RUN_YEAR   <- 2024
RUN_REGION <- "utt_west"
```

## Input

`<HYSPLIT_POINTS_DIR>/<YEAR>_<REGION>_finalpoints.csv`, one row per sample point:

| Column | Description |
|----|----|
| `pnt_id` | Unique point ID |
| `region` | Region code |
| `year` | Year |
| `LAT`, `LON` | Point location in decimal degrees |
| `wsMMDDHH` | Wind speed (m/s) for one hour. For example, `ws030622` is March 6 at 22:00. HYSPLIT reads these start times as UTC. |

Columns beginning with `ws10` (October) are dropped before filtering as we are focused solely on March - September. October marks the beginning of a new water year.

## Usage

``` bash
Rscript Windspeed_Hysplitruns.R
```

The script uses all available cores minus one, up to 96. This can be changed as needed.

## Output

Trajectories are written to `<HYSPLIT_WORK_DIR>/<YEAR>_<REGION>/s/`, one file per run:

```         
traj_<YEAR>_<REGION>_<pnt_id>_<MMDDHH>_<windspeed>.csv
```

Despite the `.csv` extension, these files are in HYSPLIT's standard trajectory text format (tdump).

## HYSPLIT settings

| Setting             | Value                       |
|---------------------|-----------------------------|
| Start height        | 10 m above ground           |
| Run length          | 144 hours (6 days), forward |
| Vertical motion     | Model vertical velocity     |
| Top of model domain | 10,000 m                    |
| Meteorology         | WRF 27 km, ARL format       |
