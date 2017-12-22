/*
**	Returns a summary of file space usage from the table:
**		[health].[fileSpaceUsage]
**	Data in the table is controlled via the procedures:
**		[health].[saveFileSpaceUsage]
**		[health].[purgeFileSpaceUsage]
**
**	Parameters:
**		@detailLevel tinyint; default:  0
**			Use this parameter to control how much information to return. 
**			The output can return multiple detail levels if 1 is passed in
**			for the @reportLowerLevels.
**			>=0:  (default)	Mountpoint usage summary from the latest capture.
**					Includes data from all drives/mountpoints that have sql
**					data or log files on them.
**			>=1:  Aggregations over mountpoint, database, and filegroup from 
**					the latest capture. 
**			>=2:	File level details from the latest capture.
**			>=3:	Trends from the first capture to the most recent (TODO)
**		@reportLowerLevels bit; default: 1
**			When 1, this causes results to be returned for all detail levels
**			that are less than or equal to the @detailLevel passed in.
**
**	Example:
	-- Mountpoint summary
		exec health.reportFileSpaceUsage 0
	-- mp/db/filegroup detail
		exec health.reportFileSpaceUsage 1
	-- File level detail
		exec health.reportFileSpaceUsage 2
	-- All result sets from detail levels 0, 1, and 2.
		exec health.reportFileSpaceUsage 2,1
*/
create procedure [health].[reportFileSpaceUsage]
	@detailLevel tinyint = 0
	, @reportLowerLevels bit = 1
as
begin
	set nocount on;

	declare 
		@latest smalldatetime
		, @earliest smalldatetime;

	select 
		@latest = max(captureDate)
		, @earliest = 
			case 
				when @detailLevel >= 3 then min(captureDate)
				else max(capturedate)
			end
	from [health].[fileSpaceUsage];


	if @detailLevel = 0 or (@reportLowerLevels = 1 and @detailLevel > 0)
	begin
		/* Mountpoint aggregation */
		select 
			min(drive) as drive
			, mp as [mountPoint]
			, min(mpTotalMB) as mpTotalMB
			, min(mpAvailableMB) as mpAvailableMB
			, min(convert(numeric(18, 2), (100. - (mpAvailableMB / mpTotalMB) * 100.))) as [mpUsedPercent]
			, max(captureDate) as captureDate
		from 
			[health].fileSpaceUsage
		where 
			captureDate between @earliest and @latest
		group by 
			mp
		order by 
			min(drive), mp;
	end

	if @detailLevel = 1 or (@reportLowerLevels = 1 and @detailLevel > 1)
	begin
		/* Aggregations over filegroup, database, and mountpoint from the latest capture.  */
		select 
			case 
				when grouping(dbName) = 1 then '*' 
				else dbName
			  end as [dbName]
			, case 
				when grouping(mp) = 1 then '*'
				else mp
			end as [mountPoint]
			, case
				when grouping(mp) = 0 and grouping(dbName) = 0 and grouping(fg) = 1 then '*' --fg 
				when grouping(mp) = 1 and grouping(dbName) = 0 and grouping(fg) = 1 then '*' --mp & fg
				when grouping(mp) = 0 and grouping(dbName) = 1 and grouping(fg) = 1 then '*' --db & fg
				else fg
			  end as [fileGroup]
			, sum(dbUsedMB) as dbUsedMB
			, sum(dbFreeMB) as dbUnusedMB
			, sum(dbUsedMB + dbFreeMB) as dbTotalMB
			, max(captureDate) as captureDate
		from 
			[health].fileSpaceUsage
		where 
			captureDate between @earliest and @latest
		group by 
			grouping sets(mp, dbName, (mp, dbName), (mp, dbName, fg));
	end

	if @detailLevel >= 2 or (@reportLowerLevels = 1 and @detailLevel > 2)
	begin
		/* File detail for the latest capture.  */
		select 
			dbName 
			, fg as [fileGroup]
			, fileId 
			, logicalName
			, fileSizeMB 
			, dbUsedMB
			, dbFreeMB 
			, dbFreePercent =  convert(numeric(18,2), (dbFreeMB * 1. / fileSizeMB * 1.) * 100 )
			, drive 
			, mp as [mountPoint]
			, mpTotalMB 
			, mpAvailableMB 
			, mpFreePercent = convert(numeric(18,2), (mpAvailableMB * 1. / (mpTotalMB * 1.)) * 100)
			, physicalName 
			, captureDate	
		from 
			[health].fileSpaceUsage
		where 
			captureDate between @earliest and @latest
		order by 
			dbName, [fileGroup], fileId;
	end

/*
	Trends from the first capture to the most recent are not implemented yet.
	if @detailLevel = 3 or (@reportLowerLevels = 1 and @detailLevel > 3)
	begin
	end
*/
end