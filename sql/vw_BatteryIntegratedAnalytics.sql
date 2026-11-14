USE [EVBatteryAnalytics]
GO

/****** Object:  View [dbo].[vw_BatteryIntegratedAnalytics]    Script Date: 14/11/2026 22:39:11 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- Integrated EV Battery Analytics
-- Keep charging exposure separate from warning score

CREATE   VIEW [dbo].[vw_BatteryIntegratedAnalytics]
AS

WITH RankedDaily AS (
    SELECT
        battery_id,
        reading_date,
        equivalent_full_cycles_cum AS EFC,
        estimated_capacity_ah,

        ROW_NUMBER() OVER (
            PARTITION BY battery_id
            ORDER BY reading_date ASC
        ) AS FirstRN,

        ROW_NUMBER() OVER (
            PARTITION BY battery_id
            ORDER BY reading_date DESC
        ) AS LastRN

    FROM dbo.daily_telemetry
),

Lifecycle AS (
    SELECT
        d.battery_id,

        MAX(CASE WHEN FirstRN = 1
            THEN EFC END) AS FirstEFC,

        MAX(CASE WHEN LastRN = 1
            THEN EFC END) AS LastEFC,

        MAX(CASE WHEN FirstRN = 1
            THEN 100.0 * estimated_capacity_ah
            / NULLIF(m.rated_capacity_ah, 0)
        END) AS FirstSOH,

        MAX(CASE WHEN LastRN = 1
            THEN 100.0 * estimated_capacity_ah
            / NULLIF(m.rated_capacity_ah, 0)
        END) AS LastSOH

    FROM RankedDaily d
    JOIN dbo.battery_master m
        ON d.battery_id = m.battery_id

    GROUP BY d.battery_id
),

Charging AS (
    SELECT
        battery_id,
        COUNT(*) AS TotalSessions,

        100.0 * SUM(
            CASE WHEN charge_mode = 'Fast'
            THEN 1 ELSE 0 END
        ) / NULLIF(COUNT(*), 0)
        AS FastChargePct

    FROM dbo.charge_events
    GROUP BY battery_id
),

ChargingThreshold AS (
    SELECT
        c.*,

        PERCENTILE_CONT(0.75)
        WITHIN GROUP (
            ORDER BY c.FastChargePct
        ) OVER (
            PARTITION BY m.chemistry
        ) AS ChemistryP75

    FROM Charging c
    JOIN dbo.battery_master m
        ON c.battery_id = m.battery_id
)

SELECT
    e.battery_id,
    e.chemistry,
    e.reading_date,
    e.BatteryAgeYears,
    e.SOH,
    e.ResistanceGrowthPct,
    e.CellVoltageDelta_mV,
    e.HighTempDays,

    e.LowSOHFlag,
    e.HighResistanceFlag,
    e.CellImbalanceFlag,
    e.ThermalFlag,
    e.EnhancedScore,
    e.InvestigationPriority,

    CAST(
        l.LastEFC - l.FirstEFC
        AS DECIMAL(10,2)
    ) AS ObservedEFC,

    CAST(
        l.FirstSOH - l.LastSOH
        AS DECIMAL(8,3)
    ) AS SOHDecline_pp,

    CAST(
        100.0 * (l.FirstSOH - l.LastSOH)
        / NULLIF(l.LastEFC - l.FirstEFC, 0)
        AS DECIMAL(8,3)
    ) AS DeclinePer100EFC,

    c.TotalSessions,

    CAST(c.FastChargePct AS DECIMAL(6,2))
        AS FastChargePct,

    CAST(c.ChemistryP75 AS DECIMAL(6,2))
        AS ChemistryP75,

    CASE
        WHEN c.FastChargePct IS NULL
          OR c.ChemistryP75 IS NULL
        THEN NULL

        WHEN c.FastChargePct >= c.ChemistryP75
        THEN 1

        ELSE 0
    END AS HighExposureFlag

FROM dbo.vw_BatteryEarlyWarning e

LEFT JOIN Lifecycle l
    ON e.battery_id = l.battery_id

LEFT JOIN ChargingThreshold c
    ON e.battery_id = c.battery_id;

GO
