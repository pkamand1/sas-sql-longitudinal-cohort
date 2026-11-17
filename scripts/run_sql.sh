#!/usr/bin/env bash
# Run the SQL steps in order and export the analytic tables as CSV for SAS.
# Usage (from the repository root):  bash scripts/run_sql.sh [extra mysql client options]
# Example:                           bash scripts/run_sql.sh -u analyst -p
set -euo pipefail

MYSQL=(mysql --local-infile=1 "$@")

for step in 01_schema 02_load 03_quality_checks 04_clean 05_cohort; do
    echo "== ${step}.sql"
    "${MYSQL[@]}" --table < "sql/${step}.sql"
done

mkdir -p output
for table in analytic_patient analytic_long qc_log cohort_flow; do
    "${MYSQL[@]}" --batch --raw -e "SELECT * FROM ehr_cohort.${table}" \
        | sed -e 's/\tNULL\t/\t\t/g' -e 's/\tNULL$/\t/' -e 's/\tNULL\t/\t\t/g' \
        | awk 'BEGIN{FS="\t"; OFS=","} {for (i = 1; i <= NF; i++) if ($i ~ /,/) $i = "\"" $i "\""; $1 = $1; print}' \
        > "output/${table}.csv"
    echo "exported output/${table}.csv ($(($(wc -l < "output/${table}.csv") - 1)) rows)"
done
