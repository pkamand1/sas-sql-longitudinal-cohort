-- 04_clean.sql
-- Apply the decisions recorded in qc_log to produce clean lab and pharmacy tables.

USE ehr_cohort;

SET @extract_date = DATE('2026-06-30');

DROP TABLE IF EXISTS clean_labs;
CREATE TABLE clean_labs AS
WITH deduplicated AS (
    SELECT l.*,
           ROW_NUMBER() OVER (
               PARTITION BY patient_id, result_date, test_code, result_value, result_unit
               ORDER BY lab_id
           ) AS copy_number
    FROM raw_labs l
),
standardized AS (
    SELECT lab_id, patient_id, result_date, test_code,
           CASE WHEN result_unit = 'mmol/mol'
                THEN ROUND(result_value / 10.929 + 2.15, 1)
                ELSE result_value END AS hba1c_pct,
           result_unit AS original_unit
    FROM deduplicated
    WHERE copy_number = 1
)
SELECT s.*
FROM standardized s
JOIN raw_patients p USING (patient_id)
WHERE s.test_code = 'HBA1C'
  AND s.hba1c_pct BETWEEN 3 AND 20
  AND s.result_date <= @extract_date;

ALTER TABLE clean_labs ADD INDEX idx_clean_labs (patient_id, result_date);

DROP TABLE IF EXISTS clean_fills;
CREATE TABLE clean_fills AS
SELECT f.*
FROM raw_pharmacy_fills f
JOIN raw_patients p USING (patient_id)
WHERE f.fill_date >= p.enrollment_date
  AND f.fill_date <= @extract_date;

ALTER TABLE clean_fills ADD INDEX idx_clean_fills (patient_id, fill_date);

SELECT 'clean_labs' AS table_name, COUNT(*) AS n_rows FROM clean_labs
UNION ALL
SELECT 'clean_fills', COUNT(*) FROM clean_fills;
