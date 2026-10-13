# DC 311 dashboard: metrics and interview guide

This guide explains each metric in the Shiny dashboard and the SQL/Power BI handoff. The figures below were calculated from the downloaded 2025 DC 311 extract. If the source file changes, rerun the refresh and SQL scripts before quoting the figures.

## Dataset and preparation

- **Source:** District of Columbia Office of Unified Communications, *311 City Service Requests in 2025*.
- **Source rows retained:** 440,562 distinct service request IDs with an opening date from January 1 through December 31, 2025.
- **Service type labels:** 24 distinct source labels become 23 analysis groups. The source spelling `Admistration` is grouped as `Administration`; `service_type_source` preserves the original label for audit. Empty labels become `Unspecified`.
- **Ward:** 10 retained records have no ward value; those rows are excluded from ward comparisons.
- **Resolution date:** 3,796 records have no resolution date in the extract. They count in request volume and in the resolved-share denominator, but not in turnaround or due-date compliance.
- **Due date:** 14 records have no due date. Of those, 6 have a resolution date. Due-date compliance uses only resolved records with both dates: 436,760 records.
- **Date validation:** all retained opening dates are in 2025. No negative calendar-day turnaround values were found.
- **Privacy:** the preparation step does not retain street addresses, free-text request details, names, or precise coordinates.

## Metric definitions and observed values

| Metric | Definition | 2025 value | Important interpretation |
|---|---|---:|---|
| Total requests | Distinct request IDs after keeping opening dates in 2025 | 440,562 | Counts service requests, not unique residents or service events. |
| Monthly request volume | Distinct requests grouped by opening month | Peak: July, 45,137; low: December, 26,378 | A within-year comparison; one year cannot establish recurring seasonality. |
| Service-type volume | Distinct requests grouped by normalized service-type description | Solid Waste Management Administration: 231,075 (52.5%) | Grouping corrects one source spelling variant; source values are preserved. |
| Resolved requests | Requests with a nonmissing resolution date | 436,766 | A missing resolution date is treated as unresolved in this extract; it does not prove a request is still open today. |
| Resolved share | Resolved requests divided by all filtered requests | 99.14% | The denominator includes requests without a resolution date. |
| Turnaround days | Calendar-date difference: resolution date minus opening date | Median: 3 days; P90: 18; P95: 34; P99: 209 | Same-day dates produce 0. These are calendar days, not business hours or elapsed hours. |
| Service median turnaround | Median nonnegative turnaround by service type; comparison shown for groups with at least 100 resolved requests | SIOD: 103 days median, 328 days P90, 1,171 resolved requests | The minimum sample rule avoids highlighting tiny categories; the long tail still needs operational context. |
| Service/ward P90 | Nearest-rank 90th percentile of nonnegative turnaround within each service type or ward | Available per group in the SQL exports | These are precomputed group values; do not average them across groups. |
| Due-date eligible requests | Resolved requests with both a resolution date and a source due date | 436,760 | The denominator is narrower than total requests and resolved requests. |
| On-time requests | Eligible resolved requests with resolution date on or before due date | 394,871 | Uses the due date in the dataset as the target; it is not an independently verified SLA. |
| Due-date compliance | On-time requests divided by due-date eligible requests | 90.41% | Do not average monthly or ward percentages; divide summed on-time counts by summed eligible counts. |
| Monthly due-date compliance | Same on-time/eligible ratio grouped by opening month | January: 70.37%; April: 96.29% | A pattern to investigate with the data owner, not proof that operations improved or worsened. |
| Ward volume | Requests with a recorded ward, grouped by ward | Highest: Ward 5, 66,937; lowest: Ward 3, 41,816 | These are raw counts, not population-adjusted service rates or measures of resident need. |
| Ward due-date compliance | On-time eligible requests divided by eligible requests within ward | Ward 8: 93.84%; Ward 3: 88.48% | A 5.36 percentage-point observed gap; it does not explain why the gap exists. |
| Ward resolved share and median | Resolved requests / all requests in the ward; median nonnegative turnaround among resolved records | Ward values are in the ward table and Power BI export | The resolution and turnaround denominators differ; never imply the median includes unresolved records. |
| Turnaround histogram | Nonnegative turnaround values at or below the 99th percentile are binned for display | Values above 209 days are hidden from the histogram only | KPI, median, and percentile calculations use the full nonnegative set. |
| Top service chart | Ten service-type groups with the most requests in the current filter selection | Dynamic | It ranks volume, not severity, quality, or performance. |
| Turnaround chart | Up to 15 service groups with the longest medians in the current selection | Dynamic; at least 100 resolved requests per group | It ranks typical calendar-day turnaround; compare alongside sample size and P90. |

