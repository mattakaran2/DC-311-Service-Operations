# Download the published 2025 DC 311 CSV and retain only the fields needed here.
# Address, free-text details, inspector names, and coordinates are discarded at import.
source(file.path("R", "data_prep.R"))

dir.create(file.path("data", "raw"), recursive = TRUE, showWarnings = FALSE)
raw_path <- file.path("data", "raw", "dc_311_2025.csv")
source_url <- "https://opendata.dc.gov/api/download/v1/items/85a2474b468b4dfeb84f9165210fe5a3/csv?layers=18"
if (!file.exists(raw_path)) {
  message("Downloading the public DC 311 CSV. This file is large; it is kept locally and excluded from Git.")
  download.file(source_url, raw_path, mode = "wb", quiet = FALSE)
}

fields <- c("SERVICEREQUESTID", "SERVICETYPECODEDESCRIPTION", "ADDDATE", "RESOLUTIONDATE", "SERVICEDUEDATE", "SERVICEORDERSTATUS", "PRIORITY", "WARD")
header <- names(read.csv(raw_path, nrows = 0, check.names = FALSE, fileEncoding = "UTF-8-BOM"))
if (!all(fields %in% header)) stop("The DC CSV no longer has the expected fields: ", paste(setdiff(fields, header), collapse = ", "))
column_types <- stats::setNames(rep("NULL", length(header)), header)
column_types[fields] <- "character"
message("Reading only the ", length(fields), " fields used by the dashboard...")
raw <- read.csv(raw_path, check.names = FALSE, colClasses = column_types, fileEncoding = "UTF-8-BOM", na.strings = c("", "<Null>"))

clean <- prepare_requests(raw)
dir.create(file.path("data", "processed"), recursive = TRUE, showWarnings = FALSE)
saveRDS(clean, file.path("data", "processed", "dc_311_2025.rds"), compress = "xz")
message("Saved ", nrow(clean), " unique requests to data/processed/dc_311_2025.rds")
