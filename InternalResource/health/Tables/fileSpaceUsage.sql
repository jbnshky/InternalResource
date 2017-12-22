CREATE TABLE [health].[fileSpaceUsage] (
    [dbName]        [sysname]       NULL,
    [fg]            [sysname]       NULL,
    [fileId]        INT             NULL,
    [fileSizeMB]    NUMERIC (18, 2) NULL,
    [dbUsedMB]      NUMERIC (18, 2) NULL,
    [dbFreeMB]      NUMERIC (18, 2) NULL,
    [logicalName]   [sysname]       NULL,
    [drive]         VARCHAR (2)     NULL,
    [mp]            NVARCHAR (512)  NULL,
    [physicalName]  NVARCHAR (260)  NULL,
    [mpTotalMB]     NUMERIC (18, 2) NULL,
    [mpAvailableMB] NUMERIC (18, 2) NULL,
    [captureDate]   SMALLDATETIME   NULL,
    [captureId]     BIGINT          IDENTITY (1, 1) NOT NULL,
    CONSTRAINT [PKC_fileSpaceUsage_id] PRIMARY KEY CLUSTERED ([captureId] ASC) WITH (FILLFACTOR = 90) ON [PRIMARY]
);

