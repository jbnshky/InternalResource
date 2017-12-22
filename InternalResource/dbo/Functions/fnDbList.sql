/*
**	
**	Returns a comma separated list of local databases as varchar(2048).
**	Requires SS2012+ (for the AG object references).  
**
**	Use the @forAG parameter to filter the list.  Tempdb is always excluded, 
**	but other system databases are not.
**	
**	Parameters:
**		@forAG tinyint; default null
**			Expected values:
**			null:	Returns all user and system databases.
**			0:		Returns only non-AG databases.
**			1:		Returns only AG databases.
**			
**	Example:
		select 
			dbo.fnDbList(null)	as [All DBs]
			, dbo.fnDbList(0)	as [Non-AG DBs]
			, dbo.fnDbList(1)	as [AG DBs]
*/
create function [dbo].[fnDbList](@forAG tinyint = null)
returns varchar(2048)
as
begin
	return 
	(
		select 
			stuff
			((	
					select ',' + d.[name] collate database_default
					from 
						[master].[sys].[databases] as d
						left join [master].[sys].[availability_databases_cluster] as agdb 
							on d.[name] = agdb.[database_name]
					where 
						lower(d.[name]) != 'tempdb'
						and 
						(
							-- AG dbs
							(agdb.[database_name] is not null and @forAG = 1)
							or 
							-- Non-AG dbs
							(agdb.[database_name] is null and @forAG = 0)
							or 
							-- Everything
							@forAG is null
						)
					for xml path('')
			), 1, 1, '')
	)
end