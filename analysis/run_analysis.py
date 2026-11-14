"""Reproduce key results for an independent synthetic EV battery case study.
Run from the repository root: python analysis/run_analysis.py
Requirements: pandas, numpy, scipy.
"""
from pathlib import Path
import json
import numpy as np
import pandas as pd
from scipy.stats import pearsonr

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"
OUT = ROOT / "analysis"

master = pd.read_csv(DATA / "battery_master.csv", parse_dates=["commissioned_date"])
daily = pd.read_csv(DATA / "daily_telemetry.csv", parse_dates=["reading_date"])
events = pd.read_csv(DATA / "charge_events.csv", parse_dates=["event_datetime"])

assert (len(master), len(daily), len(events)) == (24, 2880, 3024)
assert master.battery_id.is_unique
assert daily.battery_id.isin(master.battery_id).all()
assert events.battery_id.isin(master.battery_id).all()
assert (master.rated_capacity_ah > 0).all()

obs = daily.merge(master, on="battery_id", validate="many_to_one")
obs = obs.sort_values(["battery_id", "reading_date"])
obs["SOH_pct"] = 100 * obs.estimated_capacity_ah / obs.rated_capacity_ah

initial = obs.groupby("battery_id").first()
latest = obs.groupby("battery_id").last()
pack = pd.DataFrame(index=latest.index)
pack["Chemistry"] = latest.chemistry
pack["LatestSOH_pct"] = latest.SOH_pct
pack["SOHDecline_pp"] = initial.SOH_pct - latest.SOH_pct
pack["ObservedEFC"] = latest.equivalent_full_cycles_cum - initial.equivalent_full_cycles_cum
pack["DeclinePer100EFC_pp"] = 100 * pack.SOHDecline_pp / pack.ObservedEFC.replace(0, np.nan)
pack["BatteryAgeYears"] = (
    (pd.Timestamp("2026-10-28") - latest.commissioned_date).dt.days / 365.25
).round(2)
pack["HighTempDays"] = (daily.max_temp_c >= 45).groupby(daily.battery_id).sum()
pack["HighImbalanceDays"] = (daily.cell_voltage_delta_mv >= 45).groupby(daily.battery_id).sum()
pack["LatestCellDelta_mV"] = latest.cell_voltage_delta_mv
pack["ResistanceGrowth_pct"] = 100 * (
    latest.resistance_mohm_25c / latest.baseline_resistance_mohm_25c - 1
)
pack["FastChargeShare_pct"] = 100 * (
    events.charge_mode == "Fast"
).groupby(events.battery_id).mean()
pack["ScreeningScore"] = (
    (pack.LatestSOH_pct < 90).astype(int)
    + (pack.ResistanceGrowth_pct >= 30).astype(int)
    + (pack.LatestCellDelta_mV >= 45).astype(int)
    + (pack.HighTempDays >= 10).astype(int)
)
pack["ScreeningClass"] = np.select(
    [pack.ScreeningScore >= 2, pack.ScreeningScore == 1],
    ["Priority Review", "Monitor"],
    default="Routine Monitoring",
)
pack["HighChargingExposure"] = (
    pack.FastChargeShare_pct >= pack.FastChargeShare_pct.quantile(0.75)
)
pack.index.name = "battery_id"
pack.reset_index().to_csv(OUT / "battery_level_metrics.csv", index=False)

rows = []
for label, group in [
    ("Full fleet", pack),
    ("LFP", pack[pack.Chemistry == "LFP"]),
    ("NMC", pack[pack.Chemistry == "NMC"]),
]:
    for label_x, column in [
        ("High-temperature days", "HighTempDays"),
        ("Battery age", "BatteryAgeYears"),
        ("Fast-charging share", "FastChargeShare_pct"),
    ]:
        r, p = (
            pearsonr(group[column], group.DeclinePer100EFC_pp)
            if group[column].nunique() > 1 else (np.nan, np.nan)
        )
        rows.append({
            "Group": label, "Driver": label_x, "N": len(group),
            "Pearson_r": r, "Parametric_p": p,
        })
pd.DataFrame(rows).to_csv(OUT / "correlation_summary.csv", index=False)

nmc = pack[pack.Chemistry == "NMC"]
loo_rows = []
for battery_id in nmc.index:
    subset = nmc.drop(battery_id)
    r, p = (
        pearsonr(subset.HighTempDays, subset.DeclinePer100EFC_pp)
        if subset.HighTempDays.nunique() > 1 else (np.nan, np.nan)
    )
    loo_rows.append({
        "ExcludedBattery": battery_id, "N": len(subset),
        "ExposedRemaining": int((subset.HighTempDays > 0).sum()),
        "Pearson_r": r, "Parametric_p": p,
    })
pd.DataFrame(loo_rows).to_csv(OUT / "nmc_leave_one_out.csv", index=False)

observed_r = pearsonr(nmc.HighTempDays, nmc.DeclinePer100EFC_pp)[0]
permuted = []
for i in range(len(nmc)):
    assigned = np.zeros(len(nmc))
    assigned[i] = nmc.HighTempDays.max()
    permuted.append(pearsonr(assigned, nmc.DeclinePer100EFC_pp)[0])
exact_p = float(np.mean(np.abs(permuted) >= abs(observed_r) - 1e-12))

summary = {
    "synthetic_data": True,
    "batteries": len(master),
    "telemetry_rows": len(daily),
    "charge_events": len(events),
    "average_latest_soh_pct": round(float(pack.LatestSOH_pct.mean()), 2),
    "priority_review": int((pack.ScreeningClass == "Priority Review").sum()),
    "monitor": int((pack.ScreeningClass == "Monitor").sum()),
    "routine_monitoring": int((pack.ScreeningClass == "Routine Monitoring").sum()),
    "nmc_exact_conditional_permutation_p": exact_p,
}
(OUT / "verified_summary.json").write_text(json.dumps(summary, indent=2) + "\n")
print(json.dumps(summary, indent=2))
