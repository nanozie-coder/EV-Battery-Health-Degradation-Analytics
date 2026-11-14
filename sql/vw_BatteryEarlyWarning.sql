USE [EVBatteryAnalytics]
GO

/****** Object:  View [dbo].[vw_BatteryEarlyWarning]    Script Date: 14/11/2026 22:38:46 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- Battery Early Warning View
-- Synthetic training thresholds only

CREATE   VIEW [dbo].[vw_BatteryEarlyWarning]
AS

WITH ThermalExposure AS (
    SELECT
        battery_id,

        SUM(
            CASE
                WHEN max_temp_c >= 45
                THEN 1 ELSE 0
            END
        ) AS HighTempDays

    FROM dbo.daily_telemetry
    GROUP BY battery_id
),

BatteryIndicators AS (
    SELECT
        d.battery_id,
        d.chemistry,
        d.reading_date,
        d.BatteryAgeYears,
        d.SOH,
        d.ResistanceGrowthPct,
        d.CellVoltageDelta_mV,

        d.LowSOHFlag,
        d.HighResistanceFlag,
        d.CellImbalanceFlag,

        COALESCE(t.HighTempDays, 0)
            AS HighTempDays,

        CASE
            WHEN COALESCE(t.HighTempDays, 0) >= 10
            THEN 1 ELSE 0
        END AS ThermalFlag

    FROM dbo.vw_BatteryDiagnostics d

    LEFT JOIN ThermalExposure t
        ON d.battery_id = t.battery_id
),

BatteryScores AS (
    SELECT
        *,

        (
            LowSOHFlag
            + HighResistanceFlag
            + CellImbalanceFlag
            + ThermalFlag
        ) AS EnhancedScore

    FROM BatteryIndicators
)

SELECT
    *,

    CASE
        WHEN EnhancedScore >= 2
            THEN 'Priority Review'
        WHEN EnhancedScore = 1
            THEN 'Monitor'
        ELSE 'Routine Monitoring'
    END AS InvestigationPriority

FROM BatteryScores;

GO
