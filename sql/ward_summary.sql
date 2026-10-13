WITH resolved AS (
  SELECT ward, julianday(resolution_date) - julianday(request_date) AS days_to_resolve
  FROM requests
  WHERE ward IS NOT NULL AND ward <> ''
    AND resolution_date IS NOT NULL AND resolution_date <> ''
    AND request_date IS NOT NULL AND request_date <> ''
    AND julianday(resolution_date) >= julianday(request_date)
), ranked AS (
  SELECT ward, days_to_resolve,
         ROW_NUMBER() OVER (PARTITION BY ward ORDER BY days_to_resolve) AS row_num,
         COUNT(*) OVER (PARTITION BY ward) AS n
  FROM resolved
), turnaround AS (
  SELECT ward,
         AVG(CASE WHEN row_num IN ((n + 1) / 2, (n + 2) / 2) THEN days_to_resolve END) AS median_turnaround_days,
         MAX(CASE WHEN row_num = CAST((9 * n + 9) / 10 AS INTEGER) THEN days_to_resolve END) AS p90_turnaround_days
  FROM ranked GROUP BY ward
), volume AS (
  SELECT ward, COUNT(*) AS total_requests,
         SUM(CASE WHEN resolution_date IS NOT NULL AND resolution_date <> '' THEN 1 ELSE 0 END) AS resolved_requests,
         SUM(CASE WHEN resolution_date IS NOT NULL AND resolution_date <> '' AND due_date IS NOT NULL AND due_date <> '' THEN 1 ELSE 0 END) AS due_date_eligible_requests,
         SUM(CASE WHEN resolution_date IS NOT NULL AND resolution_date <> '' AND due_date IS NOT NULL AND due_date <> '' AND date(resolution_date) <= date(due_date) THEN 1 ELSE 0 END) AS on_time_requests
  FROM requests WHERE ward IS NOT NULL AND ward <> '' GROUP BY ward
)
SELECT volume.ward, volume.total_requests, volume.resolved_requests,
       ROUND(100.0 * volume.resolved_requests / volume.total_requests, 2) AS resolved_share_pct,
       ROUND(turnaround.median_turnaround_days, 2) AS median_turnaround_days,
       ROUND(turnaround.p90_turnaround_days, 2) AS p90_turnaround_days,
       volume.due_date_eligible_requests, volume.on_time_requests,
       ROUND(100.0 * volume.on_time_requests / NULLIF(volume.due_date_eligible_requests, 0), 2) AS due_date_compliance_pct
FROM volume LEFT JOIN turnaround ON volume.ward = turnaround.ward
ORDER BY volume.ward;
