-- =============================================
--Description: This script is used to delete files older than 60 days from a specific folder or move them to an archive folder.
--Please note that the script uses the xp_cmdshell extended stored procedure to execute the robocopy command to move the files to the archive folder.
--If you are using SQL Server 2017 or later, you can use the 'DEL' command instead of 'robocopy' to delete the files.
-- =============================================

--File paths	
DECLARE @FilePath nvarchar(1000) = ''; 
DECLARE @ArchivePath nvarchar(1000) ='';
--Other script variables
DECLARE @cmd VARCHAR(4000);
DECLARE @DataFileName VARCHAR(500);
DECLARE @DataFileDate datetime;
Declare @fileName nvarchar(max);
Declare @justPathForFile nvarchar(1000);
Declare @middleFilePath nvarchar(1000);
DECLARE @FilePathNew nvarchar(max);


----------select only file on -61 days---------------------------------------------------------------------

set  @FilePathNew = @FilePath + cast(year(GETDATE()-61) as nvarchar) + '\'+
right('0'+cast(month(GETDATE()-61) as nvarchar),2) + '\'+
right('0'+cast(day(GETDATE()-61) as nvarchar),2) + '\'

------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#TempDataFiles') IS NOT NULL
DROP TABLE #TempDataFiles

 --Create temp tables
CREATE TABLE #TempDataFiles(DataFileName VARCHAR(500),
								DataFileDate nvarchar(max));

--Get files
SET @cmd = 'dir /b /a-d /s ' + '"' + @FilePathNew + '"'
	INSERT INTO #TempDataFiles(DataFileName)
	EXEC xp_cmdshell @cmd

-----------------------Delete if older than or equal to 60 days  -------------------------------------------------------

DECLARE RawDataFileCursor CURSOR FOR 
SELECT DataFileName, DataFileDate 
FROM #TempDataFiles  
where DataFileName like '%evs%' 
and DataFileName IS NOT NULL 
and DATEDIFF(day,(TRY_CAST(DataFileDate as datetime)), GETDATE())  >= 61

---------------------------------------CURSOR ---------------------------------------------

OPEN RawDataFileCursor  
FETCH NEXT FROM RawDataFileCursor INTO @DataFileName, @DataFileDate
WHILE @@FETCH_STATUS = 0  
BEGIN
		---- FileName, e.g., 2022-06-09_10-40.file.evs
		SET @fileName = RIGHT(@DataFileName, CHARINDEX('\', REVERSE(@DataFileName)) -1);
		---- Path, e.g., C:\Data\2022\06\09\
		SET @justPathForFile = LEFT(@DataFileName,LEN(@DataFileName) - charindex('\',reverse(@DataFileName),1) + 1);
		---- Middle path, e.g., 2022\06\09\
		SET @middleFilePath = REPLACE(@justPathForFile, @FilePath, '')

------------------------------robocopy or del file ------------------------------------------------

SET @cmd = 'robocopy "' + @justPathForFile +  '." "' + @ArchivePath  + @middleFilePath +'." "' + @fileName + '" /mov /NFL /NDL /NJH /NJS /nc /ns /np' 

-- or delete file
--SET @cmd = 'del "' + @DataFileName + '"'

EXEC sys.xp_cmdshell @cmd


	FETCH NEXT FROM RawDataFileCursor INTO @DataFileName, @DataFileDate  
END
CLOSE RawDataFileCursor  
DEALLOCATE RawDataFileCursor 

---------------------------------------Final clean up ---------------------------------------------
DROP TABLE #TempDataFiles

