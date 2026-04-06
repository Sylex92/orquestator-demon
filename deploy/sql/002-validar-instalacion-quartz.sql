/*
  Validacion post-instalacion para Infra/DBA.
  Ejecutar directamente en SSMS. NO requiere SQLCMD Mode.

  Ejecutar despues de:
  - crear base/esquemas/permisos;
  - instalar tablas QRTZ_* con el script oficial de Quartz;
  - crear opcionalmente [poc].[JobExecutionLog].
*/

SET NOCOUNT ON;

DECLARE @DatabaseName sysname = N'DaemonQuartz';
DECLARE @QuartzSchema sysname = N'quartz';
DECLARE @PocSchema sysname = N'poc';
DECLARE @RuntimeLogin sysname = N'svc_daemon_quartz_runtime';
DECLARE @ValidatePocTable bit = 1;

IF DB_ID(@DatabaseName) IS NULL
BEGIN
    RAISERROR(N'La base %s no existe.', 16, 1, @DatabaseName);
    RETURN;
END;

DECLARE @sql nvarchar(max) = N'
USE ' + QUOTENAME(@DatabaseName) + N';

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = @QuartzSchema)
BEGIN
    RAISERROR(N''No existe el schema %s.'', 16, 1, @QuartzSchema);
END;

DECLARE @RequiredQuartzTables TABLE
(
    TableName sysname NOT NULL PRIMARY KEY
);

INSERT INTO @RequiredQuartzTables (TableName)
VALUES
    (N''QRTZ_BLOB_TRIGGERS''),
    (N''QRTZ_CALENDARS''),
    (N''QRTZ_CRON_TRIGGERS''),
    (N''QRTZ_FIRED_TRIGGERS''),
    (N''QRTZ_JOB_DETAILS''),
    (N''QRTZ_LOCKS''),
    (N''QRTZ_PAUSED_TRIGGER_GRPS''),
    (N''QRTZ_SCHEDULER_STATE''),
    (N''QRTZ_SIMPLE_TRIGGERS''),
    (N''QRTZ_SIMPROP_TRIGGERS''),
    (N''QRTZ_TRIGGERS'');

;WITH MissingTables AS
(
    SELECT required.TableName
    FROM @RequiredQuartzTables required
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM sys.tables t
        INNER JOIN sys.schemas s
            ON s.schema_id = t.schema_id
        WHERE s.name = @QuartzSchema
          AND t.name = required.TableName
    )
)
SELECT TableName
FROM MissingTables;

IF EXISTS
(
    SELECT 1
    FROM @RequiredQuartzTables required
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM sys.tables t
        INNER JOIN sys.schemas s
            ON s.schema_id = t.schema_id
        WHERE s.name = @QuartzSchema
          AND t.name = required.TableName
    )
)
BEGIN
    RAISERROR(N''Faltan tablas QRTZ_* en el schema %s. Revisar salida anterior.'', 16, 1, @QuartzSchema);
END;

IF USER_ID(@RuntimeLogin) IS NULL
BEGIN
    RAISERROR(N''No existe el usuario de base para %s.'', 16, 1, @RuntimeLogin);
END;

DECLARE @CanSelect int;
DECLARE @CanInsert int;
DECLARE @CanUpdate int;
DECLARE @CanDelete int;

CREATE TABLE #Perms
(
    CanSelect int NOT NULL,
    CanInsert int NOT NULL,
    CanUpdate int NOT NULL,
    CanDelete int NOT NULL
);

DECLARE @PermSql nvarchar(max) =
    N''EXECUTE AS USER = '' + QUOTENAME(@RuntimeLogin, '''''''') + N'';
      SELECT
          HAS_PERMS_BY_NAME(QUOTENAME(@QuartzSchema), ''''SCHEMA'''', ''''SELECT'''') AS CanSelect,
          HAS_PERMS_BY_NAME(QUOTENAME(@QuartzSchema), ''''SCHEMA'''', ''''INSERT'''') AS CanInsert,
          HAS_PERMS_BY_NAME(QUOTENAME(@QuartzSchema), ''''SCHEMA'''', ''''UPDATE'''') AS CanUpdate,
          HAS_PERMS_BY_NAME(QUOTENAME(@QuartzSchema), ''''SCHEMA'''', ''''DELETE'''') AS CanDelete;
      REVERT;'';

INSERT INTO #Perms (CanSelect, CanInsert, CanUpdate, CanDelete)
EXEC sp_executesql @PermSql, N''@QuartzSchema sysname'', @QuartzSchema = @QuartzSchema;

SELECT
    @CanSelect = CanSelect,
    @CanInsert = CanInsert,
    @CanUpdate = CanUpdate,
    @CanDelete = CanDelete
FROM #Perms;

DROP TABLE #Perms;

IF (@CanSelect <> 1 OR @CanInsert <> 1 OR @CanUpdate <> 1 OR @CanDelete <> 1)
BEGIN
    RAISERROR(N''El usuario %s no tiene permisos minimos completos sobre el schema %s.'', 16, 1, @RuntimeLogin, @QuartzSchema);
END;

IF @ValidatePocTable = 1
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = @PocSchema)
    BEGIN
        RAISERROR(N''Se solicito validar PoC pero no existe el schema %s.'', 16, 1, @PocSchema);
    END;

    IF OBJECT_ID(QUOTENAME(@PocSchema) + N''.[JobExecutionLog]'', ''U'') IS NULL
    BEGIN
        RAISERROR(N''No existe la tabla [%s].[JobExecutionLog].'', 16, 1, @PocSchema);
    END;
END;

SELECT
    @@SERVERNAME AS SqlServerName,
    DB_NAME() AS DatabaseName,
    GETUTCDATE() AS ValidationUtc;

SELECT
    s.name AS SchemaName,
    t.name AS TableName
FROM sys.tables t
INNER JOIN sys.schemas s
    ON s.schema_id = t.schema_id
WHERE s.name = @QuartzSchema
  AND t.name LIKE N''QRTZ[_]%''
ORDER BY t.name;
';

EXEC sp_executesql
    @sql,
    N'@QuartzSchema sysname, @PocSchema sysname, @RuntimeLogin sysname, @ValidatePocTable bit',
    @QuartzSchema = @QuartzSchema,
    @PocSchema = @PocSchema,
    @RuntimeLogin = @RuntimeLogin,
    @ValidatePocTable = @ValidatePocTable;

PRINT N'Validacion completada correctamente.';
