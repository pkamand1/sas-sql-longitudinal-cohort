/*------------------------------------------------------------------------------
  03_mixed_model.sas
  Linear mixed model for HbA1c over the first 15 months after the index fill,
  with random intercepts and slopes for each patient. The interaction between
  time and adherence tests whether HbA1c falls faster in adherent patients.
  Patients with missing sex are excluded from this adjusted model.
------------------------------------------------------------------------------*/

ods pdf startpage=now;
title2 'Linear mixed model: HbA1c trajectory by adherence group';

proc mixed data=work.long method=reml plots=none;
    where sex_n in (1, 2);
    class patient_id adherent sex_n;
    model hba1c_pct = months_since_index adherent months_since_index*adherent
                      age_c sex_n / solution cl ddfm=kenwardroger;
    random intercept months_since_index / subject=patient_id type=un;
    estimate 'Monthly change, not adherent' months_since_index 1
             months_since_index*adherent 1 0 / cl;
    estimate 'Monthly change, adherent'     months_since_index 1
             months_since_index*adherent 0 1 / cl;
    estimate 'Adherent minus not adherent'  months_since_index*adherent -1 1 / cl;
    estimate '12-month difference, adherent minus not adherent'
             adherent -1 1 months_since_index*adherent -12 12 / cl;
    ods output SolutionF=work.mixed_fixed
               Estimates=work.mixed_estimates
               CovParms=work.mixed_covparms;
run;

title2 'Estimated monthly change in HbA1c (percentage points per month)';
proc print data=work.mixed_estimates noobs label;
    var label estimate stderr df tvalue probt lower upper;
    format estimate stderr lower upper 8.4 probt pvalue6.4;
run;
title2;
