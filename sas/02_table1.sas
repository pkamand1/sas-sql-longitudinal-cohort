/*------------------------------------------------------------------------------
  02_table1.sas
  Baseline characteristics by adherence group (Table 1), built with two small
  macros, one for continuous and one for categorical variables.
------------------------------------------------------------------------------*/

/* Empty base table with fixed lengths, so that every run starts clean */
data work.table1_long;
    length group $8 characteristic $60 level $40 value $40 order sub 8;
    stop;
run;

/* Continuous variable: mean (SD) overall and by group */
%macro t1_cont(var=, label=, order=, dec=1);
    proc means data=work.patient noprint;
        class adherent;
        var &var;
        output out=work._stats n=n mean=mean std=sd;
    run;

    data work._rows;
        set work._stats;
        length group $8 characteristic $60 level $40 value $40;
        if _type_ = 0 then group = 'Overall';
        else group = cats('G', adherent);
        characteristic = "&label";
        level = 'Mean (SD)';
        value = catx(' ', put(mean, 8.&dec), cats('(', put(sd, 8.%eval(&dec + 1)), ')'));
        order = &order;
        sub = 1;
        keep group characteristic level value order sub;
    run;

    proc append base=work.table1_long data=work._rows force;
    run;
%mend t1_cont;

/* Categorical variable: n (%) overall and by group */
%macro t1_cat(var=, fmt=, label=, order=);
    proc freq data=work.patient noprint;
        tables adherent * &var / outpct out=work._by_group;
    run;
    proc freq data=work.patient noprint;
        tables &var / out=work._overall;
    run;

    data work._rows;
        set work._by_group(in=in_group) work._overall(in=in_all);
        length group $8 characteristic $60 level $40 value $40;
        if in_all then do;
            group = 'Overall';
            pct = percent;
        end;
        else do;
            group = cats('G', adherent);
            pct = pct_row;
        end;
        characteristic = "&label";
        level = put(&var, &fmt);
        value = strip(put(count, 8.)) || ' (' || strip(put(pct, 5.1)) || '%)';
        order = &order;
        sub = &var;
        keep group characteristic level value order sub;
    run;

    proc append base=work.table1_long data=work._rows force;
    run;
%mend t1_cat;

%t1_cont(var=age_at_index,   label=Age at index fill (years), order=1, dec=1)
%t1_cat (var=age_group,      fmt=agegrp., label=Age group, order=2)
%t1_cat (var=sex_n,          fmt=sexf.,   label=Sex, order=3)
%t1_cont(var=baseline_hba1c, label=Baseline HbA1c (percent), order=4, dec=2)
%t1_cat (var=baseline_group, fmt=a1cgrp., label=Baseline HbA1c group, order=5)
%t1_cont(var=pdc,            label=Proportion of days covered, order=6, dec=2)
%t1_cont(var=n_followup_labs, label=Follow-up HbA1c results, order=7, dec=1)

proc sort data=work.table1_long;
    by order sub characteristic level;
run;

proc transpose data=work.table1_long out=work.table1(drop=_name_);
    by order sub characteristic level;
    id group;
    var value;
run;

proc sql noprint;
    select count(*) into :n_all trimmed from work.patient;
    select count(*) into :n_adh trimmed from work.patient where adherent = 1;
    select count(*) into :n_non trimmed from work.patient where adherent = 0;
quit;

ods pdf startpage=now;
title2 'Table 1. Baseline characteristics by metformin adherence in the first year';
proc report data=work.table1 nowd split='|' missing;
    column order characteristic sub level Overall G1 G0;
    define order          / order noprint;
    define characteristic / order 'Characteristic' width=30;
    define sub            / order noprint;
    define level          / display 'Level' width=20;
    define Overall        / display "Overall|(N = &n_all)";
    define G1             / display "Adherent|(N = &n_adh)";
    define G0             / display "Not adherent|(N = &n_non)";
run;
title2;
