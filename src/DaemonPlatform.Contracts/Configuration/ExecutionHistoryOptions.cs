namespace DaemonPlatform.Contracts.Configuration;

public sealed class ExecutionHistoryOptions
{
    public const string SectionName = "ExecutionHistory";

    public bool Enabled { get; set; } = true;

    public string ConnectionStringTemplate { get; set; } = string.Empty;

    public string Schema { get; set; } = "poc";

    public string TableName { get; set; } = "JobExecutionLog";
}
