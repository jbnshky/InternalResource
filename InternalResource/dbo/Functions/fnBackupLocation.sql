/*
**	Returns the active backup path as varchar(1024).  
**	Requires SS2012+ (for the AG object references).  
**
**	This funtion depends on the presence and population of table:
**		[dbo].[BackupPathConfiguration]  
**	If the table is empty null is returned, so the caller should validate 
**	the return value.  
**	
**	A trailing slash is included so the output is compatible with the backup 
**	procedures.  The AG name is not added to the output, only the cluster name.
**	
**	Parameters:
**		@backupType varchar(5); default: 'Full'
**			Expects one of three literal strings:  'Full', 'Diff', 'TLog'
**			This value is integrated into the output.
**
**		@forAG tinyint; default: 0
**			When @forAg == 1 and the instance is part of an AG, the cluster 
**			name is appended to the root backup path.  If it is not in an AG 
**			or @forAG == 0, then @@servername is used. 
**	
**	Example:
		select 
			  dbo.fnBackupLocation(null, null) [Full, non-AG path (default)]
			, dbo.fnBackupLocation('Full', 0)  [Full, non-AG path]
			, dbo.fnBackupLocation('TLog', 1)  [TLog, AG path]
*/
create function [dbo].[fnBackupLocation]
(
	@backupType varchar(5) = 'Full'
	, @forAG tinyint = 0
)
returns varchar(1024)
as 
begin
	return 
	(
		select											-- Path creation:  
			ltrim(rtrim([Path]))						-- \\Base
			+ case right(ltrim(rtrim([Path])), 1)		
				when '\' then ''
				else '\'
			  end  collate database_default				--   + \
			+ case @forAG								
				when 1 
				then coalesce 							--     + cluster name
				((							
					select cluster_name
					from [master].[sys].[dm_hadr_cluster]
				), @@servername)						--     | failsafe
				else @@servername						--     | @@servername
			  end  collate database_default
			+ case @backupType							--       + \type\
				when 'Diff' then '\Diff\'
				when 'TLog' then '\TLog\'
				else '\Full\'
			  end collate database_default
		from
			[dbo].[BackupPathConfiguration]
		where 
			[Active] = 1
	)
end