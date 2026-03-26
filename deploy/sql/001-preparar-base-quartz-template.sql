/*
  Plantilla para Infra/DBA.
  Ejecutar en SSMS con SQLCMD Mode habilitado, o adaptar valores manualmente.

  Este script:
  - crea base si no existe;
  - crea schema [quartz];
  - crea schema [poc] opcional;
  - crea roles de acceso;
  - mapea usuarios a logins ya existentes;
  - otorga permisos minimos.

  Este script NO crea las tablas QRTZ_*.
  Las tablas Quartz deben instalarse con el script oficial de Quartz para SQL Server,
  adaptado al schema [quartz].
*/

:setvar DatabaseName "DaemonQuartz"
:setvar QuartzSchema "quartz"
:setvar PocSchema "poc"
:setvar RuntimeLogin "svc_daemon_quartz_runtime"
:setvar PocLogin "svc_daemon_quartz_poc"
:setvar CreatePocSchema "1"

SET NOCOUNT ON;
GO

IF DB_ID(N'$(DatabaseName)') IS NULL
BEGIN
    DECLARE @createDatabaseSql nvarchar(max) =
        N'CREATE DATABASE ' + QUOTENAME(N'$(DatabaseName)') + N';';

    EXEC (@createDatabaseSql);
    PRINT 'Base creada: $(DatabaseName)';
END
ELSE
BEGIN
    PRINT 'Base ya existe: $(DatabaseName)';
END
GO

DECLARE @useDatabaseSql nvarchar(max) =
    N'USE ' + QUOTENAME(N'$(DatabaseName)') + N';';

EXEC (@useDatabaseSql);
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'$(QuartzSchema)')
BEGIN
    DECLARE @createQuartzSchemaSql nvarchar(max) =
        N'CREATE SCHEMA ' + QUOTENAME(N'$(QuartzSchema)') + N';';

    EXEC (@createQuartzSchemaSql);
    PRINT 'Schema creado: $(QuartzSchema)';
END
ELSE
BEGIN
    PRINT 'Schema ya existe: $(QuartzSchema)';
END
GO

IF '$(CreatePocSchema)' = '1'
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'$(PocSchema)')
    BEGIN
        DECLARE @createPocSchemaSql nvarchar(max) =
            N'CREATE SCHEMA ' + QUOTENAME(N'$(PocSchema)') + N';';

        EXEC (@createPocSchemaSql);
        PRINT 'Schema creado: $(PocSchema)';
    END
    ELSE
    BEGIN
        PRINT 'Schema ya existe: $(PocSchema)';
    END
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'quartz_runtime_rw')
BEGIN
    CREATE ROLE [quartz_runtime_rw];
    PRINT 'Rol creado: quartz_runtime_rw';
END
ELSE
BEGIN
    PRINT 'Rol ya existe: quartz_runtime_rw';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'quartz_poc_rw')
BEGIN
    CREATE ROLE [quartz_poc_rw];
    PRINT 'Rol creado: quartz_poc_rw';
END
ELSE
BEGIN
    PRINT 'Rol ya existe: quartz_poc_rw';
END
GO

IF SUSER_ID(N'$(RuntimeLogin)') IS NULL
BEGIN
    RAISERROR('El login $(RuntimeLogin) no existe en la instancia SQL. Crear login antes de continuar.', 16, 1);
END
GO

IF USER_ID(N'$(RuntimeLogin)') IS NULL
BEGIN
    DECLARE @createRuntimeUserSql nvarchar(max) =
        N'CREATE USER ' + QUOTENAME(N'$(RuntimeLogin)') +
        N' FOR LOGIN ' + QUOTENAME(N'$(RuntimeLogin)') + N';';

    EXEC (@createRuntimeUserSql);
    PRINT 'Usuario creado para login runtime: $(RuntimeLogin)';
END
ELSE
BEGIN
    PRINT 'Usuario runtime ya existe: $(RuntimeLogin)';
END
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.database_role_members drm
    INNER JOIN sys.database_principals rolePrincipal
        ON rolePrincipal.principal_id = drm.role_principal_id
    INNER JOIN sys.database_principals memberPrincipal
        ON memberPrincipal.principal_id = drm.member_principal_id
    WHERE rolePrincipal.name = N'quartz_runtime_rw'
      AND memberPrincipal.name = N'$(RuntimeLogin)'
)
BEGIN
    ALTER ROLE [quartz_runtime_rw] ADD MEMBER [$(RuntimeLogin)];
    PRINT 'Login runtime agregado a quartz_runtime_rw';
END
GO

GRANT SELECT, INSERT, UPDATE, DELETE
    ON SCHEMA::[$(QuartzSchema)]
    TO [quartz_runtime_rw];
GO

IF '$(CreatePocSchema)' = '1'
BEGIN
    IF SUSER_ID(N'$(PocLogin)') IS NULL
    BEGIN
        PRINT 'Aviso: el login $(PocLogin) no existe. Se omitira mapeo de usuario PoC.';
    END
    ELSE
    BEGIN
        IF USER_ID(N'$(PocLogin)') IS NULL
        BEGIN
            DECLARE @createPocUserSql nvarchar(max) =
                N'CREATE USER ' + QUOTENAME(N'$(PocLogin)') +
                N' FOR LOGIN ' + QUOTENAME(N'$(PocLogin)') + N';';

            EXEC (@createPocUserSql);
            PRINT 'Usuario creado para login PoC: $(PocLogin)';
        END

        IF NOT EXISTS
        (
            SELECT 1
            FROM sys.database_role_members drm
            INNER JOIN sys.database_principals rolePrincipal
                ON rolePrincipal.principal_id = drm.role_principal_id
            INNER JOIN sys.database_principals memberPrincipal
                ON memberPrincipal.principal_id = drm.member_principal_id
            WHERE rolePrincipal.name = N'quartz_poc_rw'
              AND memberPrincipal.name = N'$(PocLogin)'
        )
        BEGIN
            ALTER ROLE [quartz_poc_rw] ADD MEMBER [$(PocLogin)];
            PRINT 'Login PoC agregado a quartz_poc_rw';
        END

        GRANT SELECT, INSERT, UPDATE, DELETE
            ON SCHEMA::[$(PocSchema)]
            TO [quartz_poc_rw];
    END
END
GO

PRINT 'PASO MANUAL OBLIGATORIO:';
PRINT '1. Ejecutar el script oficial de Quartz para SQL Server.';
PRINT '2. Adaptarlo para instalar tablas en el schema [$(QuartzSchema)].';
PRINT '3. Mantener el prefijo QRTZ_.';
PRINT '4. Validar luego con 002-validar-instalacion-quartz.sql.';
GO

SELECT
    DB_NAME() AS DatabaseName,
    s.name AS SchemaName
FROM sys.schemas s
WHERE s.name IN (N'$(QuartzSchema)', N'$(PocSchema)')
ORDER BY s.name;
GO
