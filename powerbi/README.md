# Power BI handoff

This folder contains four small, aggregated CSV tables generated with the SQL queries in `../sql/`:

- `exports/overall_summary.csv` — portfolio-level KPI values
- `exports/monthly_summary.csv` — monthly demand and service-date compliance
- `exports/service_summary.csv` — category volume, turnaround, and due-date performance
- `exports/ward_summary.csv` — ward volume and service measures

Regenerate these files from the prepared 2025 request data:

```sh
bash scripts/run_sql.sh
```

In Power BI Desktop, use **Get Data → Text/CSV** to import the four CSV files. Keep them as separate summary tables; do not join them to one another because each has a different grain. Build a three-page report:

1. **Executive view:** cards for request volume, resolved share, median and P90 turnaround, and due-date compliance; a monthly volume line chart.
2. **Service mix:** service-type volume bar chart and a turnaround table with request counts. Filter comparisons to categories with at least 100 resolved requests.
3. **Ward view:** request-volume bars and due-date compliance by ward. Label request volume as raw counts, not population-adjusted rates.

Add the measures in `measures.dax` to the matching table. For ratio measures, aggregate numerators and denominators before dividing. Do not average percentages across months or wards. Median and P90 values in the exports are precomputed by group and must not be summed or averaged across groups. Use `service_summary.csv` or `ward_summary.csv` row context when displaying those percentiles.

The project currently provides a reproducible Power BI data and measure handoff, not a `.pbix` file. Power BI Desktop is needed to assemble and save the report file.
