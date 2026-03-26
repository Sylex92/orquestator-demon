/*
  Validacion post-instalacion para Infra/DBA.
  Ejecutar despues de:
  - crear base/esquemas/permisos;
  - instalar tablas QRTZ_* con el script oficial de Quartz;
  - crear opcionalmente [poc].[JobExecutionLog].

  Ejecutar en SSMS con SQLCMD Mode habilitado, o adaptar valores manualmente.
*/

:setvar DatabaseName "DaemonQuartz"
:setvar QuartzSchema "quartz"
:setvar PocSchema "poc"
:setvar RuntimeLogin "svc_daemon_quartz_runtime"
:setvar ValidatePocTable "1"

SET NOCOUNT ON;
GO

IF DB_ID(N'$(DatabaseName)') IS NULL
BEGIN
    RAISERROR('La base $(DatabaseName) no existe.', 16, 1);
END
GO

DECLARE @useDatabaseSql nvarchar(max) =
    N'USE ' + QUOTENAME(N'$(DatabaseName)') + N';';

EXEC (@useDatabaseSql);
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'$(QuartzSchema)')
BEGIN
    RAISERROR('No existe el schema $(QuartzSchema).', 16, 1);
END
GO

DECLARE @RequiredQuartzTables TABLE
(
    TableName sysname NOT NULL PRIMARY KEY
);

INSERT INTO @RequiredQuartzTables (TableName)
VALUES
    (N'QRTZ_BLOB_TRIGGERS'),
    (N'QRTZ_CALENDARS'),
    (N'QRTZ_CRON_TRIGGERS'),
    (N'QRTZ_FIRED_TRIGGERS'),
    (N'QRTZ_JOB_DETAILS'),
    (N'QRTZ_LOCKS'),
    (N'QRTZ_PAUSED_TRIGGER_GRPS'),
    (N'QRTZ_SCHEDULER_STATE'),
    (N'QRTZ_SIMPLE_TRIGGERS'),
    (N'QRTZ_SIMPROP_TRIGGERS'),
    (N'QRTZ_TRIGGERS');

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
        WHERE s.name = N'$(QuartzSchema)'
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
        WHERE s.name = N'$(QuartzSchema)'
          AND t.name = required.TableName
    )
)
BEGIN
    RAISERROR('Faltan tablas QRTZ_* en el schema $(QuartzSchema). Revisar salida anterior.', 16, 1);
END
GO

IF USER_ID(N'$(RuntimeLogin)') IS NULL
BEGIN
    RAISERROR('No existe el usuario de base para $(RuntimeLogin).', 16, 1);
END
GO

EXECUTE AS USER = '$(RuntimeLogin)';

DECLARE @CanSelect int = HAS_PERMS_BY_NAME(N'[$(QuartzSchema)]', 'SCHEMA', 'SELECT');
DECLARE @CanInsert int = HAS_PERMS_BY_NAME(N'[$(QuartzSchema)]', 'SCHEMA', 'INSERT');
DECLARE @CanUpdate int = HAS_PERMS_BY_NAME(N'[$(QuartzSchema)]', 'SCHEMA', 'UPDATE');
DECLARE @CanDelete int = HAS_PERMS_BY_NAME(N'[$(QuartzSchema)]', 'SCHEMA', 'DELETE');

REVERT;

IF (@CanSelect <> 1 OR @CanInsert <> 1 OR @CanUpdate <> 1 OR @CanDelete <> 1)
BEGIN
    RAISERROR('El usuario $(RuntimeLogin) no tiene permisos minimos completos sobre el schema $(QuartzSchema).', 16, 1);
END
GO

IF '$(ValidatePocTable)' = '1'
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'$(PocSchema)')
    BEGIN
        RAISERROR('Se solicito validar PoC pero no existe el schema $(PocSchema).', 16, 1);
    END

    IF OBJECT_ID(QUOTENAME(N'$(PocSchema)') + N'.[JobExecutionLog]', 'U') IS NULL
    BEGIN
        RAISERROR('No existe la tabla [$(PocSchema)].[JobExecutionLog].', 16, 1);
    END
END
GO

SELECT
    @@SERVERNAME AS SqlServerName,
    DB_NAME() AS DatabaseName,
    GETUTCDATE() AS ValidationUtc;
GO

SELECT
    s.name AS SchemaName,
    t.name AS TableName
FROM sys.tables t
INNER JOIN sys.schemas s
    ON s.schema_id = t.schema_id
WHERE s.name = N'$(QuartzSchema)'
  AND t.name LIKE N'QRTZ[_]%'
ORDER BY t.name;
GO

PRINT 'Validacion completada correctamente.';
GO
