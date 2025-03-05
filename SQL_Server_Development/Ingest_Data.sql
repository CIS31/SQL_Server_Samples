--Description: This script is used to ingest data into SQL db from files in a directory and then move the files to an archive directory. 
--If an error occurs, the file is moved to an error directory. The script uses xp_cmdshell to read the files and robocopy to move the files. 
--The script also logs the start and end times of the script, the number of rows processed, and any errors that occur

--File paths
DECLARE @FilePathReceived VARCHAR(1000)='D:\Data\Files\Files_Received\'
DECLARE @ArchiveFilePath VARCHAR(1000)='D:\Data\Files\Files_Archive\'
DECLARE @ErrorFilePath VARCHAR(1000)='D:\Data\Files\File_Error\'

--Other script variables
DECLARE @FileFullPath varchar(500)
DECLARE @cmd VARCHAR(4000) 
DECLARE @startTime DateTime
DECLARE @overallStartTime DateTime
DECLARE @rows_processed_significant int;
DECLARE @fileName nvarchar(max);
DECLARE @justPathForFile nvarchar(max);
DECLARE @middleFilePath nvarchar(max);
DECLARE @xp_cmdshell_returnCode int;
DECLARE @xp_cmdshell_returnMessage nvarchar(max);

--Constants 
DECLARE @ProcedureName nvarchar(max) = OBJECT_NAME(@@PROCID);

IF OBJECT_ID('tempdb..#TempFiles') IS NOT NULL
	DROP TABLE #TempFiles

IF OBJECT_ID('tempdb..#TempFileData') IS NOT NULL
	DROP TABLE #TempFileData

IF OBJECT_ID('tempdb..#TempCmdMessages') IS NOT NULL
	DROP TABLE #TempCmdMessages

--Create temp tables
CREATE TABLE #TempFiles(DataFileName VARCHAR(500));
CREATE TABLE #TempFileData ([ObjectId] UNIQUEIDENTIFIER NOT NULL,
				[Name] nvarchar(max) NOT NULL,
				[Date] nvarchar(max) NOT NULL,
				[Value] float NULL,
				[significant]float NULL)
CREATE TABLE #TempCmdMessages(Msg NVARCHAR(max));

SET @overallStartTime = GETDATE();

--Get files
SET @cmd = 'dir /b /a-d /s ' + '"' + @FilePathReceived + '"'
INSERT INTO #TempFiles
EXEC xp_cmdshell @cmd

--read each file
DECLARE fileCursor CURSOR FOR 
SELECT DataFileName 
FROM #TempFiles 
WHERE (DataFileName IS NOT NULL) AND (DataFileName like '%.evs%')

