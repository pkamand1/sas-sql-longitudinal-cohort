#!/usr/bin/env python3
"""Generate the synthetic electronic health record extract used in this project.

The data are entirely synthetic. They imitate an extract from a primary care
record for adults with type 2 diabetes who start metformin: a patient table,
a laboratory table of HbA1c results, and a pharmacy table of dispensing records.
The generating model is known, so the analysis can be checked against it:

  * Each patient has a latent adherence probability. Patients who refill
    reliably (proportion of days covered of at least 0.80) experience a mean
    HbA1c decline of 0.050 percentage points per month over the first year,
    against 0.015 per month for less adherent patients, with patient-specific
    random intercepts and slopes and measurement noise.
  * Realistic data quality problems are planted on purpose: exact duplicate
    lab rows, physiologically impossible HbA1c values, lab results recorded
    in the wrong unit (mmol/mol instead of percent), missing sex, fills dated
    before the patient entered the practice, and labs dated in the future.

Run from the repository root:  python scripts/generate_data.py
"""
import csv
import datetime as dt
import os
import random

rng = random.Random(20261117)
OUT = "data"
N = 600
EXTRACT_DATE = dt.date(2026, 6, 30)


def clamp(x, lo, hi):
    return max(lo, min(hi, x))


def main():
    os.makedirs(OUT, exist_ok=True)
    patients, labs, fills = [], [], []
    lab_id = fill_id = 0

    for i in range(1, N + 1):
        pid = f"P{i:04d}"
        sex = rng.choice(["F", "M"])
        birth = dt.date(1946, 1, 1) + dt.timedelta(days=rng.randint(0, 365 * 40))
        enrolled = dt.date(2018, 1, 1) + dt.timedelta(days=rng.randint(0, 365 * 4))
        index = enrolled + dt.timedelta(days=rng.randint(60, 700))   # first metformin fill
        patients.append([pid, birth.isoformat(), "" if rng.random() < 0.02 else sex, enrolled.isoformat()])

        # Refill behaviour: 30-day fills, gaps drawn from the patient's adherence propensity
        p_adherent = rng.betavariate(4, 1.6)
        day = 0
        while day < 420:
            fill_date = index + dt.timedelta(days=day)
            fill_id += 1
            fills.append([fill_id, pid, fill_date.isoformat(), "metformin 500 mg", 30])
            gap = 0 if rng.random() < p_adherent else rng.randint(10, 60)
            day += 30 + gap + rng.randint(-3, 3)

        # Days covered in the first 365 days, to drive the true trajectory
        covered = set()
        for f in fills:
            if f[1] != pid:
                continue
            start = (dt.date.fromisoformat(f[2]) - index).days
            covered.update(d for d in range(start, start + f[4]) if 0 <= d < 365)
        adherent = len(covered) / 365 >= 0.80

        baseline = clamp(rng.gauss(8.4, 1.1), 6.6, 13.0)
        intercept = baseline + rng.gauss(0, 0.25)
        slope = (-0.050 if adherent else -0.015) + rng.gauss(0, 0.020)
        age = (index - birth).days / 365.25
        slope += -0.0004 * (age - 60)  # older patients improve a little faster

        # Baseline lab in the 90 days before the index fill
        lab_dates = [index - dt.timedelta(days=rng.randint(1, 90))]
        # Follow-up labs roughly every three months for up to 15 months, with some missed visits
        m = 3
        while m <= 15:
            if rng.random() > 0.15:
                lab_dates.append(index + dt.timedelta(days=int(30.4 * m) + rng.randint(-20, 20)))
            m += 3
        for d in lab_dates:
            months = (d - index).days / 30.4
            value = intercept + slope * max(months, 0) + rng.gauss(0, 0.30)
            lab_id += 1
            labs.append([lab_id, pid, d.isoformat(), "HBA1C", round(value, 1), "%"])

    # Planted data quality problems
    for row in rng.sample(labs, 25):                          # exact duplicates
        lab_id += 1
        labs.append([lab_id] + row[1:])
    for row in rng.sample(labs, 8):                           # impossible values
        row[4] = rng.choice([0.0, 0.4, 31.0, 48.5])
    for row in rng.sample(labs, 12):                          # wrong unit (mmol/mol)
        row[4] = round(10.929 * (row[4] - 2.15), 0)
        row[5] = "mmol/mol"
    for row in rng.sample(labs, 5):                           # future dates
        row[2] = (EXTRACT_DATE + dt.timedelta(days=rng.randint(30, 400))).isoformat()
    enrol = {p[0]: dt.date.fromisoformat(p[3]) for p in patients}
    for row in rng.sample(fills, 6):                          # fills before practice enrolment
        row[2] = (enrol[row[1]] - dt.timedelta(days=rng.randint(30, 300))).isoformat()

    rng.shuffle(labs)
    with open(os.path.join(OUT, "patients.csv"), "w", newline="") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(["patient_id", "birth_date", "sex", "enrollment_date"])
        w.writerows(patients)
    with open(os.path.join(OUT, "labs.csv"), "w", newline="") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(["lab_id", "patient_id", "result_date", "test_code", "result_value", "result_unit"])
        w.writerows(labs)
    with open(os.path.join(OUT, "pharmacy_fills.csv"), "w", newline="") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(["fill_id", "patient_id", "fill_date", "drug_name", "days_supply"])
        w.writerows(fills)
    print(f"{len(patients)} patients, {len(labs)} lab rows, {len(fills)} fills")


if __name__ == "__main__":
    main()
