USE [EVBatteryAnalytics]
GO

/****** Object:  View [dbo].[vw_BatteryDailyTrends]    Script Date: 14/11/2026 22:37:46 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- Daily battery trends for Power BI

CREATE   VIEW [dbo].[vw_BatteryDailyTrends]
AS

SELECT
    d.battery_id,
    d.reading_date,
    m.chemistry,

    CAST(
        100.0 * d.estimated_capacity_ah
        / NULLIF(m.rated_capacity_ah, 0)
        AS DECIMAL(6,2)
    ) AS DailySOH,

    d.equivalent_full_cycles_cum
        AS CumulativeEFC,

    d.max_temp_c AS MaxTempC,

    d.cell_voltage_delta_mv
        AS CellVoltageDelta_mV

FROM dbo.daily_telemetry d

JOIN dbo.battery_master m
    ON d.battery_id = m.battery_id;

GO
