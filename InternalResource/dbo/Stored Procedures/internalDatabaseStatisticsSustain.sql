create procedure [dbo].[internalDatabaseStatisticsSustain]
	@TimeLimitMins smallint = 120
	, @MinAgeDays tinyint = 2
as
set nocount on;

-- req'd for computed columns, indexed views, and filtered indexes
set ansi_warnings on;

declare	
	  @Sql			varchar(max)
	, @DbName		varchar(64)
	, @SchemaName	varchar(64)
	, @ObjectName	varchar(64)
	, @StartTime	datetime = current_timestamp
	, @MinUserDbId	tinyint = 0
	, @RID			smallint = 0;

if object_id('tempdb..#Status') is not null	
	drop table #Status;

create table #Status
(
	  RowId smallint identity(1,1) primary key clustered
	, DatabaseId int
	, DatabaseName varchar(64)
	, ObjectId	int
	, PageCount int
	, SchemaName varchar(64) null
	, ObjectName varchar(64) null
	, LastUpdateDate datetime
	, ScanDate datetime
);

while(@MinUserDbId is not null)
begin

	set @MinUserDbId = 
	(
		select min(database_id)
		from sys.databases
		where 
			[state] = 0
			and database_id > 4
			and database_id > @MinUserDbId
	);

	if @MinUserDbId is null break;

	select @Sql = replace(replace(
		'
		select distinct
			@@dbId						as DatabaseId
			, ''@@dbName''				as DatabaseName
			, t.[object_id]				as ObjectId
			, sum(ps.used_page_count) over(partition by ps.[object_id], ps.index_id) as [PageCount]
			, s.name					as SchemaName
			, t.name					as ObjectName
			, coalesce(min(sp.last_updated), ''1900-01-01'') as StatsDate
			, current_timestamp			as ScanDate
		from 
			[@@dbName].sys.dm_db_partition_stats as ps
			inner join [@@dbName].sys.tables	as t	on t.[object_id]	= ps.[object_id]
			inner join [@@dbName].sys.schemas	as s	on s.[schema_id]	= t.[schema_id]
			inner join [@@dbName].sys.stats		as stat on stat.[object_id] = t.[object_id]
			cross apply [@@dbName].sys.dm_db_stats_properties(stat.[object_id], stat.stats_id) as sp
		where 
			ps.row_count > 0
		group by 
			  s.[name]
			, t.[name]
			, t.[object_id]
			, ps.index_id
			, ps.used_page_count
			, ps.[object_id];
		'
		, '@@dbName', [name])
		, '@@dbId', @MinUserDbId)
	from 
		master.sys.databases 
	where 
		database_id = @MinUserDbId;

	insert into #Status exec(@Sql);
end

while(datediff(minute, @StartTime, current_timestamp) < @TimeLimitMins)
begin 
	select top 1 
		  @RID = RowId
		, @DbName = DatabaseName
		, @SchemaName = SchemaName
		, @ObjectName = ObjectName
	from #Status 
	where 
		datediff(dd, LastUpdateDate, current_timestamp) >= @MinAgeDays
	order by 
		LastUpdateDate asc
		, [PageCount] desc
		, ObjectName asc;
	
	if @@rowcount = 0 break;

	set @Sql = 
		'update statistics '
			+ quotename(@DbName) + '.' 
			+ quotename(@SchemaName) + '.' 
			+ quotename(@ObjectName) 
		+ ' with fullscan, columns;';

	exec(@Sql);
	delete from #Status where RowId = @RID;
end