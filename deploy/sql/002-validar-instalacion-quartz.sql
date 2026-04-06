/*
  Validacion post-instalacion para Infra/DBA.
  Ejecutar directamente en SSMS. NO requiere SQLCMD Mode.

  Ejecutar despues de:
  - crear base/esquemas/permisos;
  - instalar tablas QRTZ_* con el script oficial de Quartz;
  - crear opcionalmente [poc].[JobExecutionLog].
*/

SET NOCOUNT ON;
GO

DECLARE @DatabaseName sysname = N'DaemonQuartz';
DECLARE @DatabaseNameQuoted nvarchar(260) = QUOTENAME(@DatabaseName);
DECLARE @QuartzSchema sysname = N'quartz';
DECLARE @PocSchema sysname = N'poc';
DECLARE @RuntimeLogin sysname = N'svc_daemon_quartz_runtime';
DECLARE @ValidatePocTable bit = 1;

IF DB_ID(@DatabaseName) IS NULL
BEGIN
    RAISERROR(N'La base %s no existe.', 16, 1, @DatabaseName);
    RETURN;
END;
GO

DECLARE @DatabaseName sysname = N'DaemonQuartz';
DECLARE @DatabaseNameQuoted nvarchar(260) = QUOTENAME(@DatabaseName);
DECLARE @QuartzSchema sysname = N'quartz';
DECLARE @PocSchema sysname = N'poc';
DECLARE @RuntimeLogin sysname = N'svc_daemon_quartz_runtime';
DECLARE @ValidatePocTable bit = 1;

DECLARE @Sql nvarchar(max) = N'USE ' + @DatabaseNameQuoted + N';';
EXEC (@Sql);

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = @QuartzSchema)
BEGIN
    RAISERROR(N'No existe el schema %s.', 16, 1, @QuartzSchema);
    RETURN;
END;

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
    RAISERROR(N'Faltan tablas QRTZ_* en el schema %s. Revisar salida anterior.', 16, 1, @QuartzSchema);
    RETURN;
END;

IF USER_ID(@RuntimeLogin) IS NULL
BEGIN
    RAISERROR(N'No existe el usuario de base para %s.', 16, 1, @RuntimeLogin);
    RETURN;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.database_role_members drm
    INNER JOIN sys.database_principals rolePrincipal
        ON rolePrincipal.principal_id = drm.role_principal_id
    INNER JOIN sys.database_principals memberPrincipal
        ON memberPrincipal.principal_id = drm.member_principal_id
    WHERE rolePrincipal.name = N'quartz_runtime_rw'
      AND memberPrincipal.name = @RuntimeLogin
)
BEGIN
    RAISERROR(N'El usuario %s no pertenece al rol quartz_runtime_rw.', 16, 1, @RuntimeLogin);
    RETURN;
END;

IF @ValidatePocTable = 1
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = @PocSchema)
    BEGIN
        RAISERROR(N'Se solicito validar PoC pero no existe el schema %s.', 16, 1, @PocSchema);
        RETURN;
    END;

    IF OBJECT_ID(QUOTENAME(@PocSchema) + N'.[JobExecutionLog]', 'U') IS NULL
    BEGIN
        RAISERROR(N'No existe la tabla [%s].[JobExecutionLog].', 16, 1, @PocSchema);
        RETURN;
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
  AND t.name LIKE N'QRTZ[_]%'
ORDER BY t.name;

PRINT N'Validacion completada correctamente.';
GO
