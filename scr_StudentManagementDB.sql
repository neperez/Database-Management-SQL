/*
Nicolas Perez
Scr_StudentManagementDB

This script creates a student management database
that contains one create table statement and four create stored procedure
statements.

The Students table holds information about the student needed 
for various actions.

sp_AddStudent adds a student to the management database then creates a login with
Windows authentication.

sp_CreateStudentDB creates a database with the same name as the student login
passed INTo it.  The student is then made a user and owner of that database.

sp_BackupAndDeleteStudentDB loops through the Student databases, backs them up to the
studentManagementDB folder, drops the database from the server, and finally drops the login
associated with that database.  

sp_StudentDBSummary returns information about a student's 
table layout in their database.  It can be searched for by 
first name, last name, or login/database name.  

*/

USE [master]

GO

CREATE DATABASE [StudentManagementDB]
	ON (
	NAME = 'StudentManagementDB',
	FILENAME = 'C:\SQL282\StudentManagementDB\StudentManagement_DAT.mdf',
	MAXSIZE = 1GB,
	FILEGROWTH = 1MB ) 
	LOG ON (
	NAME = 'StudentManagementDBLog',
	FILENAME = 'C:\SQL282\StudentManagementDB\StudentManagement_LOG.ldf',
	MAXSIZE = 512MB,
	FILEGROWTH = 1MB ) ;
GO

USE [StudentManagementDB] ;

GO

ALTER DATABASE [StudentManagementDB]
	SET RESTRICTED_USER ;

CREATE TABLE Students (
	StuID INT IDENTITY(1,1) NOT NULL,
	FName VARCHAR (20) NULL,
	LName VARCHAR(40) NOT NULL,
	stuLogin VARCHAR(10) NOT NULL,
	BackupPath VARCHAR(259) NULL
) ;

GO

/*

sp_AddStudent adds a student to the management database.

@params:

	@First = First name of student.
	@Last = Last name of student
	@Login = student's assigned login

*/

CREATE PROC sp_AddStudent

	@First VARCHAR (20),
	@Last VARCHAR (40),
	@Login VARCHAR (10)
	
AS

BEGIN

	DECLARE @PathPrefix VARCHAR(14) = 'C:\SQL282\'
	
	DECLARE @BackupPath VARCHAR(259) = @PathPrefix + @Login ;
	
		
	-- Insert student info INTo Students table:
	INSERT INTO dbo.Students (FName,LName,stuLogin,BackupPath)
	VALUES (@First,@Last,@Login,@BackupPath)
		
	-- Create login for student:
	DECLARE @Domain VARCHAR (30) = 'ICS\' ;
	
	DECLARE @str VARCHAR (100) = 
	'CREATE LOGIN [' + @Domain + @Login + '] FROM WINDOWS ;' ;
	
	EXEC (@str) ;
	



END;

GO

/*

sp_CreateStudentDB creates a student database and makes student a user.

*/

CREATE PROC sp_CreateStudentDB

	@Login VARCHAR(10)
	
AS

BEGIN
	
	--- NAME parameter for data file.
	DECLARE @DatFile VARCHAR (15) = @Login + '_dat' ;
	
	-- NAME parameter for log file.
	DECLARE @LogFile VARCHAR (15) = @Login + '_log';
	
	DECLARE @FileName VARCHAR (100) = (
		SELECT BackupPath
			FROM Students
				WHERE stuLogin = @Login ) + '\' + @Login ;
	
	--FILENAME	parameter for data file:		
	DECLARE @datFileName VARCHAR (100) = @FileName + 'DAT.mdf' ;
	
	--FILENAME parameter for log:
	DECLARE @logFileName VARCHAR (100) = @FileName + 'LOG.ldf' ;
	
	-- go to master and create new database for student:
	DECLARE @str VARCHAR (1000) = 
	'USE master; 
	
	CREATE DATABASE ' + @Login +
	' ON 
	( NAME = ''' + @DatFile + ''',
		FILENAME = ''' + @datFileName + ''',
		MAXSIZE = 1GB,
		FILEGROWTH = 1MB )
	LOG ON
	( NAME = ''' + @LogFile + ''',
		FILENAME = ''' + @logFileName + ''',
		MAXSIZE = 1GB,
		FILEGROWTH = 1MB ) ; '
	
	EXEC (@str) ;
	DECLARE @DomainLogin VARCHAR (100) = '[ICS\' + @Login + ']' ;
	
	SET @str = 
	'USE ' + @Login + ' ; ALTER AUTHORIZATION
		ON DATABASE::' + @Login + ' TO '
		+ @DomainLogin ;  
	
	EXEC (@str) ;
	
	
END

GO

/*

sp_BackupAndDeleteStudentDB

Backs up all user databases and saves them to the student management folder.  
Each backup is verified before the databases are dropped.  

*/
CREATE PROC sp_BackupAndDeleteStudentDB

AS

BEGIN

DECLARE @DBName VARCHAR(50) 
DECLARE @Path VARCHAR(256)  
DECLARE @FileName VARCHAR(256) 
DECLARE @FileDate VARCHAR(20) 

SET @Path = 'C:\SQL282\StudentManagementDB\' ; 

