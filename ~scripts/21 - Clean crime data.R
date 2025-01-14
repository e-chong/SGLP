##########################################################################
# This script:
# 1. Splits the gun crimes 
# 2. Geocodes observations for Virginia Beach
# 3. Cleans the gun crime data by:
#   (a) parsing occurrence date and reported date and
#         adding a year column for rolling windows.
#   (b) documenting cleaning steps for every city
#       NB: For each city, I checked lon/lat ranges and clean_occur_date 
#           and clean_report_date for sensible values for each
#   (c) removing years with very few observations
# 4. Flattens the list into a dataframe
# 5. Creates an sf version of the crime data in list form
# 6. #5 above, but with each city's crimes split into nested dataframes for each year
#
# Exports: 
# 1. guns_list as 21_guns_list.rds
# 2. guns_clean as 21_guns_clean.rds
# 3. guns_list_shp as 21_guns_list_shp.rds
# 4. guns_list_shp_byYear as 21_guns_list_shp_byYear.rds
#
# To-do:
# 1. 
##########################################################################

## 1. ----
guns_list <- split(guns_df,
                   f = guns_df$city)

## 2. ----
# guns_list$`Virginia Beach` <- guns_list$`Virginia Beach` %>% 
#   unite("tmp_address", loc, city, state, sep = ", ", remove = FALSE) %>% 
#   dplyr::select(-c(lat, lon)) %>% 
#   mutate_geocode(tmp_address,
#                  output = "latlon",
#                  source = "google") %>% 
#   dplyr::select(all_of(names(guns_df)))
# 
# write_csv(guns_list$`Virginia Beach`,
#           file.path(data_dir, 
#                     "Individual_City_Dataset/VirginiaBeach_Virginia/clean_data/virginiabeach_firearm_16_20_geocoded.csv"))

guns_list$`Virginia Beach` <- read_csv(file.path(data_dir, 
                                                 "Individual_City_Dataset/VirginiaBeach_Virginia/clean_data/virginiabeach_firearm_16_20_geocoded.csv")) %>% 
  mutate(incidentID = as.character(incidentID),
         reportdate = as.character(reportdate),
         occurdate = as.character(occurdate))

## 3a. ----
plan(multiprocess)
# this takes a while
guns_list <- future_map(guns_list,
                        ~ .x %>% 
                          mutate(clean_occur_date = anydate(occurdate), # use built-in formats from anytime package
                                 # correct some incorrectly parsed observations
                                 clean_occur_date = case_when(occurdate == "1" ~ as.Date(NA),
                                                              clean_occur_date < as.Date("1900-01-01") ~ as.Date(NA), 
                                                              is.na(clean_occur_date) &
                                                                str_detect(occurdate,
                                                                           ".*\\d+/\\d+/\\d+.*") ~ # e.g "12/3/15", "12/3/15 1600" 
                                                                as.Date(occurdate, "%m/%d/%y"),
                                                              TRUE ~ clean_occur_date),
                                 clean_report_date = anydate(reportdate),
                                 clean_report_date = case_when(reportdate == "1" ~ as.Date(NA),
                                                               clean_report_date < as.Date("1900-01-01") ~ as.Date(NA),
                                                               is.na(clean_report_date) &
                                                                 str_detect(reportdate,
                                                                            ".*\\d+/\\d+/\\d+.*") ~ # e.g "12/3/15", "12/3/15 1600"
                                                                 as.Date(reportdate, "%m/%d/%y"),
                                                               TRUE ~ clean_report_date),
                                 year = ifelse(!is.na(clean_occur_date),
                                               lubridate::year(clean_occur_date),
                                               lubridate::year(clean_report_date))),
                        .progress = TRUE)

# 3b. ----
### Atlanta - looks fine

### Auburn - looks fine

### Baltimore - looks fine

### Baton Rouge - looks fine

### Boston - some coord values to be turned to NA
guns_list$Boston <- guns_list$Boston %>%
  mutate(lon = ifelse(lon %in% c("0.0", "0", "-1"), NA, lon),
         lat = ifelse(lat %in% c("0.0", "0", "-1"), NA, lat))

