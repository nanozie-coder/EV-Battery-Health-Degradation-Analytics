# SQL Server analytical views

Four T-SQL `CREATE VIEW` scripts exported from the working **EVBatteryAnalytics** database in SQL Server Management Studio are now published here, alongside the starter exercises.

## Published scripts

Run the view scripts in this dependency order:

1. [`vw_BatteryDailyTrends.sql`](vw_BatteryDailyTrends.sql) — date-level SOH, cumulative EFC, thermal and voltage-spread trends (independent).
2. [`vw_BatteryDiagnostics.sql`](vw_BatteryDiagnostics.sql) — latest battery snapshot, SOH, resistance growth and diagnostic flags.
3. [`vw_BatteryEarlyWarning.sql`](vw_BatteryEarlyWarning.sql) — combines diagnostics and historical high-temperature days into an illustrative four-flag investigation score; depends on **BatteryDiagnostics**.
4. [`vw_BatteryIntegratedAnalytics.sql`](vw_BatteryIntegratedAnalytics.sql) — lifecycle-normalised decline and chemistry-specific 75th-percentile fast-charging exposure; depends on **BatteryEarlyWarning**.

Also published: [`Day1_SQL_Server_Exercises.sql`](Day1_SQL_Server_Exercises.sql), the starter exercises.

## Reproduction requirements

These scripts use `USE [EVBatteryAnalytics]` and assume the following base tables already exist and are populated: `dbo.battery_master`, `dbo.daily_telemetry`, and `dbo.charge_events`. Their synthetic CSV sources are published in [data/](../data/).

The scripts are **not** a complete database build: importing the CSVs, creating base tables, and adjusting data types are separate prerequisites. `GO` is an SSMS/sqlcmd batch separator. `CREATE VIEW` requires that the view not already exist; for an existing view, use a suitable `ALTER VIEW` or `CREATE OR ALTER VIEW` procedure.

Screening cutoffs (SOH <90%, resistance growth ≥30%, cell spread ≥45 mV, or ≥10 days at 45°C+) are **illustrative learning thresholds**, not certified manufacturer safety limits. High fast-charging exposure is kept **separate** from the early-warning risk score. Correlations and screening scores do not establish causation or predict failure.

These view definitions have been reviewed against the synthetic source data for basic logic and expected aggregate flags but have **not** been executed against a live SQL Server instance in this review.
