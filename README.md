# DC 311 Service Operations Dashboard

An interactive R Shiny dashboard exploring service-request demand, resolution times, and due-date performance for requests opened in Washington, DC during 2025. The project is designed as a business intelligence portfolio piece: it turns an operational dataset into metrics and comparisons a service manager or analyst can explore.

## Questions

- Which 311 service types generate the most requests?
- How does request volume change by month?
- How does typical turnaround differ across service types and wards?
- Among resolved requests with a recorded due date, what share was completed by that date?

## Run it locally

1. Install R 4.1 or newer.
2. Install the required packages:

   ```r
   install.packages(c("shiny", "bslib", "dplyr", "ggplot2", "lubridate", "scales", "jsonlite"))
   ```

3. From the repository folder, download and prepare the data:

   ```sh
   Rscript scripts/refresh_data.R
   ```

4. Start the app in R:

   ```r
   shiny::runApp()
   ```

The data refresh script requests only the columns needed by the dashboard. It does not request street addresses, free-text details, inspector names, or precise coordinates. The downloaded processed file is ignored by Git because it can be regenerated.

## Publish to GitHub

Create an empty repository on GitHub, then run these commands from this folder (replace the URL with your repository URL):

```sh
git add .
git commit -m "Build DC 311 service operations dashboard"
git branch -M main
git remote add origin https://github.com/YOUR-USERNAME/dc-311-service-operations.git
git push -u origin main
```

The 175 MB source CSV and generated RDS file are excluded from Git. Include a screenshot of the running app in the repository after you review the dashboard.

## Data source

District of Columbia, Office of Unified Communications, [311 City Service Requests in 2025](https://catalog.data.gov/dataset/311-city-service-requests-in-2025). The dataset is public and listed under the [Creative Commons Attribution 4.0 license](https://creativecommons.org/licenses/by/4.0/). The ArcGIS layer endpoint is used by `scripts/refresh_data.R`.

## Metric definitions

- **Requests:** distinct request identifiers with an opening date in calendar year 2025.
- **Resolved share:** records with a resolution date divided by filtered records.
- **Turnaround:** elapsed calendar days from the opening date to the resolution date. Negative durations are excluded from turnaround summaries.
- **Met due date:** resolved requests whose resolution date is on or before the source due date, among records with both dates.
- **Ward:** ward as recorded in the source. Ward request totals are not adjusted for population.

## Limitations

These measures describe the fields published in the source; they do not establish why requests take longer or whether a particular agency caused a delay. Open requests and missing dates affect resolution summaries. A source due date is treated as an operational target, not an independently verified service-level agreement. Request volume is not a measure of resident need, service quality, or agency effort. Category and ward comparisons should be interpreted descriptively.

## Project structure

```text
app.R                  Shiny interface and dashboard calculations
R/data_prep.R          Reusable date parsing and cleaning logic
scripts/refresh_data.R Paginated download and local data preparation
data/                  Local generated data (excluded from Git)
```

## Skills demonstrated

R data cleaning, date handling, metric definition, exploratory analysis, interactive dashboard design, data sourcing, and reproducible project documentation.