### Chicago - some points are located in Missouri. Change to NA.
guns_list$Chicago <- guns_list$Chicago %>%
  mutate(lat_tmp = as.numeric(lat),
         lon = ifelse(lat_tmp < 40., NA_character_, lon),
         lat = ifelse(lat_tmp < 40., NA_character_, lat)) %>% 
  dplyr::select(-c(lat_tmp))

### Cincinnati - looks fine

### Columbia - looks fine

### Dallas - looks fine

### Denver - some points with lons/lats near 0. Change to NA
guns_list$Denver <- guns_list$Denver %>%
  mutate(lat_tmp = as.numeric(lat),
         lon = ifelse(lat_tmp < 39., NA_character_, lon),
         lat = ifelse(lat_tmp < 39., NA_character_, lat)) %>% 
  dplyr::select(-c(lat_tmp))

### Detroit - some lons/lats in Ohio or near Inf. Change to NA
guns_list$Detroit <- guns_list$Detroit %>%
  mutate(lat_tmp = as.numeric(lat),
         lon_tmp = as.numeric(lon),
         lon = ifelse(lat_tmp < 40. | lat_tmp > 43. |
                        lon_tmp > 0., NA_character_, lon),
         lat = ifelse(lat_tmp < 40. | lat_tmp > 43. |
                        lon_tmp > 0., NA_character_, lat)) %>% 
  dplyr::select(-c(lat_tmp, lon_tmp))

### Gainesville - Some points well outside of Gainesville but still in Florida. Change to NA
guns_list$Gainesville <- guns_list$Gainesville %>%
  mutate(lat_tmp = as.numeric(lat),
         lon_tmp = as.numeric(lon),
         lon = ifelse(lat_tmp < 29.5, NA_character_, lon),
         lat = ifelse(lat_tmp < 29.5, NA_character_, lat)) %>% 
  dplyr::select(-c(lat_tmp, lon_tmp))

### Hartford - looks fine

### Indianapolis - Some points in TN. Change to NA
guns_list$Indianapolis <- guns_list$Indianapolis %>%
  mutate(lat_tmp = as.numeric(lat),
         lon_tmp = as.numeric(lon),
         lon = ifelse(lat_tmp < 39., NA_character_, lon),
         lat = ifelse(lat_tmp < 39., NA_character_, lat)) %>% 
  dplyr::select(-c(lat_tmp, lon_tmp))

### Kansas City - Some points far outside KC. Change to NA
guns_list$`Kansas City` <- guns_list$`Kansas City` %>%
  mutate(lat_tmp = as.numeric(lat),
         lon_tmp = as.numeric(lon),
         lon = ifelse(lon_tmp > -93. | lon_tmp < -95., NA_character_, lon),
         lat = ifelse(lon_tmp > -93. | lon_tmp < -95., NA_character_, lat)) %>% 
  dplyr::select(-c(lat_tmp, lon_tmp))

### Lincoln - Some points far outside Lincoln. Change to NA
guns_list$Lincoln <- guns_list$Lincoln %>%
  mutate(lat_tmp = as.numeric(lat),
         lon_tmp = as.numeric(lon),
         lon = ifelse(lat_tmp > 41., NA_character_, lon),
         lat = ifelse(lat_tmp > 41., NA_character_, lat)) %>% 
  dplyr::select(-c(lat_tmp, lon_tmp))

### Little Rock - looks fine

### Los Angeles - A few 0 points. Change to NA
guns_list$`Los Angeles` <- guns_list$`Los Angeles` %>%
  mutate(lat_tmp = as.numeric(lat),
         lon_tmp = as.numeric(lon),
         lon = ifelse(lat_tmp < 30., NA_character_, lon),
         lat = ifelse(lat_tmp < 30., NA_character_, lat)) %>% 
  dplyr::select(-c(lat_tmp, lon_tmp))

