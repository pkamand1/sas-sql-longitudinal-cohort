-- 03_quality_checks.sql
-- Profile the raw extract before anything is changed, and record every finding
-- in qc_log so that the cleaning decisions in 04_clean.sql are documented.

USE ehr_cohort;

SET @extract_date = DATE('2026-06-30');

DROP TABLE IF EXISTS qc_log;
CREATE TABLE qc_log (
    check_id    INT          NOT NULL PRIMARY KEY,
    table_name  VARCHAR(30)  NOT NULL,
    check_name  VARCHAR(120) NOT NULL,
    n_rows      INT          NOT NULL,
    action      VARCHAR(120) NOT NULL
);

-- 1. Exact duplicate lab results (same patient, date, test, value, and unit)
INSERT INTO qc_log
SELECT 1, 'raw_labs', 'Duplicate lab rows beyond the first copy', COALESCE(SUM(n - 1), 0),
       'Keep the row with the lowest lab_id'
FROM (
    SELECT COUNT(*) AS n
    FROM raw_labs
    GROUP BY patient_id, result_date, test_code, result_value, result_unit
    HAVING COUNT(*) > 1
) d;

-- 2. HbA1c reported in mmol/mol rather than percent
INSERT INTO qc_log
SELECT 2, 'raw_labs', 'HbA1c reported in mmol/mol', COUNT(*),
       'Convert to percent: value / 10.929 + 2.15 (IFCC to NGSP)'
FROM raw_labs
WHERE test_code = 'HBA1C' AND result_unit = 'mmol/mol';

-- 3. Physiologically implausible HbA1c in percent (outside 3 to 20)
INSERT INTO qc_log
SELECT 3, 'raw_labs', 'HbA1c (percent) outside 3 to 20', COUNT(*),
       'Exclude result'
FROM raw_labs
WHERE test_code = 'HBA1C' AND result_unit = '%'
  AND (result_value < 3 OR result_value > 20);

-- 4. Results dated after the extract date
INSERT INTO qc_log
SELECT 4, 'raw_labs', 'Lab results dated after the extract date', COUNT(*),
       'Exclude result'
FROM raw_labs
WHERE result_date > @extract_date;

-- 5. Pharmacy fills dated before the patient enrolled in the practice
INSERT INTO qc_log
SELECT 5, 'raw_pharmacy_fills', 'Fills dated before practice enrollment', COUNT(*),
       'Exclude fill'
FROM raw_pharmacy_fills f
JOIN raw_patients p USING (patient_id)
WHERE f.fill_date < p.enrollment_date;

-- 6. Missing sex
INSERT INTO qc_log
SELECT 6, 'raw_patients', 'Missing sex', COUNT(*),
       'Retain patient; reported as missing in Table 1'
FROM raw_patients
WHERE sex IS NULL;

-- 7. Orphan records (results or fills for unknown patients)
INSERT INTO qc_log
SELECT 7, 'raw_labs, raw_pharmacy_fills', 'Records without a matching patient',
       (SELECT COUNT(*) FROM raw_labs l LEFT JOIN raw_patients p USING (patient_id) WHERE p.patient_id IS NULL)
     + (SELECT COUNT(*) FROM raw_pharmacy_fills f LEFT JOIN raw_patients p USING (patient_id) WHERE p.patient_id IS NULL),
       'Exclude record';

SELECT * FROM qc_log ORDER BY check_id;
