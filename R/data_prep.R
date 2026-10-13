prepare_requests <- function(raw) {
  names(raw) <- toupper(names(raw))
  required <- c("SERVICEREQUESTID", "SERVICETYPECODEDESCRIPTION", "ADDDATE", "RESOLUTIONDATE", "SERVICEDUEDATE", "SERVICEORDERSTATUS", "PRIORITY", "WARD")
  missing <- setdiff(required, names(raw))
  if (length(missing)) stop("The source data is missing expected fields: ", paste(missing, collapse = ", "))

  parse_arcgis_date <- function(x) {
    if (inherits(x, "POSIXt")) return(as.POSIXct(x, tz = "UTC"))
    if (is.numeric(x) || all(grepl("^[0-9]+$", na.omit(as.character(x))))) {
      return(as.POSIXct(as.numeric(x) / 1000, origin = "1970-01-01", tz = "UTC"))
    }
    as.POSIXct(x, tz = "UTC")
  }
  add_date <- parse_arcgis_date(raw$ADDDATE)
  resolution_date <- parse_arcgis_date(raw$RESOLUTIONDATE)
  due_date <- parse_arcgis_date(raw$SERVICEDUEDATE)

  source_service_type <- ifelse(is.na(raw$SERVICETYPECODEDESCRIPTION) | raw$SERVICETYPECODEDESCRIPTION == "", "Unspecified", as.character(raw$SERVICETYPECODEDESCRIPTION))
  # The source contains this spelling variant; retain it for audit and group it with the intended label.
  service_type <- gsub("Admistration", "Administration", source_service_type, fixed = TRUE)

  data.frame(
    request_id = as.character(raw$SERVICEREQUESTID),
    service_type_source = source_service_type,
    service_type = service_type,
    request_date = as.Date(add_date, tz = "UTC"),
    resolution_date = as.Date(resolution_date, tz = "UTC"),
    due_date = as.Date(due_date, tz = "UTC"),
    status = as.character(raw$SERVICEORDERSTATUS),
    priority = as.character(raw$PRIORITY),
    ward = ifelse(is.na(raw$WARD) | raw$WARD == "", NA_character_, as.character(raw$WARD)),
    turnaround_days = as.numeric(as.Date(resolution_date, tz = "UTC") - as.Date(add_date, tz = "UTC")),
    stringsAsFactors = FALSE
  ) |>
    dplyr::filter(!is.na(request_date), request_date >= as.Date("2025-01-01"), request_date < as.Date("2026-01-01")) |>
    dplyr::distinct(request_id, .keep_all = TRUE)
}
