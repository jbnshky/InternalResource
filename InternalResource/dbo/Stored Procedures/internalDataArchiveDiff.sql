
/*Database Differential Backup*/
CREATE PROCEDURE [dbo].[internalDataArchiveDiff] (
	@destination VARCHAR(1000),
	@numbackups SMALLINT = 0,
	@include VARCHAR(8000) = NULL,
	@exclude VARCHAR(8000) = NULL,
	@includereadonly BIT = 0
)
AS
SET NOCOUNT ON
DECLARE @dbname VARCHAR(255)
DECLARE @cmd VARCHAR(8000)
DECLARE @timestamp VARCHAR(20)
DECLARE @pattern VARCHAR(255)
DECLARE @file VARCHAR(1024)
DECLARE @counter SMALLINT
DECLARE @sql VARCHAR(8000)
DECLARE @instancedest VARCHAR(1024)

-- If the trailing slash is included write to that path directly, otherwise add the servername.
If(Right(@destination, 1) != '\')
	Set @instancedest = @destination + '\' + @@SERVERNAME + '\Diff'
Else
	Set @instancedest = left(@destination, datalength(@destination) - 1)

CREATE TABLE #files ([output] VARCHAR(255))
CREATE TABLE #dbs (db VARCHAR(255))

Declare @version real
Set @version = SUBSTRING(CAST(SERVERPROPERTY('ProductVersion') as varchar), 0, CHARINDEX('.', CAST(SERVERPROPERTY('ProductVersion') as varchar), CHARINDEX('.', CAST(SERVERPROPERTY('ProductVersion') as varchar)) + 1))

SET @pattern = N'%[_]db[_]20[0-9][0-9][0-1][0-9][0-3][0-9][0-2][0-9][0-5][0-9].diff'

IF @include IS NOT NULL AND @exclude IS NOT NULL
BEGIN
	RAISERROR ('Parameters @include and @exclude cannot both be specified', 16, 1)
	RETURN
END

SET @sql = '
SELECT name FROM master.sys.databases WHERE recovery_model < 3 ' 
+ COALESCE('AND name NOT IN (''' + REPLACE(@exclude, ',', ''',''') + ''') ', 'AND name IN (''' + REPLACE(@include, ',', ''',''') + ''') ', '') 
+ '
ORDER BY name'

INSERT #dbs EXEC (@sql)

DECLARE dbs CURSOR FAST_FORWARD FOR
	SELECT db FROM #dbs ORDER BY db
OPEN dbs

FETCH NEXT FROM dbs INTO @dbname
WHILE @@FETCH_STATUS = 0
BEGIN
	IF	DATABASEPROPERTYEX(@dbname, 'Status') = 'ONLINE'
		AND (DATABASEPROPERTYEX(@dbname, 'Updateability') = 'READ_WRITE' OR @includereadonly = 1)
	BEGIN
		TRUNCATE TABLE #files 
		set @cmd = 'EXEC master.dbo.xp_cmdshell ''dir /b "' + @instancedest + '\' + @dbname + '\' + @dbname + '_db_"*.diff'''
--		PRINT @cmd
		INSERT #files EXEC (@cmd)

		IF EXISTS (SELECT 1 FROM #files WHERE [output] LIKE 'The system cannot find the%specified.')
		BEGIN
			Set @cmd = 'EXEC master.dbo.xp_cmdshell ''md "' + @instancedest + '\' + @dbname + '"'', no_output'
			EXEC (@cmd)
		END

		SET @timestamp = CONVERT(CHAR(8), GETDATE(), 112) + REPLACE(CONVERT(CHAR(5), GETDATE(), 108), ':', '')
		IF @version >= 10.5
			Set @cmd = 'BACKUP DATABASE [' + @dbname +'] TO DISK = ''' + @instancedest + '\' + @dbname + '\' + @dbname + '_db_' + @timestamp + '.diff'' WITH  DIFFERENTIAL, INIT,COMPRESSION'
		ELSE
			Set @cmd = 'BACKUP DATABASE [' + @dbname +'] TO DISK = ''' + @instancedest + '\' + @dbname + '\' + @dbname + '_db_' + @timestamp + '.diff'' WITH DIFFERENTIAL,INIT'

		EXEC(@cmd)

		Set @cmd = 'RESTORE VERIFYONLY FROM DISK = ''' + @instancedest + '\' + @dbname + '\' + @dbname + '_db_' + @timestamp + '.diff'''
		EXEC (@cmd)

		IF @@ERROR = 0
		BEGIN
			DECLARE files CURSOR STATIC FORWARD_ONLY READ_ONLY FOR
				SELECT RTRIM(LTRIM([output])) AS [file] 
				FROM #files 
				WHERE [output] LIKE @pattern AND [output] NOT LIKE '%' + @timestamp + '%'
				ORDER BY [file]

			OPEN files
			SET @counter = @@CURSOR_ROWS - (@numbackups)
			FETCH NEXT FROM files INTO @file

			WHILE @counter > 0 AND @@FETCH_STATUS = 0
			BEGIN
				Set @cmd = 'EXEC master.dbo.xp_cmdshell ''del /q "' + @instancedest + '\' + @dbname +'\' + @file +'"'', no_output'
				--PRINT (@cmd)
				EXEC (@cmd)

				SET @counter = @counter - 1
				FETCH NEXT FROM files INTO @file
			END
			
			CLOSE files
			DEALLOCATE files		
		END
	END
	FETCH NEXT FROM dbs INTO @dbname
END

CLOSE dbs
DEALLOCATE dbs