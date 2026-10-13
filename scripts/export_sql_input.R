args <- commandArgs(trailingOnly = TRUE)
output_path <- if (length(args)) args[[1]] else file.path("data", "processed", "sql_requests.csv")
input_path <- file.path("data", "processed", "dc_311_2025.rds")
if (!file.exists(input_path)) stop("Prepared data not found. Run Rscript scripts/refresh_data.R first.")

requests <- readRDS(input_path)
sql_requests <- requests[c(
  "request_id", "service_type_source", "service_type", "request_date",
  "resolution_date", "due_date", "status", "priority", "ward"
)]
write.csv(sql_requests, output_path, row.names = FALSE, na = "", fileEncoding = "UTF-8")
message("Wrote ", nrow(sql_requests), " cleaned request rows for SQL analysis.")
