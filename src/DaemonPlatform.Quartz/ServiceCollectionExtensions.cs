using System.Collections.Specialized;
using System.Globalization;
using DaemonPlatform.Contracts.Configuration;
using DaemonPlatform.Quartz.Jobs;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Options;
using Quartz;
using Quartz.Impl;
using Quartz.Spi;

namespace DaemonPlatform.Quartz;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddDaemonQuartzAdministrationServices(
        this IServiceCollection services,
        IConfiguration configuration,
        ResolvedConnectionStrings connectionStrings)
    {
        services.Configure<QuartzClusterOptions>(configuration.GetSection(QuartzClusterOptions.SectionName));
        services.Configure<ExecutionHistoryOptions>(configuration.GetSection(ExecutionHistoryOptions.SectionName));
        services.Configure<DemoJobsOptions>(configuration.GetSection(DemoJobsOptions.SectionName));
        services.AddSingleton(connectionStrings);
        services.AddSingleton<ISchedulerFactory>(sp =>
        {
            var options = sp.GetRequiredService<IOptions<QuartzClusterOptions>>().Value;
            return new StdSchedulerFactory(BuildQuartzProperties(options, connectionStrings.Quartz));
        });
        services.AddSingleton<QuartzClusterRepository>();
        services.AddSingleton<IJobExecutionLogStore, SqlServerJobExecutionLogStore>();
        services.AddSingleton<IJobAdministrationService, QuartzAdministrationService>();
        services.AddHealthChecks().AddCheck<QuartzStorageHealthCheck>("quartz-storage", failureStatus: HealthStatus.Unhealthy);
        return services;
    }

    public static IServiceCollection AddDaemonQuartzWorkerServices(
        this IServiceCollection services,
        IConfiguration configuration,
        ResolvedConnectionStrings connectionStrings)
    {
        services.AddDaemonQuartzAdministrationServices(configuration, connectionStrings);
        services.AddSingleton<IJobFactory, ScopedJobFactory>();
        services.AddSingleton<DemoJobCatalogBootstrapper>();
        services.AddTransient<JobDemoRapido>();
        services.AddTransient<JobDemoLento>();
        services.AddHostedService<QuartzSchedulerHostedService>();
        return services;
    }

    private static NameValueCollection BuildQuartzProperties(QuartzClusterOptions options, string quartzConnectionString)
    {
        return new NameValueCollection
        {
            ["quartz.scheduler.instanceName"] = options.SchedulerName,
            ["quartz.scheduler.instanceId"] = options.InstanceId,
            ["quartz.scheduler.skipUpdateCheck"] = "true",
            ["quartz.serializer.type"] = "stj",
            ["quartz.threadPool.type"] = "Quartz.Simpl.DefaultThreadPool, Quartz",
            ["quartz.threadPool.threadCount"] = options.ThreadCount.ToString(CultureInfo.InvariantCulture),
            ["quartz.jobStore.type"] = "Quartz.Impl.AdoJobStore.JobStoreTX, Quartz",
            ["quartz.jobStore.useProperties"] = "true",
            ["quartz.jobStore.dataSource"] = "default",
            ["quartz.jobStore.tablePrefix"] = $"[{options.Schema}].{options.TablePrefix}",
            ["quartz.jobStore.driverDelegateType"] = options.DriverDelegateType,
            ["quartz.jobStore.clustered"] = "true",
            ["quartz.jobStore.acquireTriggersWithinLock"] = "true",
            ["quartz.jobStore.misfireThreshold"] = TimeSpan.FromSeconds(options.MisfireThresholdSeconds).TotalMilliseconds.ToString(CultureInfo.InvariantCulture),
            ["quartz.jobStore.clusterCheckinInterval"] = TimeSpan.FromSeconds(options.ClusterCheckinIntervalSeconds).TotalMilliseconds.ToString(CultureInfo.InvariantCulture),
            ["quartz.dataSource.default.provider"] = options.Provider,
            ["quartz.dataSource.default.connectionString"] = quartzConnectionString
        };
    }
}
