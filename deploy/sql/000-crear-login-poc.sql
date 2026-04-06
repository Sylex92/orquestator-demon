/*
  Script previo para PoC.
  Ejecutar en la base [master].

  Crea un unico login SQL para:
  - runtime Quartz
  - historial PoC

  Ajusta el nombre del login y el password antes de ejecutar.
*/

USE [master];
GO

DECLARE @LoginName sysname = N'svc_daemon_quartz_runtime';
DECLARE @LoginPassword nvarchar(256) = N'Temporal_POC_2026_Strong!';
DECLARE @LoginNameQuoted nvarchar(260) = QUOTENAME(@LoginName);
DECLARE @Sql nvarchar(max);

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = @LoginName)
BEGIN
    SET @Sql =
        N'CREATE LOGIN ' + @LoginNameQuoted +
        N' WITH PASSWORD = ' + QUOTENAME(@LoginPassword, '''') +
        N', CHECK_POLICY = ON, CHECK_EXPIRATION = OFF;';

    EXEC (@Sql);
    PRINT N'Login creado: ' + @LoginName;
END
ELSE
BEGIN
    PRINT N'Login ya existe: ' + @LoginName;
END;
GO
