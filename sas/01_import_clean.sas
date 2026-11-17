/*------------------------------------------------------------------------------
  01_import_clean.sas
  Read the analytic data sets with explicit informats, derive analysis
  variables, merge patient-level covariates onto the long data, and check
  that the two data sets agree.
------------------------------------------------------------------------------*/

proc format;
    value adhf   1 = 'Adherent (PDC >= 0.80)'
                 0 = 'Not adherent (PDC < 0.80)';
    value sexf   1 = 'Female'
                 2 = 'Male'
                 9 = 'Missing';
    value agegrp 1 = 'Under 50'
                 2 = '50 to 64'
                 3 = '65 and over';
    value a1cgrp 1 = 'Under 8.0%'
                 2 = '8.0% to 8.9%'
                 3 = '9.0% and over';
run;

/* One row per patient */
data work.patient;
    infile "&outdir/analytic_patient.csv" dsd firstobs=2 truncover;
    length patient_id $10 sex $1;
    input patient_id $ sex $ age_at_index index_date :yymmdd10.
          baseline_hba1c days_covered pdc adherent hba1c_12m
          controlled_12m n_followup_labs;
    format index_date yymmdd10.;

    /* Numeric sex code so that missing sex is a reportable category */
    if sex = 'F' then sex_n = 1;
    else if sex = 'M' then sex_n = 2;
    else sex_n = 9;

    if age_at_index < 50 then age_group = 1;
    else if age_at_index < 65 then age_group = 2;
    else age_group = 3;

    if baseline_hba1c < 8 then baseline_group = 1;
    else if baseline_hba1c < 9 then baseline_group = 2;
    else baseline_group = 3;

    age_c = age_at_index - 60;   /* centred at 60 years for the models */

    label age_at_index   = 'Age at index fill (years)'
          baseline_hba1c = 'Baseline HbA1c (%)'
          pdc            = 'Proportion of days covered, first year'
          adherent       = 'Adherent to metformin'
          hba1c_12m      = 'HbA1c at 12 months (%)'
          controlled_12m = 'HbA1c below 7.0% at 12 months'
          age_c          = 'Age minus 60 (years)';
run;

/* One row per HbA1c result: baseline (month 0) and follow-up */
data work.long_raw;
    infile "&outdir/analytic_long.csv" dsd firstobs=2 truncover;
    length patient_id $10;
    input patient_id $ months_since_index hba1c_pct;
    label months_since_index = 'Months since index fill'
          hba1c_pct          = 'HbA1c (%)';
run;

proc sort data=work.patient;  by patient_id; run;
proc sort data=work.long_raw; by patient_id months_since_index; run;

data work.long;
    merge work.long_raw(in=in_long)
          work.patient(in=in_patient keep=patient_id adherent sex_n age_c);
    by patient_id;
    if in_long and not in_patient then put 'WARNING: result without patient record: ' patient_id=;
    if in_long and in_patient;
run;

/* Consistency check: follow-up counts recomputed here must match the SQL count */
proc sql;
    title2 'Check: follow-up results per patient, SAS recount versus SQL count';
    create table work.followup_check as
        select p.patient_id,
               p.n_followup_labs,
               sum(l.months_since_index > 0) as n_followup_sas
        from work.patient as p
             inner join work.long as l
             on p.patient_id = l.patient_id
        group by p.patient_id, p.n_followup_labs;

    select count(*)                                      as n_patients,
           sum(n_followup_labs ne n_followup_sas)        as n_mismatched,
           mean(n_followup_sas)                          as mean_followup_results format=5.2
    from work.followup_check;
quit;

/* Data quality log and cohort flow from the SQL steps */
proc import datafile="&outdir/qc_log.csv" out=work.qc_log dbms=csv replace;
    guessingrows=max;
run;
proc import datafile="&outdir/cohort_flow.csv" out=work.cohort_flow dbms=csv replace;
    guessingrows=max;
run;

title2 'Data quality checks applied to the raw extract (SQL step 03)';
proc print data=work.qc_log noobs label;
    var check_id table_name check_name n_rows action;
run;

title2 'Cohort construction (SQL step 05)';
proc print data=work.cohort_flow noobs label;
    var step description n_patients;
run;
title2;