### Louisville - Some points far outside Louisville. Change to NA
guns_list$Louisville <- guns_list$Louisville %>%
  mutate(lat_tmp = as.numeric(lat),
         lon_tmp = as.numeric(lon),
         lon = ifelse(lat_tmp < 37.5 | lat_tmp > 40.|
                        lon_tmp > -85. | lon_tmp < -86., NA_character_, lon),
         lat = ifelse(lat_tmp < 37.5 | lat_tmp > 40.|
                        lon_tmp > -85. | lon_tmp < -86., NA_character_, lat)) %>% 
  dplyr::select(-c(lat_tmp, lon_tmp))

### Madison - Some points far outside Madison. Change to NA
guns_list$Madison <- guns_list$Madison %>%
  mutate(lat_tmp = as.numeric(lat),
         lon_tmp = as.numeric(lon),
         lon = ifelse(lat_tmp < 42., NA_character_, lon),
         lat = ifelse(lat_tmp < 42., NA_character_, lat)) %>% 
  dplyr::select(-c(lat_tmp, lon_tmp))

### Minneapolis - Some 0s. Change to NA
guns_list$Minneapolis <- guns_list$Minneapolis %>%
  mutate(lat_tmp = as.numeric(lat),
         lon_tmp = as.numeric(lon),
         lon = ifelse(lat_tmp < 44., NA_character_, lon),
         lat = ifelse(lat_tmp < 44., NA_character_, lat)) %>% 
  dplyr::select(-c(lat_tmp, lon_tmp))

### Nashville - looks fine

### New York - looks fine

### Phoenix - looks fine

### Portland - looks fine

### Raleigh - some 0s. Changed to NA
guns_list$Raleigh <- guns_list$Raleigh %>%
  mutate(lat_tmp = as.numeric(lat),
         lon_tmp = as.numeric(lon),
         lon = ifelse(lat_tmp < 35., NA_character_, lon),
         lat = ifelse(lat_tmp < 35., NA_character_, lat)) %>% 
  dplyr::select(-c(lat_tmp, lon_tmp))


### Sacramento County - many points in the Pacific. Changed to NA

guns_list$`Sacramento County` <- guns_list$`Sacramento County` %>%
  mutate(lat_tmp = as.numeric(lat),
         lon_tmp = as.numeric(lon),
         lon = ifelse(lat_tmp < 38., NA_character_, lon),
         lat = ifelse(lat_tmp < 38., NA_character_, lat)) %>% 
  dplyr::select(-c(lat_tmp, lon_tmp))

### Saint Paul - some points far outside Saint Paul. Changed to NA
guns_list$`Saint Paul` <- guns_list$`Saint Paul` %>%
  mutate(lat_tmp = as.numeric(lat),
         lon_tmp = as.numeric(lon),
         lon = ifelse(lat_tmp < 44., NA_character_, lon),
         lat = ifelse(lat_tmp < 44., NA_character_, lat)) %>% 
  dplyr::select(-c(lat_tmp, lon_tmp))

### Salt Lake City - looks fine

### San Francisco - some lats near 90. Changed to NA
guns_list$`San Francisco` <- guns_list$`San Francisco` %>%
  mutate(lat_tmp = as.numeric(lat),
         lon_tmp = as.numeric(lon),
         lon = ifelse(lat_tmp > 38., NA_character_, lon),
         lat = ifelse(lat_tmp > 38., NA_character_, lat)) %>% 
  dplyr::select(-c(lat_tmp, lon_tmp))

### St Louis County - some points outside MO. Changed to NA
guns_list$`St Louis County` <- guns_list$`St Louis County` %>%
  mutate(lat_tmp = as.numeric(lat),
         lon_tmp = as.numeric(lon),
         lon = ifelse(lat_tmp > 39. | lat_tmp < 38., NA_character_, lon),
         lat = ifelse(lat_tmp > 39. | lat_tmp < 38., NA_character_, lat)) %>% 
  dplyr::select(-c(lat_tmp, lon_tmp))

### Tucson - looks fine

