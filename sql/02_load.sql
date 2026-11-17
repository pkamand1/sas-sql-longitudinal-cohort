-- 02_load.sql
-- Load the CSV extract. Run from the repository root with local_infile enabled,
-- for example: mysql --local-infile=1 -u <user> -p < sql/02_load.sql

USE ehr_cohort;

LOAD DATA LOCAL INFILE 'data/patients.csv'
INTO TABLE raw_patients
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(patient_id, birth_date, @sex, enrollment_date)
SET sex = NULLIF(@sex, '');

LOAD DATA LOCAL INFILE 'data/labs.csv'
INTO TABLE raw_labs
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(lab_id, patient_id, result_date, test_code, result_value, result_unit);

LOAD DATA LOCAL INFILE 'data/pharmacy_fills.csv'
INTO TABLE raw_pharmacy_fills
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(fill_id, patient_id, fill_date, drug_name, days_supply);
