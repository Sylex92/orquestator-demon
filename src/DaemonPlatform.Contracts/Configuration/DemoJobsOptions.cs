namespace DaemonPlatform.Contracts.Configuration;

public sealed class DemoJobsOptions
{
    public const string SectionName = "DemoJobs";

    public string FastCron { get; set; } = "0 0/1 * * * ?";

    public string SlowCron { get; set; } = "0 0/3 * * * ?";

    public int SlowDurationSeconds { get; set; } = 150;
}
