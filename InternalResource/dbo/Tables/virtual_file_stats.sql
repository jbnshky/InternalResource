CREATE TABLE [dbo].[virtual_file_stats] (
    [Stat_date]            DATETIME      NULL,
    [database_id]          SMALLINT      NULL,
    [file_id]              SMALLINT      NULL,
    [sample_ms]            BIGINT        NULL,
    [num_of_reads]         BIGINT        NULL,
    [num_of_bytes_read]    BIGINT        NULL,
    [io_stall_read_ms]     BIGINT        NULL,
    [num_of_writes]        BIGINT        NULL,
    [num_of_bytes_written] BIGINT        NULL,
    [io_stall_write_ms]    BIGINT        NULL,
    [io_stall]             BIGINT        NULL,
    [size_on_disk_bytes]   BIGINT        NULL,
    [file_handle]          VARBINARY (8) NULL
) ON [PRIMARY];

