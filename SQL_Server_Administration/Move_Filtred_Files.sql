-- =============================================
-- Description: The script uses a cursor to loop through the files in the specified folder and move them to the archive folder.
--Please note that the script uses the xp_cmdshell extended stored procedure to execute the robocopy command to move the files to the archive folder.
-- =============================================

--Files Paths
DECLARE @FilePath nvarchar(max) = 'D:\Files\Element\';
DECLARE @ArchiveFilePath nvarchar(max) =  'D:\Files\Archive\';
--Other Variables
DECLARE @cmd varchar(4000);
DECLARE @FileNameCursor varchar(500); 
Declare @FileNamePath nvarchar(max);
Declare @FileName nvarchar(max);
Declare @justPathForFile nvarchar(max);
Declare @middleFilePath nvarchar(max);

DECLARE fileCursor CURSOR FOR 
SELECT FileName   
FROM [Element].[dbo].[File] where 
date detween '2023-07-26' and '2023-08-26' 

OPEN fileCursor  
FETCH NEXT FROM fileCursor INTO @FileNameCursor 
WHILE @@FETCH_STATUS = 0  
BEGIN

  ---- select File Name and Path ----------

  SET @FileNamePath = replace(@FilePath + @FileNameCursor, '/','\') 
	---- FileName, e.g., 2022-06-09_10-40.file.evs
	SET @FileName = RIGHT(@FileNamePath, CHARINDEX('\', REVERSE(@FileNamePath)) -1);
	---- FilePath, e.g., C:\SQL\Ingestion\2022\06\09\
	SET @justPathForFile = LEFT(@FileNamePath,LEN(@FileNamePath) - charindex('\',reverse(@FileNamePath),1) + 1);
	---- MiddleFilePath, e.g., 2022\06\09\
	SET @middleFilePath = REPLACE(@justPathForFile, @filePath, '')

  -------------move file -------------------
  
	SET @cmd = 'robocopy "' + @justPathForFile +  '." "' + @archiveFilePath  + @middleFilePath +'." "' + @FileName + '"  /NFL /NDL /NJH /NJS /nc /ns /np' 
	EXEC  sys.xp_cmdshell @cmd

	FETCH NEXT FROM fileCursor INTO @FileNameCursor

END
CLOSE fileCursor  
DEALLOCATE fileCursor 