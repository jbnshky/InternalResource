CREATE TABLE [dbo].[BackupPathConfiguration] (
    [Step]   TINYINT      NOT NULL,
    [Path]   VARCHAR (98) NOT NULL,
    [Active] BIT          NOT NULL,
    CONSTRAINT [LimitStepTo4] CHECK ([Step]<=(4))
) ON [PRIMARY];


GO
CREATE UNIQUE NONCLUSTERED INDEX [fi_BackupPathConfig_Active]
    ON [dbo].[BackupPathConfiguration]([Active] ASC) WHERE ([Active]=(1)) WITH (FILLFACTOR = 90)
    ON [PRIMARY];

