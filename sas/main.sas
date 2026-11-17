/*------------------------------------------------------------------------------
  main.sas
  Runs the SAS analysis of the analytic data sets produced by the SQL steps.

  Before running:
    1. Run the SQL steps (bash scripts/run_sql.sh) so that output/ holds
       analytic_patient.csv, analytic_long.csv, qc_log.csv, and cohort_flow.csv.
    2. Set ROOT below to the folder that holds this repository. The default
       works on SAS OnDemand for Academics and other Unix SAS installations
       when the repository sits in your home directory.

  Output: output/sas_results.pdf, plus the SAS log.
------------------------------------------------------------------------------*/

%let root   = %sysget(HOME)/sas-sql-longitudinal-cohort;
%let outdir = &root/output;

options nodate nonumber nocenter validvarname=v7 mprint;
ods graphics on / reset=all imagefmt=png width=6.5in height=4in;
ods pdf file="&outdir/sas_results.pdf" style=journal startpage=no;

title1 'Metformin adherence and HbA1c in a synthetic primary care cohort';

%include "&root/sas/01_import_clean.sas";
%include "&root/sas/02_table1.sas";
%include "&root/sas/03_mixed_model.sas";
%include "&root/sas/04_logistic.sas";
%include "&root/sas/05_figure.sas";

ods pdf close;
title;
