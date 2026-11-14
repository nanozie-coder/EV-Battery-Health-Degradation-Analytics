/*
EV Battery Health & Lifecycle Analytics — data quality and KPI validation (T-SQL).
Independent synthetic data; no real customer BMS data.
Import data/battery_master.csv, daily_telemetry.csv and charge_events.csv
into dbo tables in EVBatteryAnalytics before executing.
*/
USE EVBatteryAnalytics;
GO

-- Verify input row counts (expected: 24, 2880, 3024).
SELECT 'battery_master' AS dataset, COUNT(*) AS row_count FROM dbo.battery_master
UNION ALL SELECT 'daily_telemetry', COUNT(*) FROM dbo.daily_telemetry
UNION ALL SELECT 'charge_events', COUNT(*) FROM dbo.charge_events;
GO

-- Latest capacity SOH by battery using ROW_NUMBER.
;WITH ranked AS (
  SELECT d.*, ROW_NUMBER() OVER (
    PARTITION BY d.battery_id ORDER BY d.reading_date DESC
  ) AS rn
  FROM dbo.daily_telemetry AS d
)
SELECT d.battery_id, d.reading_date, b.chemistry,
       ROUND(100.0*d.estimated_capacity_ah/NULLIF(b.rated_capacity_ah,0),2) AS SOH_pct
FROM ranked AS d
JOIN dbo.battery_master AS b ON b.battery_id=d.battery_id
WHERE d.rn=1
ORDER BY SOH_pct, d.battery_id;
GO

-- Fleet latest SOH average and count below 90%.
;WITH ranked AS (
  SELECT d.*, ROW_NUMBER() OVER (
    PARTITION BY d.battery_id ORDER BY d.reading_date DESC
  ) AS rn
  FROM dbo.daily_telemetry AS d
),
latest AS (
  SELECT d.battery_id,
         100.0*d.estimated_capacity_ah/NULLIF(b.rated_capacity_ah,0) AS SOH_pct
  FROM ranked AS d
  JOIN dbo.battery_master AS b ON b.battery_id=d.battery_id
  WHERE d.rn=1
)
SELECT COUNT(*) AS PackCount,
       ROUND(AVG(SOH_pct),2) AS AverageSOH_pct,
       SUM(CASE WHEN SOH_pct<90 THEN 1 ELSE 0 END) AS PacksBelow90
FROM latest;
-- Expected: 24, 93.30%, 4.
GO

-- Charging session mix.
SELECT COUNT(*) AS ChargingSessions,
       SUM(CASE WHEN charge_mode='Fast' THEN 1 ELSE 0 END) AS FastSessions,
       ROUND(100.0*SUM(CASE WHEN charge_mode='Fast' THEN 1 ELSE 0 END)
             /NULLIF(COUNT(*),0),2) AS FastShare_pct
FROM dbo.charge_events;
GO

-- High-temperature exposure (illustrative >=45C threshold).
SELECT battery_id, COUNT(*) AS HighTempDays
FROM dbo.daily_telemetry
WHERE max_temp_c>=45
GROUP BY battery_id
ORDER BY HighTempDays DESC, battery_id;
GO

-- Basic telemetry data-quality validation.
SELECT
 SUM(CASE WHEN soc_start_pct NOT BETWEEN 0 AND 100
             OR soc_end_pct NOT BETWEEN 0 AND 100 THEN 1 ELSE 0 END) AS InvalidSOC,
 SUM(CASE WHEN estimated_capacity_ah<=0 THEN 1 ELSE 0 END) AS InvalidCapacity,
 SUM(CASE WHEN avg_temp_c>max_temp_c THEN 1 ELSE 0 END) AS InconsistentTemperature
FROM dbo.daily_telemetry;
GO
