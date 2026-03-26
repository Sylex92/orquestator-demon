/*
  PoC only.
  Esta tabla NO pertenece al modelo operativo real del negocio.
  Su objetivo es dar visibilidad basica de ejecuciones en la UI/API.
*/

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'poc')
BEGIN
    EXEC('CREATE SCHEMA [poc]');
END
GO

IF OBJECT_ID('[poc].[JobExecutionLog]', 'U') IS NULL
BEGIN
    CREATE TABLE [poc].[JobExecutionLog]
    (
        [RunId] UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
        [SchedulerName] NVARCHAR(200) NOT NULL,
        [JobGroup] NVARCHAR(200) NOT NULL,
        [JobName] NVARCHAR(200) NOT NULL,
        [TriggerGroup] NVARCHAR(200) NOT NULL,
        [TriggerName] NVARCHAR(200) NOT NULL,
        [FireInstanceId] NVARCHAR(200) NOT NULL,
        [NodeName] NVARCHAR(200) NOT NULL,
        [StartedAtUtc] DATETIME2(3) NOT NULL,
        [FinishedAtUtc] DATETIME2(3) NULL,
        [DurationMs] BIGINT NULL,
        [Recovering] BIT NOT NULL CONSTRAINT [DF_JobExecutionLog_Recovering] DEFAULT (0),
        [Status] NVARCHAR(50) NOT NULL,
        [Result] NVARCHAR(4000) NULL
    );

    CREATE UNIQUE INDEX [IX_JobExecutionLog_FireInstanceId]
        ON [poc].[JobExecutionLog]([FireInstanceId]);

    CREATE INDEX [IX_JobExecutionLog_JobLookup]
        ON [poc].[JobExecutionLog]([JobGroup], [JobName], [StartedAtUtc] DESC);
END
GO
