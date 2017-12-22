create procedure [dbo].[internalGenerateLoginScripts]
as
begin 
	select
		p.principal_id
		, @@servername as server_name 
		, 'create login [' + p.name + '] ' 
			+ case when p.type in ('U','G') then 'from windows ' else '' end
			+ 'with ' 
			+ case 
				when p.type = 'S' 
				then 
					'password = ' + master.sys.fn_varbintohexstr(l.password_hash) + ' hashed' 
					+ ', sid = ' + master.sys.fn_varbintohexstr(l.sid) 
					+ ', check_expiration = ' 
					+ case when l.is_expiration_checked > 0 then 'ON, ' else 'OFF, ' end  collate database_default
					+ 'check_policy = ' 
					+ case when l.is_policy_checked > 0 then 'ON, ' else 'OFF, ' end  collate database_default
					+ case when l.credential_id > 0 then 'credential = ' + c.name + ', ' else '' end  collate database_default
				else '' 
			  end  collate database_default
			+ 'default_database = ' + p.default_database_name  collate database_default
			+ case when len(p.default_language_name) > 0 then ', default_language = ' + p.default_language_name else '' end  collate database_default
	from 
		sys.server_principals p 
		left join sys.sql_logins l 
			on p.principal_id = l.principal_id 
		left join sys.credentials c 
			on  l.credential_id = c.credential_id
	where 
		p.type in ('S','U','G') and p.name <> 'sa' 
end