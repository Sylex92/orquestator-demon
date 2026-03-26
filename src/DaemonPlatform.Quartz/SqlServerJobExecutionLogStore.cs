using DaemonPlatform.Contracts.Configuration;
using DaemonPlatform.Contracts.Models;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;

namespace DaemonPlatform.Quartz;

public sealed class SqlServerJobExecutionLogStore(
    IOptions<ExecutionHistoryOptions> historyOptions,
    ResolvedConnectionStrings connectionStrings) : IJobExecutionLogStore
{
    public async Task RecordStartAsync(JobExecutionStarted started, CancellationToken cancellationToken)
    {
        if (!historyOptions.Value.Enabled)
        {
            return;
        }

        var sql = $"""
            INSERT INTO {QuartzSqlNaming.ExecutionHistoryTable(historyOptions.Value)}
            (
                RunId,
                SchedulerName,
                JobGroup,
                JobName,
                TriggerGroup,
                TriggerName,
                FireInstanceId,
                NodeName,
                StartedAtUtc,
                Recovering,
                Status
            )
            VALUES
            (
                @RunId,
                @SchedulerName,
                @JobGroup,
                @JobName,
                @TriggerGroup,
                @TriggerName,
                @FireInstanceId,
                @NodeName,
                @StartedAtUtc,
                @Recovering,
                @Status
            );
            """;

        await using var connection = new SqlConnection(connectionStrings.ExecutionHistory);
        await connection.OpenAsync(cancellationToken);
        await using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@RunId", started.RunId);
        command.Parameters.AddWithValue("@SchedulerName", started.SchedulerName);
        command.Parameters.AddWithValue("@JobGroup", started.JobGroup);
        command.Parameters.AddWithValue("@JobName", started.JobName);
        command.Parameters.AddWithValue("@TriggerGroup", started.TriggerGroup);
        command.Parameters.AddWithValue("@TriggerName", started.TriggerName);
        command.Parameters.AddWithValue("@FireInstanceId", started.FireInstanceId);
        command.Parameters.AddWithValue("@NodeName", started.NodeName);
        command.Parameters.AddWithValue("@StartedAtUtc", started.StartedAtUtc.UtcDateTime);
        command.Parameters.AddWithValue("@Recovering", started.Recovering);
        command.Parameters.AddWithValue("@Status", "Running");
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    public async Task RecordCompletionAsync(JobExecutionCompleted completed, CancellationToken cancellationToken)
    {
        if (!historyOptions.Value.Enabled)
        {
            return;
        }

        var sql = $"""
            UPDATE {QuartzSqlNaming.ExecutionHistoryTable(historyOptions.Value)}
            SET
                FinishedAtUtc = @FinishedAtUtc,
                DurationMs = @DurationMs,
                Status = @Status,
                Result = @Result
            WHERE FireInstanceId = @FireInstanceId;
            """;

        await using var connection = new SqlConnection(connectionStrings.ExecutionHistory);
        await connection.OpenAsync(cancellationToken);
        await using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@FinishedAtUtc", completed.FinishedAtUtc.UtcDateTime);
        command.Parameters.AddWithValue("@DurationMs", completed.DurationMs);
        command.Parameters.AddWithValue("@Status", completed.Status);
        command.Parameters.AddWithValue("@Result", (object?)completed.Result ?? DBNull.Value);
        command.Parameters.AddWithValue("@FireInstanceId", completed.FireInstanceId);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    public async Task<JobExecutionHistoryItemResponse?> GetLastExecutionAsync(string jobGroup, string jobName, CancellationToken cancellationToken)
    {
        var history = await GetRecentExecutionsAsync(jobGroup, jobName, 1, cancellationToken);
        return history.FirstOrDefault();
    }

    public async Task<IReadOnlyList<JobExecutionHistoryItemResponse>> GetRecentExecutionsAsync(string jobGroup, string jobName, int take, CancellationToken cancellationToken)
    {
        if (!historyOptions.Value.Enabled)
        {
            return Array.Empty<JobExecutionHistoryItemResponse>();
        }

        var sql = $"""
            SELECT TOP (@Take)
                RunId,
                JobGroup,
                JobName,
                NodeName,
                StartedAtUtc,
                FinishedAtUtc,
                DurationMs,
                Status,
                Result,
                FireInstanceId,
                Recovering
            FROM {QuartzSqlNaming.ExecutionHistoryTable(historyOptions.Value)}
            WHERE JobGroup = @JobGroup
              AND JobName = @JobName
            ORDER BY StartedAtUtc DESC;
            """;

        var items = new List<JobExecutionHistoryItemResponse>();
        await using var connection = new SqlConnection(connectionStrings.ExecutionHistory);
        await connection.OpenAsync(cancellationToken);
        await using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@Take", take);
        command.Parameters.AddWithValue("@JobGroup", jobGroup);
        command.Parameters.AddWithValue("@JobName", jobName);

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            items.Add(new JobExecutionHistoryItemResponse(
                reader.GetGuid(0),
                reader.GetString(1),
                reader.GetString(2),
                reader.GetString(3),
                new DateTimeOffset(DateTime.SpecifyKind(reader.GetDateTime(4), DateTimeKind.Utc)),
                reader.IsDBNull(5) ? null : new DateTimeOffset(DateTime.SpecifyKind(reader.GetDateTime(5), DateTimeKind.Utc)),
                reader.IsDBNull(6) ? null : reader.GetInt64(6),
                reader.GetString(7),
                reader.IsDBNull(8) ? null : reader.GetString(8),
                reader.IsDBNull(9) ? null : reader.GetString(9),
                reader.GetBoolean(10)));
        }

        return items;
    }
}
