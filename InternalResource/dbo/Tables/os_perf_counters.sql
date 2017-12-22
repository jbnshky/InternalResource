CREATE TABLE [dbo].[os_perf_counters] (
    [run_date]      DATETIME    NULL,
    [object_name]   NCHAR (128) NULL,
    [counter_name]  NCHAR (128) NULL,
    [instance_name] NCHAR (128) NULL,
    [cntr_value]    BIGINT      NULL,
    [cntr_type]     INT         NULL
) ON [PRIMARY];

