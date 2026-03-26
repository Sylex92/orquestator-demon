namespace DaemonPlatform.Contracts.Configuration;

public sealed class QuartzClusterOptions
{
    public const string SectionName = "Quartz";

    public string SchedulerName { get; set; } = "DaemonPlatformCluster";

    public string InstanceId { get; set; } = "AUTO";

    public string DriverDelegateType { get; set; } = "Quartz.Impl.AdoJobStore.SqlServerDelegate, Quartz";

    public string Provider { get; set; } = "SqlServer";

    public string Schema { get; set; } = "quartz";

    public string TablePrefix { get; set; } = "QRTZ_";

    public int ThreadCount { get; set; } = 10;

    public int MisfireThresholdSeconds { get; set; } = 60;

    public int ClusterCheckinIntervalSeconds { get; set; } = 15;

    public string ConnectionStringTemplate { get; set; } = string.Empty;

    public bool OverwriteExistingJobs { get; set; }
}
