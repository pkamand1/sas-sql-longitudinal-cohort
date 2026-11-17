-- 05_cohort.sql
-- Build the analytic cohort and data sets for the SAS analysis.
--   index date      first clean metformin fill
--   baseline HbA1c  most recent result in the 90 days before the index date
--   follow-up       results from day 1 to day 456 (about 15 months) after the index date
--   adherence       proportion of days covered (PDC) over days 0 to 364; adherent if PDC >= 0.80
--   12-month value  result closest to day 365 within days 274 to 456

USE ehr_cohort;

-- Index date and age at index
DROP TABLE IF EXISTS cohort_index;
CREATE TABLE cohort_index AS
SELECT p.patient_id,
       p.sex,
       MIN(f.fill_date) AS index_date,
       TIMESTAMPDIFF(YEAR, p.birth_date, MIN(f.fill_date)) AS age_at_index
FROM raw_patients p
JOIN clean_fills f USING (patient_id)
GROUP BY p.patient_id, p.sex, p.birth_date;

-- Baseline HbA1c
DROP TABLE IF EXISTS cohort_baseline;
CREATE TABLE cohort_baseline AS
SELECT patient_id, hba1c_pct AS baseline_hba1c, result_date AS baseline_date
FROM (
    SELECT l.patient_id, l.hba1c_pct, l.result_date,
           ROW_NUMBER() OVER (PARTITION BY l.patient_id ORDER BY l.result_date DESC, l.lab_id) AS rn
    FROM clean_labs l
    JOIN cohort_index c USING (patient_id)
    WHERE l.result_date BETWEEN DATE_SUB(c.index_date, INTERVAL 90 DAY)
                            AND DATE_SUB(c.index_date, INTERVAL 1 DAY)
) b
WHERE rn = 1;

-- Proportion of days covered over the first 365 days, counting each calendar day once
DROP TABLE IF EXISTS cohort_pdc;
CREATE TABLE cohort_pdc AS
WITH RECURSIVE day_offsets (d) AS (
    SELECT 0
    UNION ALL
    SELECT d + 1 FROM day_offsets WHERE d < 364
),
covered AS (
    SELECT DISTINCT c.patient_id, o.d
    FROM cohort_index c
    JOIN clean_fills f
      ON f.patient_id = c.patient_id
    JOIN day_offsets o
      ON DATE_ADD(c.index_date, INTERVAL o.d DAY) BETWEEN f.fill_date
                                                      AND DATE_ADD(f.fill_date, INTERVAL f.days_supply - 1 DAY)
)
SELECT c.patient_id,
       COUNT(cv.d) AS days_covered,
       ROUND(COUNT(cv.d) / 365, 3) AS pdc,
       CASE WHEN COUNT(cv.d) / 365 >= 0.80 THEN 1 ELSE 0 END AS adherent
FROM cohort_index c
LEFT JOIN covered cv USING (patient_id)
GROUP BY c.patient_id;

-- Follow-up results
DROP TABLE IF EXISTS cohort_followup;
CREATE TABLE cohort_followup AS
SELECT l.patient_id, l.lab_id, l.result_date, l.hba1c_pct,
       DATEDIFF(l.result_date, c.index_date) AS days_since_index
FROM clean_labs l
JOIN cohort_index c USING (patient_id)
WHERE DATEDIFF(l.result_date, c.index_date) BETWEEN 1 AND 456;

-- Twelve-month value
DROP TABLE IF EXISTS cohort_12m;
CREATE TABLE cohort_12m AS
SELECT patient_id, hba1c_pct AS hba1c_12m, days_since_index AS day_12m
FROM (
    SELECT f.*,
           ROW_NUMBER() OVER (PARTITION BY patient_id
                              ORDER BY ABS(days_since_index - 365), days_since_index) AS rn
    FROM cohort_followup f
    WHERE days_since_index BETWEEN 274 AND 456
) t
WHERE rn = 1;

-- One row per patient in the analytic cohort
DROP TABLE IF EXISTS analytic_patient;
CREATE TABLE analytic_patient AS
SELECT c.patient_id,
       c.sex,
       c.age_at_index,
       c.index_date,
       b.baseline_hba1c,
       p.days_covered,
       p.pdc,
       p.adherent,
       m.hba1c_12m,
       CASE WHEN m.hba1c_12m IS NULL THEN NULL
            WHEN m.hba1c_12m < 7.0 THEN 1 ELSE 0 END AS controlled_12m,
       (SELECT COUNT(*) FROM cohort_followup f WHERE f.patient_id = c.patient_id) AS n_followup_labs
FROM cohort_index c
JOIN cohort_baseline b USING (patient_id)
JOIN cohort_pdc p USING (patient_id)
LEFT JOIN cohort_12m m USING (patient_id)
WHERE EXISTS (SELECT 1 FROM cohort_followup f WHERE f.patient_id = c.patient_id);

-- Long format: baseline (month 0) plus every follow-up result, for the mixed model
DROP TABLE IF EXISTS analytic_long;
CREATE TABLE analytic_long AS
SELECT a.patient_id, 0.0 AS months_since_index, a.baseline_hba1c AS hba1c_pct
FROM analytic_patient a
UNION ALL
SELECT f.patient_id, ROUND(f.days_since_index / 30.4375, 2), f.hba1c_pct
FROM cohort_followup f
JOIN analytic_patient a USING (patient_id);

-- Cohort flow for the methods section
DROP TABLE IF EXISTS cohort_flow;
CREATE TABLE cohort_flow (step INT PRIMARY KEY, description VARCHAR(120), n_patients INT);
INSERT INTO cohort_flow VALUES
    (1, 'Patients in the extract', (SELECT COUNT(*) FROM raw_patients)),
    (2, 'With at least one valid metformin fill', (SELECT COUNT(*) FROM cohort_index)),
    (3, 'With a baseline HbA1c in the 90 days before the index fill', (SELECT COUNT(*) FROM cohort_baseline)),
    (4, 'With at least one follow-up HbA1c (analytic cohort)', (SELECT COUNT(*) FROM analytic_patient)),
    (5, 'With a 12-month HbA1c (logistic regression cohort)', (SELECT COUNT(*) FROM analytic_patient WHERE hba1c_12m IS NOT NULL));

SELECT * FROM cohort_flow ORDER BY step;
