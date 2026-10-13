SELECT strftime('%Y-%m', date(request_date)) AS request_month,
       COUNT(*) AS total_requests,
       SUM(CASE WHEN resolution_date IS NOT NULL AND resolution_date <> '' THEN 1 ELSE 0 END) AS resolved_requests,
       ROUND(100.0 * SUM(CASE WHEN resolution_date IS NOT NULL AND resolution_date <> '' THEN 1 ELSE 0 END) / COUNT(*), 2) AS resolved_share_pct,
       SUM(CASE WHEN resolution_date IS NOT NULL AND resolution_date <> '' AND due_date IS NOT NULL AND due_date <> '' THEN 1 ELSE 0 END) AS due_date_eligible_requests,
       SUM(CASE WHEN resolution_date IS NOT NULL AND resolution_date <> '' AND due_date IS NOT NULL AND due_date <> '' AND date(resolution_date) <= date(due_date) THEN 1 ELSE 0 END) AS on_time_requests,
       ROUND(100.0 * SUM(CASE WHEN resolution_date IS NOT NULL AND resolution_date <> '' AND due_date IS NOT NULL AND due_date <> '' AND date(resolution_date) <= date(due_date) THEN 1 ELSE 0 END)
             / NULLIF(SUM(CASE WHEN resolution_date IS NOT NULL AND resolution_date <> '' AND due_date IS NOT NULL AND due_date <> '' THEN 1 ELSE 0 END), 0), 2) AS due_date_compliance_pct
FROM requests
GROUP BY request_month
ORDER BY request_month;
