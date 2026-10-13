#!/usr/bin/env bash
set -euo pipefail

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "sqlite3 CLI is required. macOS and most Linux distributions include it." >&2
  exit 1
fi
if [ ! -f data/processed/dc_311_2025.rds ]; then
  echo "Prepared data not found. Run Rscript scripts/refresh_data.R first." >&2
  exit 1
fi

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/dc311-sql.XXXXXX")"
trap 'rm -r "$tmp_dir"' EXIT
csv_path="$tmp_dir/requests.csv"
db_path="$tmp_dir/requests.sqlite"

Rscript scripts/export_sql_input.R "$csv_path"
sqlite3 "$db_path" <<SQL
CREATE TABLE requests (
  request_id TEXT,
  service_type_source TEXT,
  service_type TEXT,
  request_date TEXT,
  resolution_date TEXT,
  due_date TEXT,
  status TEXT,
  priority TEXT,
  ward TEXT
);
.mode csv
.import --skip 1 "$csv_path" requests
SQL

mkdir -p powerbi/exports
for report in overall_summary monthly_summary service_summary ward_summary; do
  sqlite3 -header -csv "$db_path" < "sql/${report}.sql" > "powerbi/exports/${report}.csv"
  echo "Wrote powerbi/exports/${report}.csv"
done
