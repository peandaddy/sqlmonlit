
USE master;
GO
IF DB_ID (N'SqlMonLit') IS NOT NULL
DROP DATABASE SqlMonLit;
GO
CREATE DATABASE SqlMonLit;
GO

USE SqlMonLit;
GO

-- 1. CPU
CREATE Or ALTER PROCEDURE usp_SQLMonLit_CPU
AS
BEGIN
    SELECT TOP 1
    -- record_id,
    -- DATEADD(ms, -1 * ((SELECT ms_ticks FROM sys.dm_os_sys_info) - [timestamp]), GETDATE()) AS EventTime,
    SQLProcessUtilization,
    SystemIdle,
    (100 - SystemIdle - SQLProcessUtilization) AS OtherProcessUtilization
	, cpu_count = (SELECT cpu_count FROM sys.dm_os_sys_info)
FROM 
(
    SELECT 
        record.value('(./Record/@id)[1]', 'int') AS record_id,
        record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int') AS SystemIdle,
        record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int') AS SQLProcessUtilization,
        [timestamp]
    FROM 
    (
        SELECT 
            TIMESTAMP, 
            CONVERT(XML, record) AS record
        FROM sys.dm_os_ring_buffers 
        WHERE ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR'
        AND record LIKE '%<SystemHealth>%'
    ) AS x
) AS y
ORDER BY record_id DESC;
END;
GO

-- 2. Memory
CREATE OR ALTER PROCEDURE usp_SQLMonLit_Memory
AS
BEGIN
SELECT 
    CAST(SUM(CASE WHEN counter_name = 'Total Server Memory (KB)' THEN cntr_value ELSE 0 END) / 1024.0 AS DECIMAL(15,2)) AS total_server_memory_mb,
    --CAST(SUM(CASE WHEN counter_name = 'Target Server Memory (KB)' THEN cntr_value ELSE 0 END) / 1024.0 AS DECIMAL(15,2)) AS target_server_memory_mb,
    --CAST(SUM(CASE WHEN counter_name = 'Available MBytes' THEN cntr_value ELSE 0 END) AS DECIMAL(15,2)) AS available_memory_mb,
    (SELECT CAST((physical_memory_in_use_kb / 1024.0) as DECIMAL(15,2)) FROM sys.dm_os_process_memory) AS memory_in_use_mb,
    (SELECT CAST((total_physical_memory_kb / 1024.0) as DECIMAL(15,2)) FROM sys.dm_os_sys_memory) AS total_physical_memory_mb,
    (SELECT CAST((available_physical_memory_kb / 1024.0) as DECIMAL(15,2)) FROM sys.dm_os_sys_memory) AS available_physical_memory_mb,
    SERVERPROPERTY('ServerName') AS server_name,
    @@VERSION AS sql_server_version
    -- , GETDATE() AS current_date_time
    , (SELECT cpu_count FROM sys.dm_os_sys_info) AS cpu_count
FROM sys.dm_os_performance_counters
WHERE counter_name IN ('Total Server Memory (KB)', 'Target Server Memory (KB)', 'Available MBytes')
GROUP BY object_name;
END
GO

-- 3. Tempdb
CREATE or ALTER PROCEDURE usp_SQLMonLit_Tempdb
AS
BEGIN

;WITH CTE as (
	SELECT DB_NAME() as [DatabaseName],
	       f.name AS [DBLogicalFileName],
	       f.physical_name AS [PhysicalFileName],
	       CAST((f.size / 128.0) AS DECIMAL(15, 2)) AS [TotalSizeMB],
	       CAST(CAST(FILEPROPERTY(f.name, 'SpaceUsed') AS int) / 128.0 AS DECIMAL(15, 2)) AS [CurrentDBSizeMB],
	       CAST(f.size / 128.0 - CAST(FILEPROPERTY(f.name, 'SpaceUsed') AS int) / 128.0 AS DECIMAL(15, 2)) AS [AvailableSizeMB],
	       CAST(CAST(CAST(FILEPROPERTY(f.name, 'SpaceUsed') AS int) / 128.0 AS DECIMAL(15, 2))
	            / CAST((f.size / 128.0) AS DECIMAL(15, 2)) * 100 as DECIMAL(15, 2)) AS [PercentUsed],
	       [file_id] as [FileID],
	       fg.name AS [FileGroupName]
	FROM tempdb.sys.database_files AS f WITH (NOLOCK)
	    LEFT OUTER JOIN tempdb.sys.data_spaces AS fg WITH (NOLOCK)
	        ON f.data_space_id = fg.data_space_id
)
SELECT 
 sum([TotalSizeMB]) as [Total_SizeMB]
, sum([TotalSizeMB]) - 
  sum(case when [FileID] = 2 then [TotalSizeMB] else 0 end) as [Provisioned_DBSizeMB]
, sum(case when [FileID] = 2 then 0 else [CurrentDBSizeMB] end) as [Used_DBSizeMB]
, sum(case when [FileID] = 2 then [TotalSizeMB] else 0 end) as [Provisioned_LogSizeMB]
, sum(case when [FileID] = 2 then [CurrentDBSizeMB] else 0 end) as [Used_LogSizeMB]
FROM CTE
GROUP BY [DatabaseName]

END
GO

-- 4. Batch/Disk
CREATE or ALTER PROCEDURE usp_SQLMonLit_Batch
AS
BEGIN
DECLARE @v1_BatchReq BIGINT, @v2_PageLife BIGINT, @v3_BufferHit BIGINT, @v4_BufferSize BIGINT;
DECLARE @delay SMALLINT = 2; -- Adjustable interval in seconds
DECLARE @time DATETIME;

