USE [EVBatteryAnalytics]
GO

/****** Object:  View [dbo].[vw_BatteryDiagnostics]    Script Date: 14/11/2026 22:38:19 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- Create a reusable battery diagnostic view

CREATE   VIEW [dbo].[vw_BatteryDiagnostics]
AS

WITH LatestReadings AS (
    SELECT
        d.battery_id,
        m.chemistry,
        d.reading_date,

        CAST(
            DATEDIFF(
                DAY,
                m.commissioned_date,
                d.reading_date
            ) / 365.25
            AS DECIMAL(6,2)
        ) AS BatteryAgeYears,

        CAST(
            100.0 * d.estimated_capacity_ah
            / NULLIF(m.rated_capacity_ah, 0)
            AS DECIMAL(6,2)
        ) AS SOH,

        CAST(
            100.0 *
            (d.resistance_mohm_25c
            - m.baseline_resistance_mohm_25c)
            / NULLIF(
                m.baseline_resistance_mohm_25c, 0
            )
            AS DECIMAL(8,2)
        ) AS ResistanceGrowthPct,

        CAST(
            d.cell_voltage_delta_mv
            AS DECIMAL(8,2)
        ) AS CellVoltageDelta_mV,

        ROW_NUMBER() OVER (
            PARTITION BY d.battery_id
            ORDER BY d.reading_date DESC
        ) AS rn

    FROM dbo.daily_telemetry d
    JOIN dbo.battery_master m
        ON d.battery_id = m.battery_id
)

SELECT
    battery_id,
    chemistry,
    reading_date,
    BatteryAgeYears,
    SOH,
    ResistanceGrowthPct,
    CellVoltageDelta_mV,

    CASE
        WHEN SOH < 90 THEN 1
        ELSE 0
    END AS LowSOHFlag,

    CASE
        WHEN ResistanceGrowthPct >= 30 THEN 1
        ELSE 0
    END AS HighResistanceFlag,

    CASE
        WHEN CellVoltageDelta_mV >= 45 THEN 1
        ELSE 0
    END AS CellImbalanceFlag

FROM LatestReadings
WHERE rn = 1;

GO