### Virginia Beach - one data point outside of Virginia Beach. Changed to NA
guns_list$`Virginia Beach` <- guns_list$`Virginia Beach` %>%
  mutate(lat_tmp = as.numeric(lat),
         lon_tmp = as.numeric(lon),
         lon = ifelse(lat_tmp < 36., NA_character_, lon),
         lat = ifelse(lat_tmp < 36., NA_character_, lat)) %>% 
  dplyr::select(-c(lat_tmp, lon_tmp))

## 3c. ----
### Atlanta
guns_list$Atlanta <- guns_list$Atlanta %>% 
  filter(year %!in% c(2006, 2008))

### Auburn
guns_list$Auburn <- guns_list$Auburn %>% 
  filter(year %!in% c(2017))

### Baltimore - looks fine

### Baton Rouge - looks fine

### Boston - looks fine

### Chicago - looks fine

### Cincinnati
guns_list$Cincinnati <- guns_list$Cincinnati %>% 
  filter(year %!in% c(2003, 2005))

### Columbia - looks fine

### Dallas - looks fine

### Denver - looks fine

### Detroit - crimes drop dramatically starting in 2017
guns_list$Detroit <- guns_list$Detroit %>% 
  filter(year %!in% c(2015, 2016))

### Gainesville - looks fine

### Hartford - looks fine

### Indianapolis - looks fine. crimes cut in half in 2013

### Kansas City - 2013 is much lower, and data is missing from 2014-2018

### Lincoln 
guns_list$Lincoln <- guns_list$Lincoln %>% 
  filter(year %in% c(2013:2020))

### Little Rock
guns_list$`Little Rock` <- guns_list$`Little Rock` %>% 
  filter(year %!in% c(2014))

### Los Angeles - looks fine

### Louisville - Note that 2003, first year, has much lower count
guns_list$Louisville$year %>% table()
guns_list$Louisville <- guns_list$Louisville %>% 
  filter(year %in% c(2003:2020))

### Madison 
guns_list$Madison <- guns_list$Madison %>% 
  filter(year %in% c(2005:2020))

### Minneapolis - looks fine

### Nashville
guns_list$Nashville <- guns_list$Nashville %>% 
  filter(year %in% c(2013:2020))

### New York
guns_list$`New York` <- guns_list$`New York` %>% 
  filter(year %in% c(2006:2019))

### Phoenix
guns_list$Phoenix <- guns_list$Phoenix %>% 
  filter(year %!in% c(2015))

### Portland - looks fine

### Raleigh - looks fine

### Sacramento County
guns_list$`Sacramento County` <- guns_list$`Sacramento County` %>% 
  filter(year %in% c(2007:2019))

### Saint Paul - looks fine

### Salt Lake City - looks fine

### San Francisco - looks fine

### St Louis County
guns_list$`St Louis County` <- guns_list$`St Louis County` %>% 
  filter(year %in% c(2015:2019))

### Tucson
guns_list$Tucson <- guns_list$Tucson %>% 
  filter(year %in% c(2009:2020))

### Virginia Beach - one data point outside of Virginia Beach. Changed to NA
guns_list$`Virginia Beach` <- guns_list$`Virginia Beach` %>% 
  filter(year %in% c(2016:2020))

## 4. ----
guns_clean <- bind_rows(guns_list)

## 5. ----
plan(multiprocess)
guns_list_shp <- future_map(guns_list,
                            ~ .x %>% 
                              filter(!is.na(lon),
                                     !is.na(lat)) %>% 
                              st_as_sf(coords = c("lon", "lat"),
                                       crs = 4326,
                                       remove = FALSE),
                            .progress = TRUE)

## 6. ----
guns_list_shp_byYear <- map(guns_list_shp,
                            ~ split(.x,
                                    .x$year))

## 1. Export as rds ----
# saveRDS(guns_list,
#         "~outputs/20/21_guns_list.rds")

## 2. Export as rds ----
# saveRDS(guns_clean,
#          "~outputs/20/21_guns_clean.rds")

## 3. Export as rds ----
# saveRDS(guns_list_shp,
#          "~outputs/20/21_guns_list_shp.rds")

## 4. Export as rds ----
# saveRDS(guns_list_shp_byYear,
#         "~outputs/20/21_guns_list_shp_byYear.rds")
