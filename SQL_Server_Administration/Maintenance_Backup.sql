-- Full database backup and transaction log backup (only if the database is in FULL recovery mode).
-- Statistics update to improve query performance and index maintenance, rebuild and reorganize :
---- If fragmentation is > 30%, the index is rebuilt.
---- If fragmentation is between 10% and 30%, the index is reorganized.


USE master;
GO

--bak paths
DECLARE @DatabaseName NVARCHAR(100) = 'DBName' 
DECLARE @BackupPath NVARCHAR(200) = 'C:\SQL_Backups\' 
--Other variables
DECLARE @Date NVARCHAR(20) = FORMAT(GETDATE(), 'yyyyMMdd_HHmmss')
DECLARE @FullBackupFile NVARCHAR(300) = @BackupPath + @DatabaseName + '_FullBackup_' + @Date + '.bak'
DECLARE @LogBackupFile NVARCHAR(300) = @BackupPath + @DatabaseName + '_LogBackup_' + @Date + '.trn'

--Full database backup
BACKUP DATABASE @DatabaseName 
TO DISK = @FullBackupFile
WITH FORMAT, INIT, SKIP, CHECKSUM, COMPRESSION, STATS = 10;

--Transaction log backup (only if the database is in FULL recovery mode)
IF (SELECT recovery_model_desc FROM sys.databases WHERE name = @DatabaseName) = 'FULL'
BEGIN
    BACKUP LOG @DatabaseName 
    TO DISK = @LogBackupFile
    WITH INIT, CHECKSUM, COMPRESSION, STATS = 5;
END

DECLARE @TableName NVARCHAR(400), @SQL NVARCHAR(MAX)

DECLARE IndexCursor CURSOR FOR 
SELECT QUOTENAME(s.name) + '.' + QUOTENAME(o.name)
FROM sys.indexes i
JOIN sys.objects o ON i.object_id = o.object_id
JOIN sys.schemas s ON o.schema_id = s.schema_id
-- Clustered or non-clustered index
WHERE o.type = 'U' AND i.type IN (1, 2) 

OPEN IndexCursor
FETCH NEXT FROM IndexCursor INTO @TableName

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @SQL = '
    IF EXISTS (SELECT 1 FROM sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID(''' + @TableName + '''), NULL, NULL, ''LIMITED'') WHERE avg_fragmentation_in_percent > 30)
    BEGIN
        ALTER INDEX ALL ON ' + @TableName + ' REBUILD WITH (ONLINE = ON)
    END
    ELSE IF EXISTS (SELECT 1 FROM sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID(''' + @TableName + '''), NULL, NULL, ''LIMITED'') WHERE avg_fragmentation_in_percent BETWEEN 10 AND 30)
    BEGIN
        ALTER INDEX ALL ON ' + @TableName + ' REORGANIZE
    END'
    
    EXEC sp_executesql @SQL
    FETCH NEXT FROM IndexCursor INTO @TableName
END

CLOSE IndexCursor
DEALLOCATE IndexCursor

--Update statistics
EXEC sp_MSforeachtable 'UPDATE STATISTICS ? WITH FULLSCAN';

