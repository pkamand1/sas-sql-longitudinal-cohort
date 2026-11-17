/*------------------------------------------------------------------------------
  04_logistic.sas
  Logistic regression for glycaemic control (HbA1c below 7.0%) at 12 months,
  adjusted for baseline HbA1c, age, and sex. Patients without a 12-month
  result, or with missing sex, are excluded.
------------------------------------------------------------------------------*/

ods pdf startpage=now;
title2 'Logistic regression: HbA1c below 7.0% at 12 months';

proc logistic data=work.patient plots=none;
    where not missing(controlled_12m) and sex_n in (1, 2);
    format adherent sex_n;    /* model on the unformatted codes */
    class adherent(ref='0') sex_n(ref='1') / param=ref;
    model controlled_12m(event='1') = adherent baseline_hba1c age_c sex_n;
    ods output OddsRatios=work.logit_or
               ParameterEstimates=work.logit_pe
               Association=work.logit_assoc;
run;

title2 'Adjusted odds ratios with 95% Wald confidence limits';
proc print data=work.logit_or noobs label;
    format oddsratioest lowercl uppercl 8.3;
run;
title2;
