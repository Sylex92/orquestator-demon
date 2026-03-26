using DaemonPlatform.Contracts.Configuration;
using DaemonPlatform.Contracts.Models;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;

namespace DaemonPlatform.Quartz;

public sealed class QuartzClusterRepository(
    IOptions<QuartzClusterOptions> quartzOptions,
    ResolvedConnectionStrings connectionStrings)
{
    public async Task<IReadOnlyList<ClusterNodeStatusResponse>> GetClusterNodesAsync(CancellationToken cancellationToken)
    {
        var sql = $"""
            SELECT INSTANCE_NAME, LAST_CHECKIN_TIME, CHECKIN_INTERVAL
            FROM {QuartzSqlNaming.QuartzTable(quartzOptions.Value, "SCHEDULER_STATE")}
            WHERE SCHED_NAME = @SchedulerName
            ORDER BY INSTANCE_NAME;
            """;

        var results = new List<ClusterNodeStatusResponse>();
        await using var connection = new SqlConnection(connectionStrings.Quartz);
        await connection.OpenAsync(cancellationToken);
        await using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@SchedulerName", quartzOptions.Value.SchedulerName);

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            var lastCheckin = DateTimeOffset.FromUnixTimeMilliseconds(reader.GetInt64(1));
            var interval = TimeSpan.FromMilliseconds(reader.GetInt64(2));
            var consideredAlive = lastCheckin.Add(interval + interval) >= DateTimeOffset.UtcNow;

            results.Add(new ClusterNodeStatusResponse(reader.GetString(0), lastCheckin, interval, consideredAlive));
        }

        return results;
    }

    public async Task<Dictionary<string, RunningJobInfo>> GetRunningJobsAsync(CancellationToken cancellationToken)
    {
        var sql = $"""
            SELECT JOB_GROUP, JOB_NAME, INSTANCE_NAME
            FROM {QuartzSqlNaming.QuartzTable(quartzOptions.Value, "FIRED_TRIGGERS")}
            WHERE SCHED_NAME = @SchedulerName
              AND STATE = 'EXECUTING';
            """;

        var items = new Dictionary<string, RunningJobInfo>(StringComparer.OrdinalIgnoreCase);
        await using var connection = new SqlConnection(connectionStrings.Quartz);
        await connection.OpenAsync(cancellationToken);
        await using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@SchedulerName", quartzOptions.Value.SchedulerName);

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            var info = new RunningJobInfo(reader.GetString(0), reader.GetString(1), reader.GetString(2));
            items[$"{info.JobGroup}:{info.JobName}"] = info;
        }

        return items;
    }
}
