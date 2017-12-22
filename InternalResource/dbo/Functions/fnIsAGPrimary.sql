/*
**	Returns 1 if the instance is currently an AG primary.
**	Returns 0 if it is not part of an AG, or it is not the primary.
**
**	Requires SS2012+ (for the AG object references).
**	
**	Example:
		select dbo.fnIsAgPrimary()	as [IsAgPrimary]
**
*/
create function [dbo].[fnIsAGPrimary]()
returns bit
as
begin
	return
	(
		select isnull
		((
			select top(1) 1
			from [master].[sys].[dm_hadr_availability_replica_states]
			where [is_local] = 1 and [role] = 1
		), 0)
	)
end