## Likely interview questions

### Why use median turnaround instead of average?

Resolution times are strongly right-skewed: the median is 3 days, but the P90 is 18 and P99 is 209. A small number of very long cases would pull the mean upward, so the median better represents the typical resolved request. I include percentiles to show the long tail rather than hiding it.

### What exactly is the denominator for the 90.41% due-date metric?

It is 436,760 resolved requests that have both a due date and resolution date. There are 394,871 on or before the source due date, so compliance is 394,871 / 436,760 = 90.41%. Requests still unresolved and records missing either date are excluded; that makes this a resolved-case measure, not a measure of all requests.

### Why does the resolved share use a different denominator?

Resolved share is 436,766 requests with a resolution date divided by all 440,562 requests. That measures the share of the full request cohort with a recorded resolution date. I keep it separate from due-date compliance because including unresolved requests as late would mix completion status with due-date adherence.

### How did you define turnaround?

I subtract the request opening calendar date from the resolution calendar date. I exclude missing dates and negative values from turnaround summaries. Because the source is date-level, 0 means the request was opened and resolved on the same calendar date; it does not mean zero hours elapsed.

### How did you handle the misspelled service category?

The source has both `Admistration` and `Administration` in the solid-waste label. I map that one spelling variant to a common analysis category and keep the original source label in a separate column so the decision is auditable. I do not broadly fuzzy-match other categories without confirmation from the data owner.

### Does 99.14% resolved mean agencies completed 99.14% on time?

No. It means 99.14% of records have a resolution date. Due-date compliance is a separate calculation with its own eligible denominator, and it is 90.41% among resolved requests with both dates.

### Can you call the due date an SLA?

Not without validating it with the dataset owner. The analysis calls it a source due date or operational target. The public fields alone do not prove it is a contractual or consistently applied service-level agreement.

### What do the ward comparisons tell you?

They show descriptive differences in request counts and due-date compliance among requests assigned to each ward. They do not adjust for population, request mix, complexity, reporting behavior, or agency workload, so I would use them to ask follow-up questions, not to rank agency performance.

### Why set a 100-request comparison threshold?

It makes the service turnaround ranking less sensitive to very small groups. It is a practical display rule, not a statistical significance test. I still show sample sizes and would examine uncertainty and category definitions before making decisions.

### What would you recommend based on this analysis?

I would first validate category and due-date definitions with the owning agencies. Then I would review high-volume categories and the long turnaround tail with operational staff, segment by request complexity or priority if those fields are reliable, and look for process changes supported by that additional context. The current analysis identifies where to investigate; it does not establish causes.

### What are the main limitations?

The project covers one year and one public dataset. Missing resolution dates and due dates affect the denominators. Request mix and complexity are not controlled. Ward volumes are not normalized for population. A due date is not independently validated as an SLA. Aggregated association does not identify causation.

## SQL and Power BI notes

- SQL creates overall, monthly, service-type, and ward summaries from the cleaned request rows.
- P90 uses the nearest-rank convention: the value at rank `ceil(0.90 * n)`. The median averages the two middle values when `n` is even.
- Power BI ratio measures sum the numerator and denominator separately and then divide. Do not average category compliance percentages.
- Median and P90 values are already grouped in the exported summary tables. Do not sum them or average them across groups.

## Practice before an interview

Be ready to explain the denominator, source field, inclusion/exclusion rule, and decision limit for every metric you quote. Then make one small code change yourself—for example, add a priority filter or compare P90 turnaround by service type—and explain how you checked the result.
