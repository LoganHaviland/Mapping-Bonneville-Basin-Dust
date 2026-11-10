# Mapping-Bonneville-Basin-Dust
Contains the custom code for mapping dust from the Bonneville Basin


[![DOI](https://zenodo.org/badge/1398722837.svg)](https://doi.org/10.5281/zenodo.23070517)


**Note:** This dataset has utilized a variety of data sources, software, and 
This project has used the following:

- R: Version 4.4.3
  - For most coding purposes

- Google Earth Engine
  - For satellite/aerial imagery
  
- Google Cloud Storage
  - For storage purposes randomly sampled points, shapefiles, and trajectories
  
- Various nodes at the University of Utah's Center of High Performance Computing
  - For both storage purposes and use of parallel computing resources


This repo is organized with all of the code and its associated README in the 'Code' Folder. 

**PronePolygon_Code** contains the script that determines the potential hotspot areas in the Greater Bonneville Basin. Of note in the README is a reference to 4 final areas - this was later split into 8 which is mentioned in the manuscript. This change was made for two main reasons; the first was differences within those areas (Sevier Lake Proper versus surrounding Delta), the second was for computational feasibility. Areas in the West Desert are both large and generally dry resulting in a number of points that was not feasible to run all at once. Hence we split this into sub regions. We believe little harm comes from this as there are both valid reasons for doing it and we can aggregate and combine those trajectories to achieve an unsplit version as well.

**Earth Engine python colab code** contains the scripts for sampling and getting satellite imagery (Landsat) for our various dust hotspot regions and then obtaining the different indices (NDWI, and EVI). 

**Max Elevation for GSL** is the script that obtains all of the maximum water dates for the GSL proper using the USDA - USGS package `dataRetrieval`. 

The **HYSPLIT** folder contains the custom code to run the HYSPLIT program for all of our region and years. 

Separate README files are provided for the different parts of the code process. If the code does not work for your system please contact the author at logan.haviland@usu.edu.
Credentials and accounts will be required for Google Cloud Storage with substantial storage constraints and very long processing times for the HYSPLIT model.
