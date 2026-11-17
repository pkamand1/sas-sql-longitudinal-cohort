/*------------------------------------------------------------------------------
  05_figure.sas
  Mean HbA1c with 95% confidence limits in three-month windows, by adherence.
------------------------------------------------------------------------------*/

data work.long_binned;
    set work.long;
    month_window = 3 * round(months_since_index / 3);
    label month_window = 'Months since index fill';
run;

proc means data=work.long_binned noprint nway;
    class adherent month_window;
    var hba1c_pct;
    output out=work.trajectory n=n mean=mean lclm=lclm uclm=uclm;
run;

ods pdf startpage=now;
title2 'Mean HbA1c by adherence group (95% confidence limits)';

proc sgplot data=work.trajectory;
    format adherent adhf.;
    band   x=month_window lower=lclm upper=uclm / group=adherent transparency=0.7;
    series x=month_window y=mean / group=adherent markers;
    refline 7 / axis=y lineattrs=(pattern=shortdash) label='7.0%';
    xaxis values=(0 to 15 by 3) label='Months since index fill';
    yaxis label='Mean HbA1c (%)';
    keylegend / title='';
run;
title2;
