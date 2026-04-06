/*
  Plantilla para Infra/DBA.
  Ejecutar directamente en SSMS. NO requiere SQLCMD Mode.

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

SET NOCOUNT ON;
GO

DECLARE @DatabaseName sysname = N'DaemonQuartz';
DECLARE @DatabaseNameQuoted nvarchar(260) = QUOTENAME(@DatabaseName);
DECLARE @CreateDatabaseSql nvarchar(max);

IF DB_ID(@DatabaseName) IS NULL
BEGIN
    SET @CreateDatabaseSql = N'CREATE DATABASE ' + @DatabaseNameQuoted + N';';
    EXEC (@CreateDatabaseSql);
    PRINT N'Base creada: ' + @DatabaseName;
END
ELSE
BEGIN
    PRINT N'Base ya existe: ' + @DatabaseName;
END;
GO

DECLARE @QuartzSchema sysname = N'quartz';
DECLARE @PocSchema sysname = N'poc';
DECLARE @RuntimeLogin sysname = N'svc_daemon_quartz_runtime';
DECLARE @PocLogin sysname = N'svc_daemon_quartz_runtime';
DECLARE @CreatePocSchema bit = 1;

DECLARE @DatabaseName sysname = N'DaemonQuartz';
DECLARE @DatabaseNameQuoted nvarchar(260) = QUOTENAME(@DatabaseName);
DECLARE @QuartzSchemaQuoted nvarchar(260) = QUOTENAME(@QuartzSchema);
DECLARE @PocSchemaQuoted nvarchar(260) = QUOTENAME(@PocSchema);
DECLARE @RuntimeLoginQuoted nvarchar(260) = QUOTENAME(@RuntimeLogin);
DECLARE @PocLoginQuoted nvarchar(260) = QUOTENAME(@PocLogin);
DECLARE @Sql nvarchar(max);

SET @Sql = N'USE ' + @DatabaseNameQuoted + N';';
EXEC (@Sql);

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = @QuartzSchema)
BEGIN
    SET @Sql = N'CREATE SCHEMA ' + @QuartzSchemaQuoted + N';';
    EXEC (@Sql);
    PRINT N'Schema creado: ' + @QuartzSchema;
END
ELSE
BEGIN
    PRINT N'Schema ya existe: ' + @QuartzSchema;
END;

IF @CreatePocSchema = 1
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = @PocSchema)
    BEGIN
        SET @Sql = N'CREATE SCHEMA ' + @PocSchemaQuoted + N';';
        EXEC (@Sql);
        PRINT N'Schema creado: ' + @PocSchema;
    END
    ELSE
    BEGIN
        PRINT N'Schema ya existe: ' + @PocSchema;
    END;
END;

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'quartz_runtime_rw')
BEGIN
    CREATE ROLE [quartz_runtime_rw];
    PRINT N'Rol creado: quartz_runtime_rw';
END
ELSE
BEGIN
    PRINT N'Rol ya existe: quartz_runtime_rw';
END;

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'quartz_poc_rw')
BEGIN
    CREATE ROLE [quartz_poc_rw];
    PRINT N'Rol creado: quartz_poc_rw';
END
ELSE
BEGIN
    PRINT N'Rol ya existe: quartz_poc_rw';
END;

IF SUSER_ID(@RuntimeLogin) IS NULL
BEGIN
    RAISERROR(N'El login %s no existe en la instancia SQL. Crear login antes de continuar.', 16, 1, @RuntimeLogin);
    RETURN;
END;

IF USER_ID(@RuntimeLogin) IS NULL
BEGIN
    SET @Sql = N'CREATE USER ' + @RuntimeLoginQuoted + N' FOR LOGIN ' + @RuntimeLoginQuoted + N';';
    EXEC (@Sql);
    PRINT N'Usuario creado para login runtime: ' + @RuntimeLogin;
END
ELSE
BEGIN
    PRINT N'Usuario runtime ya existe: ' + @RuntimeLogin;
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
    SET @Sql = N'ALTER ROLE [quartz_runtime_rw] ADD MEMBER ' + @RuntimeLoginQuoted + N';';
    EXEC (@Sql);
    PRINT N'Login runtime agregado a quartz_runtime_rw';
END;

SET @Sql = N'GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::' + @QuartzSchemaQuoted + N' TO [quartz_runtime_rw];';
EXEC (@Sql);

IF @CreatePocSchema = 1
BEGIN
    IF SUSER_ID(@PocLogin) IS NULL
    BEGIN
        PRINT N'Aviso: el login ' + @PocLogin + N' no existe. Se omitira mapeo de usuario PoC.';
    END
    ELSE
    BEGIN
        IF USER_ID(@PocLogin) IS NULL
        BEGIN
            SET @Sql = N'CREATE USER ' + @PocLoginQuoted + N' FOR LOGIN ' + @PocLoginQuoted + N';';
            EXEC (@Sql);
            PRINT N'Usuario creado para login PoC: ' + @PocLogin;
        END;

        IF NOT EXISTS
        (
            SELECT 1
            FROM sys.database_role_members drm
            INNER JOIN sys.database_principals rolePrincipal
                ON rolePrincipal.principal_id = drm.role_principal_id
            INNER JOIN sys.database_principals memberPrincipal
                ON memberPrincipal.principal_id = drm.member_principal_id
            WHERE rolePrincipal.name = N'quartz_poc_rw'
              AND memberPrincipal.name = @PocLogin
        )
        BEGIN
            SET @Sql = N'ALTER ROLE [quartz_poc_rw] ADD MEMBER ' + @PocLoginQuoted + N';';
            EXEC (@Sql);
            PRINT N'Login PoC agregado a quartz_poc_rw';
        END;

        SET @Sql = N'GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::' + @PocSchemaQuoted + N' TO [quartz_poc_rw];';
        EXEC (@Sql);
    END;
END;

SELECT
    DB_NAME() AS DatabaseName,
    s.name AS SchemaName
FROM sys.schemas s
WHERE s.name IN (@QuartzSchema, @PocSchema)
ORDER BY s.name;

PRINT N'PASO MANUAL OBLIGATORIO:';
PRINT N'1. Ejecutar el script oficial de Quartz para SQL Server.';
PRINT N'2. Adaptarlo para instalar tablas en el schema [' + @QuartzSchema + N'].';
PRINT N'3. Mantener el prefijo QRTZ_.';
PRINT N'4. Validar luego con 002-validar-instalacion-quartz.sql.';
GO
