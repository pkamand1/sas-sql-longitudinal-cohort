-- 01_schema.sql
-- Raw tables that receive the electronic health record extract exactly as delivered.
-- Target: MySQL 8.0 or later.

CREATE DATABASE IF NOT EXISTS ehr_cohort;
USE ehr_cohort;

DROP TABLE IF EXISTS raw_patients;
CREATE TABLE raw_patients (
    patient_id      VARCHAR(10) NOT NULL PRIMARY KEY,
    birth_date      DATE        NOT NULL,
    sex             CHAR(1)     NULL,
    enrollment_date DATE        NOT NULL
);

DROP TABLE IF EXISTS raw_labs;
CREATE TABLE raw_labs (
    lab_id       INT           NOT NULL PRIMARY KEY,
    patient_id   VARCHAR(10)   NOT NULL,
    result_date  DATE          NOT NULL,
    test_code    VARCHAR(20)   NOT NULL,
    result_value DECIMAL(6, 1) NOT NULL,
    result_unit  VARCHAR(10)   NOT NULL,
    INDEX idx_labs_patient (patient_id, result_date)
);

DROP TABLE IF EXISTS raw_pharmacy_fills;
CREATE TABLE raw_pharmacy_fills (
    fill_id     INT          NOT NULL PRIMARY KEY,
    patient_id  VARCHAR(10)  NOT NULL,
    fill_date   DATE         NOT NULL,
    drug_name   VARCHAR(50)  NOT NULL,
    days_supply SMALLINT     NOT NULL,
    INDEX idx_fills_patient (patient_id, fill_date)
);