-- Set the delay time
SET @time = DATEADD(SECOND, @delay, '00:00:00');

-- Capture initial values
SELECT 
    @v1_BatchReq = CASE WHEN counter_name = 'Batch Requests/sec' THEN cntr_value ELSE @v1_BatchReq END,
    @v2_PageLife = CASE WHEN counter_name = 'Page life expectancy' THEN cntr_value ELSE @v2_PageLife END,
    @v3_BufferHit = CASE WHEN counter_name = 'Buffer cache hit ratio' THEN cntr_value ELSE @v3_BufferHit END,
    @v4_BufferSize = CASE WHEN counter_name = 'Total Server Memory (KB)' THEN cntr_value ELSE @v4_BufferSize END
FROM master.sys.dm_os_performance_counters
WHERE counter_name IN ('Batch Requests/sec', 'Page life expectancy', 
                      'Buffer cache hit ratio', 'Total Server Memory (KB)');

-- Wait for the specified interval
WAITFOR DELAY @time;

-- Calculate and return metrics in one row with 2 decimal places
SELECT TOP 1
    CAST(ROUND(CAST((br.cntr_value - @v1_BatchReq) AS DECIMAL(18,2)) / @delay, 2) AS DECIMAL(18,2)) AS AvgBatchRequestsPerSec,
    CAST(ROUND(ple.cntr_value * 1.0, 2) AS DECIMAL(18,2)) AS PageLifeExpectancySec,
    --CAST(ROUND(bhr.cntr_value / 100.0, 2) AS DECIMAL(18,2)) AS BufferCacheHitRatioPercent,
	CAST(ROUND((1.0 - (CAST(bhrb.cntr_value AS FLOAT) / CAST(bhr.cntr_value AS FLOAT))) * 100, 2) AS DECIMAL(5, 2)) AS BufferCacheHitRatioPercent,
    CAST(ROUND(tsm.cntr_value / 1024.0 / 1024.0, 2) AS DECIMAL(18,2)) AS TotalServerMemoryGB
FROM master.sys.dm_os_performance_counters
CROSS APPLY (SELECT cntr_value FROM master.sys.dm_os_performance_counters WHERE counter_name = 'Batch Requests/sec') br
CROSS APPLY (SELECT cntr_value FROM master.sys.dm_os_performance_counters WHERE counter_name = 'Page life expectancy') ple
CROSS APPLY (SELECT cntr_value FROM master.sys.dm_os_performance_counters WHERE counter_name = 'Buffer cache hit ratio') bhr
CROSS APPLY (SELECT cntr_value FROM master.sys.dm_os_performance_counters WHERE counter_name = 'Buffer cache hit ratio base') bhrb
CROSS APPLY (SELECT cntr_value FROM master.sys.dm_os_performance_counters WHERE counter_name = 'Total Server Memory (KB)') tsm
WHERE counter_name IN ('Batch Requests/sec', 'Page life expectancy', 
                      'Buffer cache hit ratio', 'Total Server Memory (KB)');
END
GO

-- 5. Activity
CREATE or ALTER PROCEDURE usp_SQLMonLit_Activity
AS
BEGIN
/*
blocked processes and deadlocks

This query includes:

blocked_processes: Current count of blocked processes
total_deadlocks: Cumulative number of deadlocks since last SQL Server restart
avg_wait_time_ms: Average wait time in milliseconds for current requests
signal_wait_pct: Percentage of waits related to CPU scheduling
page_life_exp_sec: Buffer pool page life expectancy in seconds
active_user_connections: Current number of user connections
*/
SELECT 
    (SELECT COUNT(*) FROM sys.dm_exec_sessions WHERE is_user_process = 1) AS UserConnections,
    (SELECT COUNT(*) FROM sys.dm_exec_sessions WHERE is_user_process = 0) AS SystemConnections,
    (SELECT COUNT(*) FROM sys.dm_exec_connections) AS TotalConnections,
	(SELECT COUNT(*) FROM sys.dm_exec_sessions WHERE status = 'running' AND is_user_process = 1) AS ActiveUserSessions,

    CAST((SELECT COUNT(*) 
          FROM sys.dm_exec_requests 
          WHERE blocking_session_id <> 0) AS DECIMAL(10,2)) AS blocked_processes,
    CAST((SELECT cntr_value 
          FROM sys.dm_os_performance_counters 
          WHERE counter_name = 'Number of Deadlocks/sec' 
          AND instance_name = '_Total') AS DECIMAL(10,2)) AS total_deadlocks,
    CAST((SELECT AVG(wait_time) 
          FROM sys.dm_exec_requests 
          WHERE session_id > 50) AS DECIMAL(10,2)) AS avg_wait_time_ms,
    CAST((SELECT SUM(signal_wait_time_ms) * 1.0 / SUM(wait_time_ms) * 100 
          FROM sys.dm_os_wait_stats 
          WHERE wait_time_ms > 0) AS DECIMAL(10,2)) AS signal_wait_pct,
    CAST((SELECT cntr_value * 1.0 / 1000 
          FROM sys.dm_os_performance_counters 
          WHERE counter_name = 'Page life expectancy' 
          AND object_name LIKE '%Buffer Manager%') AS DECIMAL(10,2)) AS page_life_exp_sec,
    CAST((SELECT COUNT(*) 
          FROM sys.dm_exec_sessions 
          WHERE is_user_process = 1) AS DECIMAL(10,2)) AS active_user_connections

END
GO