OPEN fileCursor  
FETCH NEXT FROM fileCursor INTO @FileFullPath  
WHILE @@FETCH_STATUS = 0  
BEGIN
	BEGIN TRY
		---- FileName, e.g., 2022-06-09_10-40.file.evs
		SET @fileName = RIGHT(@FileFullPath, CHARINDEX('\', REVERSE(@FileFullPath)) -1);
		---- FilePath, e.g., C:\SQL\Ingestion\2022\06\09\
		SET @justPathForFile = LEFT(@FileFullPath,LEN(@FileFullPath) - charindex('\',reverse(@FileFullPath),1) + 1);
		---- MiddleFilePath, e.g., 2022\06\09\
		SET @middleFilePath = REPLACE(@justPathForFile, @FilePathReceived, '')

		--Clear #TempFileData
		DELETE FROM #TempFileData
		SET @rows_processed_significant = NULL;
		SET @xp_cmdshell_returnCode = NULL;

		SET @cmd = 
		'BULK INSERT #TempFileData 
		FROM ''' + @FileFullPath +
		''' WITH (FIELDTERMINATOR = ''\t'',ROWTERMINATOR = ''\r'')'

		SET @startTime=GETDATE()

		EXEC(@cmd)

		-- Format datetime data
		update #TempFileData
		set [Date] = CAST(LEFT(T.[Date], 10) + ' ' +  REPLACE(RIGHT(T.[Date], 8), '-', ':') as datetime)
		FROM #TempFileData T
	
		--Insert only non-duplicate data
		INSERT INTO [dbo].[Data_Obj] ([ObjectId], [Date], [Value])
		SELECT T.[ObjectId]
			, T.Date
			, T.[Value]
		FROM #TempFileData T 
			LEFT JOIN [dbo].[Data_Obj] F ON T.ObjectId = F.ObjectId AND T.Date = F.Date 
			join Value on  Value.ObjectId = T.[ObjectId]

		WHERE F.ObjectId IS NULL
		and AttributeId = '...' 


		SELECT @rows_processed_significant = @@ROWCOUNT;

		INSERT INTO dbo.FlowData_Log (UserName, ProcedureName, FilePath, Message, StartDateTime, EndDateTime, RowsProcessedSignificant, RowsProcessedNonSignificant)
		VALUES(SUSER_SNAME(), @ProcedureName, @FileFullPath, 'Success', @startTime, GETDATE(), @rows_processed_significant, @rows_processed_nonsignificant)

		
		/*
			Only move the file if the data was correctly processed

			NOTES:
				1. /mov moves the files. The other robocopy options (/NFL /NDL /NJH /NJS /nc /ns /np) just make it silent
				2. The "." is necessary to prevent a trailing "\" from escaping the double quote
		*/
		DELETE FROM #TempCmdMessages
		SET @cmd = 'robocopy "' + @justPathForFile +  '." "' + @ArchiveFilePath  + @middleFilePath +'." "' + @fileName + '" /mov /NFL /NDL /NJH /NJS /nc /ns /np' 
		INSERT INTO #TempCmdMessages
		EXEC @xp_cmdshell_returnCode = sys.xp_cmdshell @cmd
		SET @xp_cmdshell_returnMessage = (SELECT STRING_AGG(Msg, CHAR(13)) from #TempCmdMessages)

		/*Check for errors from xp_cmdshell. Values greater than 8 returned from robocopy indicate an error*/
		if (@xp_cmdshell_returnCode > 8)
			THROW 50000, @xp_cmdshell_returnMessage, 1

	END TRY
	BEGIN CATCH
		IF @@ERROR <> 0
			BEGIN
				PRINT N'An error occurred: '+ ERROR_MESSAGE();
				INSERT INTO dbo.FlowData_Log (UserName, ProcedureName, FilePath, ErrorNumber, ErrorState, ErrorSeverity, ErrorLine, ErrorProcedure, Message, StartDateTime, EndDateTime, RowsProcessedSignificant, RowsProcessedNonSignificant)
				VALUES(
					SUSER_SNAME(),
					@ProcedureName,
					@FileFullPath,
					ERROR_NUMBER(),
					ERROR_STATE(),
					ERROR_SEVERITY(),
					ERROR_LINE(),
					ERROR_PROCEDURE(),
					ERROR_MESSAGE(),
					@startTime,
					GETDATE(),
					@rows_processed_significant,
					@rows_processed_nonsignificant
				);

				/*
					Move the file to the error directory to prevent re-processing of the file that causes the error

					NOTES:
						1. /mov moves the files. The other robocopy options (/NFL /NDL /NJH /NJS /nc /ns /np) just make it silent
						2. The "." is necessary to prevent a trailing "\" from escaping the double quote
				*/
				DELETE FROM #TempCmdMessages
				SET @cmd = 'robocopy "' + @justPathForFile +  '." "' + @ErrorFilePath  + @middleFilePath +'." "' + @fileName + '" /mov /NFL /NDL /NJH /NJS /nc /ns /np' 
				INSERT INTO #TempCmdMessages
				EXEC @xp_cmdshell_returnCode = sys.xp_cmdshell @cmd
				SET @xp_cmdshell_returnMessage = (SELECT STRING_AGG(Msg, CHAR(13)) from #TempCmdMessages)
			END
		ELSE /*We are catching a non-TSQL error. I.e., an error we threw when checking xp_cmdshell results.*/
			BEGIN
				PRINT N'An error occurred: '+ ERROR_MESSAGE();
				INSERT INTO dbo.FlowData_Log (UserName, ProcedureName, FilePath, ErrorNumber, ErrorState, ErrorSeverity, ErrorLine, ErrorProcedure, xp_cmdshellCommand, Message, StartDateTime, EndDateTime, RowsProcessedSignificant, RowsProcessedNonSignificant)
				VALUES(
					SUSER_SNAME(),
					@ProcedureName,
					@FileFullPath,
					ERROR_NUMBER(),
					ERROR_STATE(),
					ERROR_SEVERITY(),
					ERROR_LINE(),
					ERROR_PROCEDURE(),
					@cmd,
					ERROR_MESSAGE(),
					@startTime,
					GETDATE(),
					@rows_processed_significant,
					@rows_processed_nonsignificant
				);
			END
	END CATCH
	FETCH NEXT FROM fileCursor INTO @FileFullPath 
END
CLOSE fileCursor  
DEALLOCATE fileCursor 

