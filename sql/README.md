# SQL Server (T-SQL) analysis

This directory contains the T-SQL work supporting the independent **synthetic EV battery health and degradation analytics** portfolio.

## Already published

- [Day1_SQL_Server_Exercises.sql](Day1_SQL_Server_Exercises.sql) — initial SQL Server learning and exploration exercises.

## Still to add

- Complete working **view definitions** from the author's SQL Server Management Studio (SSMS) battery analytics database, including the battery-risk-screening and charging-exposure analysis views. These have **not yet been uploaded**.
- Optional final analysis queries that demonstrate fleet summaries and priority investigation results.

## Export from SSMS

In **Object Explorer**, expand the correct battery analytics database → **Views**. For each project view, right-click → **Script View as → CREATE To → File**. Give each script a descriptive `.sql` filename and upload it here.

For a larger group, use **Database → Tasks → Generate Scripts**, select the relevant views, choose **schema only**, and save as a single SQL script. Inspect scripts before publishing: exclude login credentials, machine-specific file paths, connection strings and any non-synthetic business data.

These SQL files document SQL Server code; the repository does not host a live SQL Server database. See [data](../data) for the synthetic CSV inputs and the [Power BI report](../powerbi) for dashboards.