SELECT @FileDate = convert( VARCHAR (20), getdate(), 112 )

DECLARE db_cursor CURSOR FOR 
	( SELECT name 
		FROM master.dbo.sysdatabases 
			WHERE name NOT IN ( 'master', 'model', 'msdb', 
				'tempdb', 'StudentManagementDB' ) ) ;

OPEN db_cursor ;
FETCH NEXT FROM db_cursor INTO @DBName ;

WHILE @@FETCH_STATUS = 0  

BEGIN  
       

	-- set current file name
	SET @FileName = @Path + @DBName + '_' + @FileDate ;
	
	DECLARE @DatFileName VARCHAR (100) = @FileName + '_Dat.bak' ;
	
	DECLARE @LogFileName VARCHAR(100) = @FileName + '_Log.bak' ;	
	
	-- backup database
	BACKUP DATABASE @DBName 
		TO DISK = @DatFileName
	
	-- backup log
	BACKUP LOG @DBName
		TO DISK = @LogFileName ;
	
	-- delete student db.
	DECLARE @str VARCHAR (40) = 
		'USE master ;
		DROP DATABASE ' + @DBName + ' ;' ;

	EXEC(@str) ;
	
	SET @str = 'USE master ; DROP LOGIN ' + '[ICS\' + @DBName + '] ;' ;
	
	EXEC (@str) ;
	
	FETCH NEXT FROM db_cursor INTO @DBName 

END

CLOSE db_cursor  

DEALLOCATE db_cursor

END 

GO

/*
sp_StudentDBSummary

Creates and queries a table #TableSummary, that lists
the columns for each user table in their database,
plus the number of rows in each table.

Author: Bryan Syverson 2006-07-12 (Murach SQL Server 2005
	for developers)

Modified: Nick Perez 2010-05-30
-changed format from script to parametized stored procedure that accepts optional values.

*/
CREATE PROC sp_StudentDBSummary

@FName VARCHAR (20) = NULL,
@LName VARCHAR (40) = NULL,
@stuLogin VARCHAR (20) = NULL

AS

BEGIN

	DECLARE @DB VARCHAR (10) ;

	IF @FName IS NOT NULL
		BEGIN
			SET @DB = (
				SELECT StuLogin
					FROM Students
						WHERE FName = @FName) ;
		END
		
	ELSE IF @LName IS NOT NULL
		BEGIN
			SET @DB = (
				SELECT StuLogin
					FROM Students
						WHERE LName = @LName);
		END
		
	ELSE IF @stuLogin IS NOT NULL
		BEGIN
			SET @DB = @stuLogin;
		END
	
	ELSE 
		BEGIN
			PRINT 'No parameters entered, Enter first name or 
			last name or login name';
			RETURN
		END
		
	DECLARE @str VARCHAR(1650) = 
	'USE ' + @DB + 
	' 
	IF OBJECT_ID(''tempdb..#TableSummary'') IS NOT NULL
		DROP TABLE #TableSummary
		
	SELECT sys.tables.name AS TableName, sys.columns.name AS ColumnName,
		sys.types.name AS Type
	INTO #TableSummary
	FROM sys.tables
		JOIN sys.columns ON sys.tables.object_id = sys.columns.object_id
		JOIN sys.types ON sys.columns.system_type_id = sys.types.system_type_id
	WHERE sys.tables.name IN
		(SELECT name
		FROM sys.tables
		WHERE name NOT IN (''dtproperties'', ''TableSummary'', ''AllUserTables''))
			
	IF OBJECT_ID(''tempdb..#AllUserTables'') IS NOT NULL
		DROP TABLE #AllUserTables

	CREATE TABLE #AllUserTables (
		TableID INT IDENTITY, 
		TableName VARCHAR (128)
	)
	INSERT #AllUserTables (TableName)
	SELECT name
	FROM sys.tables
	WHERE name NOT IN (''dtproperties'',''TableSummary'', ''AllUserTables'')

	DECLARE @LoopMax INT, @LoopVar INT
	DECLARE @TableNameVar VARCHAR (128), @ExecVar VARCHAR(1000)

	SELECT @LoopMax = MAX(TableID) FROM #AllUserTables

	SET @LoopVar = 1

	WHILE @LoopVar <= @LoopMax
		BEGIN
			SELECT @TableNameVar = TableName
				FROM #AllUserTables
				WHERE TableID = @LoopVar
			SET @ExecVar = ''DECLARE @CountVar INT ''
			SET @ExecVar = @ExecVar + ''SELECT @CountVar = COUNT(*) ''
			SET @ExecVar = @ExecVar + '' FROM '' + @TableNameVar + '' ''
			SET @ExecVar = @ExecVar + ''INSERT #TableSummary ''
			SET @ExecVar = @ExecVar + ''VALUES ('''''' + @TableNameVar + '''''',''
			SET @ExecVar = @ExecVar + ''''''*RowCount*'''',''
			SET @ExecVar = @ExecVar + '' @CountVar)''
			EXEC (@ExecVar)
			SET @LoopVar = @LoopVar + 1
		END
	
	SELECT * FROM #TableSummary
	ORDER BY TableName, ColumnName
	' ;

	EXEC (@str) ;

END

GO
