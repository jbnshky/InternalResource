/*
**	Purges the [health].[fileSpaceUsage] table of all rows where 
**	captureDate is older than @retainDays.
**
**	Parameters:
**		@rowsPerIteration int; default: 10000
**			Specifies the number of rows per batch to remove. 
**
**		@retainDays smallint; default:  60
**			Specifies the number of days to retain logged data.
**
**	Example:
		-- Remove rows older than 60 days 10000 rows at a time. 
		exec health.purgeFileSpaceUsage	@retainDays = 60, @rowsPerIteration = 10000
**
*/
create procedure health.purgeFileSpaceUsage
	@retainDays smallint = 60
	, @rowsPerIteration int = 10000
as
begin
	set nocount on;

	declare 
		@delcount int
		, @deltotal int;

	while @delcount is null or @delcount > 0
	begin
		begin transaction;

		delete top(@rowsPerIteration)
		from 
			[InternalResource].[health].[fileSpaceUsage]
		where 
			datediff(dd, captureDate, getdate()) > isnull(@retainDays, 60);

		set @delcount = @@rowcount;
		set @deltotal += @delcount;

		commit transaction;
	end

	select @deltotal as totalRowsRemoved;
end