# Data dictionary and engineering conventions

**All records are synthetic.** No actual battery-swap operator, MOCX/Rechaj asset, manufacturer BMS record, client site, or personal record is represented.

| Source | Rows | Grain |
|---|---:|---|
| battery_master.csv | 24 | One row per battery pack |
| daily_telemetry.csv | 2,880 | One row per pack per date, 120 days |
| charge_events.csv | 3,024 | One row per charge event |

## Calculations

- Latest SOH (%) = 100 × last estimated capacity (Ah) / rated capacity (Ah).
- SOH decline (percentage points) = first observed SOH − last observed SOH.
- Observed EFC = last cumulative EFC − first cumulative EFC.
- SOH decline per 100 EFC = SOH decline (pp) × 100 / observed EFC.
- Resistance growth (%) = 100 × (latest 25°C-normalised resistance / baseline resistance − 1).
- High-temperature days = count of days with maximum temperature ≥45°C.
- High-imbalance days = count of days with cell-voltage delta ≥45 mV.
- Fast-charge share (%) = 100 × Fast charge sessions / all sessions for that pack.

## Educational screening score

One point is assigned per condition: latest SOH below 90%; resistance growth at least 30%; latest cell-voltage delta at least 45 mV; high-temperature days at least 10. Two or more points = Priority Review; one = Monitor; zero = Routine Monitoring. Top-quartile fast charging is shown as context, *not* included in the four-point score.

**These are illustrative screening cutoffs, not manufacturer limits or instructions to remove batteries from service.** The data do not establish failure causes, true risk probabilities, lifetime predictions, or warranted device performance.

## Inference limitations

NMC temperature correlation r ≈ +0.947 is dominated by one exposed pack (SYN-BAT-018). Excluding this pack leaves no temperature-predictor variation and makes Pearson r undefined. A conditional exact permutation of the single exposure among eight packs yields a two-sided p-value of 0.125. This is not causal evidence.
