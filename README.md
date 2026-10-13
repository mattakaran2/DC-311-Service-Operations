# DC 311 Service Operations Dashboard

An interactive R Shiny and SQL analysis of DC 311 service-request volume, resolution times, and due-date performance for requests opened in 2025. The project frames public-service requests as an operations and business-intelligence problem: where is demand concentrated, and where should an analyst investigate turnaround patterns?

## Findings from the 2025 extract

- The source contains **440,562 distinct requests** opened during 2025. **436,766 (99.14%)** have a resolution date in this extract.
- Median turnaround is **3 calendar days**; the 90th percentile is **18 days**. The 99th percentile is 209 days, showing a long tail that the median alone would hide.
- **394,871 of 436,760** resolved requests with both dates were resolved on or before the source due date (**90.41%**). This is a due-date measure, not a verified contractual SLA.
- July had the most requests (**45,137**); December had the fewest (**26,378**). One year is not enough to establish a recurring seasonal pattern.
- One source spelling variant split the solid-waste service type into two labels. Grouping `Admistration` with `Administration` combines them into **231,075 requests (52.5%)**. The original source label remains available for audit.
- Among service types with at least 100 resolved requests, SIOD has the longest median turnaround (**103 days**, P90 **328 days**, n = **1,171**). This is a prompt for operational follow-up, not evidence of a cause.

## Project walkthrough

**Question:** Where is DC 311 request demand concentrated, and what patterns in resolution time and due-date performance deserve operational follow-up?

**Analysis decisions:** I treat each distinct request as one record and group trends by the date it was opened. Because resolution times have a long right tail, I show the median and upper percentiles instead of relying on an average. Due-date performance includes only resolved requests with both dates; the source due date is not assumed to be a validated SLA. I normalize one documented service-label spelling variant, preserve the original value for traceability, and keep ward comparisons descriptive rather than population-adjusted.

**What the dashboard shows:** Demand is concentrated in the solid-waste service group (52.5% of requests). Typical turnaround is 3 calendar days, while the P90 is 18 days and P99 is 209 days, indicating a small but substantial long tail. 90.41% of eligible resolved requests were completed on or before their source due date. July had the most requests in this one-year extract; that alone does not establish a recurring seasonal pattern.

**How to interpret it:** These results identify segments to investigate with service owners. They do not explain delays, establish agency performance, or measure resident need. A next analysis should validate the due-date meaning and add reliable request complexity or priority fields before drawing operational conclusions.

**Walkthrough path:** Start on Overview for scale and headline KPIs, open Findings for the observed patterns, use Turnaround to inspect the long tail and service differences, then use Ward view for descriptive geography. Definitions documents the metric rules and limitations.

## Run the Shiny dashboard

1. Install R 4.1 or newer.
2. Install the R packages:

   ```r
   install.packages(c("shiny", "bslib", "dplyr", "ggplot2", "lubridate", "scales", "jsonlite"))
   ```

3. From the repository folder, download and prepare the source data:

   ```sh
   Rscript scripts/refresh_data.R
   ```

4. Open `dc-311-service-operations.Rproj` in RStudio, then run:

   ```r
   shiny::runApp()
   ```

The source CSV is large. The refresh script reads only the fields used by the analysis and excludes address, free-text details, names, and precise coordinates. The raw download and prepared request-level RDS are local generated files and are excluded from Git.

## Deploy the Shiny app

The app can be deployed to [shinyapps.io](https://www.shinyapps.io/). First prepare the local RDS using the refresh steps above, then install `rsconnect` and connect your own shinyapps.io account from R:

```r
install.packages("rsconnect")
rsconnect::deployApp(appDir = ".", appName = "dc-311-service-operations")
```

Configure your account token and secret locally using the command provided in your shinyapps.io account. Do not add credentials to this repository. `.rscignore` keeps the 161 MB raw download out of the deployment bundle while retaining the prepared 2 MB analysis file. A live deployment link will be added here after deployment succeeds.

## Reproduce the SQL and Power BI exports

After preparing the data, run:

```sh
bash scripts/run_sql.sh
```

This exports the cleaned request fields to a temporary CSV, loads them into a temporary SQLite database, runs the SQL in `sql/`, and writes four aggregated CSVs to `powerbi/exports/`. The temporary request-level export and database are removed when the command finishes. The aggregated outputs are small and contain no exact locations or free text.

See [`powerbi/README.md`](powerbi/README.md) for the Power BI report layout and [`powerbi/measures.dax`](powerbi/measures.dax) for DAX measures. These files are a reproducible Power BI handoff; a `.pbix` still needs to be assembled and saved in Power BI Desktop.

## Data source and license

District of Columbia, Office of Unified Communications, [311 City Service Requests in 2025](https://catalog.data.gov/dataset/311-city-service-requests-in-2025). The dataset is public and listed under the [Creative Commons Attribution 4.0 license](https://creativecommons.org/licenses/by/4.0/). The source data can change; rerun the preparation and SQL steps before quoting updated results.

## Metric and data-quality decisions

- **Resolved share:** records with a resolution date divided by all filtered requests.
- **Turnaround:** resolution date minus opening date in calendar days. Missing and negative durations are excluded; same-day resolutions equal zero days.
- **P90:** nearest-rank 90th percentile in SQL. The displayed histogram omits values above the 99th percentile for readability; summary metrics use the full nonnegative distribution.
- **Due-date compliance:** resolved requests on or before the source due date divided by resolved requests with both dates. Missing-date records are excluded from this denominator.
- **Service comparisons:** turnaround charts require at least 100 resolved requests in each displayed group. This is a display stability threshold, not a statistical significance test.
- **Ward comparisons:** counts are not adjusted for population or request mix.
- **Label normalization:** only the known `Admistration` spelling variant is mapped to `Administration`; no fuzzy matching is used.
- **Interpretation:** observed group differences guide follow-up questions but do not prove causation, agency responsibility, or service quality.

## Repository structure

```text
app.R                         Shiny dashboard
R/data_prep.R                 Date parsing, label normalization, and cleaning
scripts/refresh_data.R        Public source download and local data preparation
scripts/run_sql.sh            Reproducible SQLite import and Power BI exports
scripts/export_sql_input.R    Safe request-level SQL input export
sql/                          Overall, monthly, service, and ward queries
powerbi/                      Aggregated exports, DAX measures, and report guide
```
