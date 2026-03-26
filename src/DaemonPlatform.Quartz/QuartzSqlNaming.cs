using DaemonPlatform.Contracts.Configuration;

namespace DaemonPlatform.Quartz;

internal static class QuartzSqlNaming
{
    public static string QuartzTable(QuartzClusterOptions options, string suffix) => $"[{options.Schema}].[{options.TablePrefix}{suffix}]";

    public static string ExecutionHistoryTable(ExecutionHistoryOptions options) => $"[{options.Schema}].[{options.TableName}]";
}
