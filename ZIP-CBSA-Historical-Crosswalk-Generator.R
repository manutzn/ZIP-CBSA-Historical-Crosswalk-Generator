# ------------------------------------------------------------------------------
# ZIP-CBSA-Historical-Crosswalk-Generator
#
# Script to construct a historical quarterly dataset mapping USPS ZIP codes to
# their corresponding CBSA codes, utilizing data from the HUD USPS ZIP Code
# Crosswalk Files API.
#
# Author: Manu García, Washington University in St. Louis
# Date: 09/25/2024
# ------------------------------------------------------------------------------

# Clear the workspace
rm(list = ls())

# Load necessary libraries
library(httr)
library(jsonlite)
library(dplyr)
library(data.table)
library(tidyr)

# ------------------------------------------------------------------------------
# Set up API Key and Endpoint
# ------------------------------------------------------------------------------

# Load the API key securely

key <- 'your_api_key_here'

# HUD USPS ZIP Code Crosswalk Files API endpoint
url <- "https://www.huduser.gov/hudapi/public/usps"

# ------------------------------------------------------------------------------
# Define Parameters
# ------------------------------------------------------------------------------

# Set the output path (update this to your desired path)
output_path <- "path/to/your/output/directory"

# Ensure the output directory exists
if (!dir.exists(output_path)) {
  dir.create(output_path, recursive = TRUE)
}

# Define the years and quarters to download
years <- 2010:2023
quarters <- 1:4

# Define the crosswalk type (type 3: zip-cbsa)
type <- 3
type_name <- "zip_cbsa"

# ------------------------------------------------------------------------------
# Function Definitions
# ------------------------------------------------------------------------------

# Function to download crosswalk data for a given year and quarter
download_crosswalk_data <- function(type, query, year, quarter, key) {
  # Make the API request
  response <- httr::GET(
    url,
    query = list(
      type = type,
      query = query,
      year = year,
      quarter = quarter
    ),
    add_headers(Authorization = paste("Bearer", key))
  )
  
  # Check for HTTP errors
  if (httr::http_error(response)) {
    warning(
      sprintf(
        "HTTP error %s for year %d quarter %d type %d",
        httr::status_code(response), year, quarter, type
      )
    )
    return(NULL)
  }
  
  # Parse the JSON content
  output <- httr::content(response, as = "text", encoding = "UTF-8")
  parsed_output <- fromJSON(output)
  
  # Extract the data
  data <- as.data.frame(parsed_output$data)
  
  # Remove unnecessary columns if present
  data$results.city <- NULL
  data$results.state <- NULL
  
  return(data)
}

# ------------------------------------------------------------------------------
# Main Processing Loop
# ------------------------------------------------------------------------------

# Initialize an empty list to store data
data_list <- list()

# Loop over years and quarters
for (year in years) {
  for (quarter in quarters) {
    message(sprintf("Processing year %d, quarter %d, type %d", year, quarter, type))
    
    # Download the data
    temp_data <- download_crosswalk_data(type, "All", year, quarter, key)
    
    # Check if data was successfully downloaded
    if (!is.null(temp_data)) {
      # Add year and quarter columns if not present
      temp_data$year <- year
      temp_data$quarter <- quarter
      
      # Append to the list
      data_list[[length(data_list) + 1]] <- temp_data
    } else {
      warning(sprintf("No data for year %d quarter %d type %d", year, quarter, type))
    }
  }
}

# Combine all data into one data frame
if (length(data_list) > 0) {
  data_combined <- bind_rows(data_list)
  
  # Rename columns based on type
  colnames(data_combined) <- c(
    "year", "quarter", "input", "crosswalk_type", "zip_code", "cbsa_code", 
    "res_ratio", "bus_ratio", "oth_ratio", "tot_ratio")
  
  # Convert to data.table for efficient processing
  setDT(data_combined)
  
  # Save the data in RDS and CSV formats
  saveRDS(
    data_combined,
    file = file.path(output_path, paste0("quarterly_crosswalk_", type_name, ".rds"))
  )
  fwrite(
    data_combined,
    file = file.path(output_path, paste0("quarterly_crosswalk_", type_name, ".csv"))
  )
  
  message(sprintf("Saved data for crosswalk type: %s", type_name))
} else {
  warning(sprintf("No data downloaded for crosswalk type: %s", type_name))
}

# ------------------------------------------------------------------------------
# End of Script
# ------------------------------------------------------------------------------

