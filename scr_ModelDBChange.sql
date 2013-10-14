/*
Nicolas Perez
scr_ModelDBChange


This script backs up the default model database before adding a
stored procedure.

The stored procedure sp_backupdb provides a way for the Students to save their own databases
to their respective folders.  


*/

USE [model];
GO

-- back up model database file and log.

DECLARE @filePath VARCHAR(100) = 'C:\SQL282\StudentManagementDB\';

DECLARE @DBFILE VARCHAR(150)= @filePath + 'model.bak';

DECLARE @DBLOG VARCHAR(100) = @filePath + 'modelLOG.bak';

BACKUP DATABASE model
	TO DISK = @DBFILE; 


BACKUP LOG model
	TO DISK = @DBLOG;

GO

/*

sp_backupdb will backup a student's database file and log to
their respective backup location.  Will work for any database 
and folder with the same name like StudentManagementDB. 

*/

CREATE PROC sp_backupdb

AS

DECLARE @DBName	VARCHAR(128)   = (SELECT DB_NAME());

DECLARE @Path VARCHAR(500)   = 'C:\SQL282\' ;

DECLARE	@FileName VARCHAR(4000);

DECLARE @FileSuffix VARCHAR (1000) = 
	CONVERT(VARCHAR(8),GETDATE(),112) + '_'
	+ REPLACE(CONVERT(VARCHAR(8),GETDATE(),108),':','')
	+ '.bak' ;

SELECT @FileName = @Path + @DBName + '\' + @DBName + '_Full_' + @FileSuffix ;

BACKUP DATABASE @DBName
	TO DISK = @FileName

SELECT @FileName = @Path + @DBName + '\' + @DBName + '_Log_' + @FileSuffix ;

BACKUP LOG @DBName
	TO DISK = @FileName ;
	
GO
