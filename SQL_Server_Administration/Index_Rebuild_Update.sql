-- Description: rebuild index and update statistics for DataFile table and disable DataFile_Ingestion job 
-- WARNING:	This procedure temporarily disables other DataFile related jobs. If this procedure is stopped before it completed, the other jobs
--			will need to be manually restarted. See script below for which jobs are stopped.

--Disable other DataFile processing jobs
EXEC msdb.dbo.sp_update_job @job_name='DataFile_Ingestion', @enabled = 0

BEGIN TRY
	DECLARE @startTime DATETIME = GETDATE();

	ALTER INDEX [PK_DataFile] ON [dbo].[DataFile] REBUILD PARTITION = ALL WITH (PAD_INDEX = ON, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80)

	UPDATE STATISTICS DataFile WITH FULLSCAN

--Log information
	INSERT INTO dbo.DataFile_Log (UserName, ProcedureName, Message, StartDateTime, EndDateTime)
	VALUES(SUSER_SNAME(), OBJECT_NAME(@@PROCID), 'Success' , @startTime, GETDATE())
END TRY
BEGIN CATCH
	PRINT N'An error occurred: '+ ERROR_MESSAGE();
	INSERT INTO dbo.DataFile_Log (UserName, ProcedureName, ErrorNumber, ErrorState, ErrorSeverity, ErrorLine, ErrorProcedure, Message, StartDateTime, EndDateTime)
		VALUES(
			SUSER_SNAME(),
			OBJECT_NAME(@@PROCID),
			ERROR_NUMBER(),
			ERROR_STATE(),
			ERROR_SEVERITY(),
			ERROR_LINE(),
			ERROR_PROCEDURE(),
			ERROR_MESSAGE(),
			@startTime,
			GETDATE()
		);
END CATCH

--Enable DataFile processing jobs
EXEC msdb.dbo.sp_update_job @job_name='DataFile_Ingestion', @enabled = 1
