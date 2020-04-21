DECLARE CR CURSOR FOR
SELECT T.name TABLE_NAME,
       C.name COLUMN_NAME,
       CASE
           WHEN TY.name LIKE '%CHAR%' THEN
               TY.name + '(' + CONVERT(VARCHAR(10), C.max_length) + ')'
           ELSE
               TY.name
       END TYPE_NAME
FROM sys.tables T
    INNER JOIN sys.columns C
        ON C.object_id = T.object_id
    INNER JOIN sys.types TY
        ON TY.system_type_id = C.system_type_id
    LEFT JOIN sys.tables T2
        ON T2.name = 'AuditLog_' + T.name
WHERE T.name NOT LIKE 'AuditLog_%'
      AND T2.object_id IS NULL;

OPEN CR;

DECLARE @TABLE_NAME VARCHAR(MAX),
        @LAST_TABLE_NAME VARCHAR(MAX) = '',
        @COLUMN_NAME VARCHAR(MAX),
        @TYPE_NAME VARCHAR(MAX),
        @LINE VARCHAR(MAX),
        @TRIGGER VARCHAR(MAX),
        @SQL NVARCHAR(MAX) = N'',
        @EXECSQL NVARCHAR(MAX) = N'';


FETCH NEXT FROM CR
INTO @TABLE_NAME,
     @COLUMN_NAME,
     @TYPE_NAME;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF @TABLE_NAME != @LAST_TABLE_NAME
    BEGIN
        SET @LAST_TABLE_NAME = @TABLE_NAME;
        SET @EXECSQL += CHAR(13) + N'CREATE TABLE [AuditLog_' + @TABLE_NAME + N']';
        SET @EXECSQL += CHAR(13) + N'(';
        SET @EXECSQL += CHAR(13) + N'	AuditLogDate DATETIME DEFAULT GETDATE(),';
        SET @EXECSQL += CHAR(13) + N'	AuditLogType VARCHAR(5),';

        SET @TRIGGER
            = 'CREATE TRIGGER [' + @TABLE_NAME + '_AuditLogTrigger] ' + CHAR(13) + 'ON [' + @TABLE_NAME + '] '
              + CHAR(13) + 'AFTER INSERT , UPDATE , DELETE';
        SET @TRIGGER += CHAR(13) + 'AS';
        SET @TRIGGER += CHAR(13) + 'BEGIN';
        SET @TRIGGER += CHAR(13) + '	INSERT INTO [AuditLog_' + @TABLE_NAME + ']';
        SET @TRIGGER += CHAR(13) + '	SELECT GETDATE(), ''I'' ,I.* FROM INSERTED I';
        SET @TRIGGER += CHAR(13) + '	INSERT INTO [AuditLog_' + @TABLE_NAME + ']';
        SET @TRIGGER += CHAR(13) + '	SELECT GETDATE(), ''D'' ,D.* FROM DELETED D';
        SET @TRIGGER += CHAR(13) + 'END';
    END;
    SET @LINE = '	' + @COLUMN_NAME + ' ' + @TYPE_NAME;

    FETCH NEXT FROM CR
    INTO @TABLE_NAME,
         @COLUMN_NAME,
         @TYPE_NAME;

    SET @EXECSQL += CHAR(13) + @LINE + CASE
                                           WHEN @TABLE_NAME ! = @LAST_TABLE_NAME THEN
                                               ''
                                           ELSE
                                               ' ,'
                                       END;

    IF @TABLE_NAME != @LAST_TABLE_NAME
       OR @TABLE_NAME IS NULL
    BEGIN
        SET @EXECSQL += CHAR(13) + N')';
        SET @EXECSQL += CHAR(13) + N'';
        EXEC sp_executesql @EXECSQL;
        SET @SQL += @EXECSQL;
        SET @EXECSQL = N'';
        SET @SQL += CHAR(13) + N'GO';
        SET @SQL += CHAR(13) + N'';
        SET @EXECSQL += CHAR(13) + @TRIGGER;
        EXEC sp_executesql @EXECSQL;
        SET @SQL += @EXECSQL;
        SET @EXECSQL = N'';
        SET @SQL += CHAR(13) + N'';
        SET @SQL += CHAR(13) + N'GO';
        SET @SQL += CHAR(13) + N'';
    END;
END;

SET @EXECSQL += CHAR(13) + N')';
SET @EXECSQL += CHAR(13) + N'';
EXEC sp_executesql @EXECSQL;
SET @SQL += @EXECSQL;
SET @EXECSQL = N'';
SET @EXECSQL += CHAR(13) + @TRIGGER;
EXEC sp_executesql @EXECSQL;
SET @SQL += @EXECSQL;
SET @SQL += CHAR(13) + N'';
SET @SQL += CHAR(13) + N'GO';
SET @SQL += CHAR(13) + N'';

PRINT @SQL;

CLOSE CR;
DEALLOCATE CR;