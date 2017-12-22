/*
**	Captures and reports file space usage details while saving a copy of the 
**	results to the table [health].[fileSpaceUsage].
**	Databases that are offline or aren't readable are included in the output
**	but have null values for size values.
**
**	Parameters:
**		@minDbId int; default: 1
**			Use this to include or exclude the capture of system databases.
**			Set it to 1 to include all system databases.
**			Databases with a sysdatabases.database_id that is lower than @minDbId
**			will be skipped.
**
**	Example:
		-- Capture space usage for user databases
		exec health.saveFileSpaceUsage 4

		-- Capture system and user databases
		exec health.saveFileSpaceUsage
*/
create procedure [health].[saveFileSpaceUsage]
	@minDbId int = 1
as 
begin
	set nocount on;
	declare @sysfilesSQL varchar(max)
		, @dt varchar(30) = convert(varchar(30), getdate())

	set @sysfilesSQL = 
		replace
		(
			stuff
			((
				select 
					/*  2008R2 sp1 - 2016  */
					'use ' + quotename(d.[name]) + '; '
					+ 'insert [InternalResource].[health].[fileSpaceUsage] '
					+ 'select ''' + d.[name] + ''''
					+ ', isnull(filegroup_name(df.data_space_id),''Log'')'
					+ ', df.file_id'
					+ ', df.size/128.'
					+ ', fileproperty(df.name, ''SpaceUsed'')/128.'
					+ ', (df.size - fileproperty(df.name, ''SpaceUsed''))/128.'
					+ ', df.name'
					+ ', upper(left(df.physical_name, 2))'
					+ ', upper(vs.volume_mount_point)'
					+ ', df.physical_name'
					+ ', vs.total_bytes/1024./1024.'
					+ ', vs.available_bytes/1024./1024.'
					+ ', ''' + @dt + ''' '
					+ 'from ' + quotename(d.[name]) + '.sys.database_files df '
					+ 'cross apply sys.dm_os_volume_stats(' + convert(varchar, d.database_id) + ', df.file_id) vs '  collate database_default
					+ 'where df.size > 0;'
				from master.sys.databases d
				where 
					compatibility_level > 80
					and state_desc = 'ONLINE'
					and database_id >= @minDbId
				for xml path('')
			), 1, 0, '')
			, '&gt;', '>'
		);

	exec(@sysfilesSQL);

	-- Marker entries for offline and AG secondary dbs
	insert [InternalResource].[health].[fileSpaceUsage]
	select 
		[name] + ' (offline)', 'offline', 0, null, null, null, 'offline', '', ' offline', 'offline', null, null, @dt
	from sys.databases
	where state != 0
	union 
	select 
		[name] + ' (secondary)', 'secondary', 0, null, null, null, 'secondary', '', ' secondary', 'secondary', null, null, @dt
	from 
		sys.databases d
		left join sys.dm_hadr_availability_replica_states rs
			on d.replica_id = rs.replica_id
	where rs.role = 2	-- AG secondaries 


	/* Report details from this run.  */
	exec health.reportFileSpaceUsage @detailLevel = 2, @reportLowerLevels = 1;
end