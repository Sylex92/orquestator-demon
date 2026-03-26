using DaemonPlatform.Contracts.Models;

namespace DaemonPlatform.Quartz;

public sealed record JobExecutionStarted(
    Guid RunId,
    string SchedulerName,
    string JobGroup,
    string JobName,
    string TriggerGroup,
    string TriggerName,
    string FireInstanceId,
    string NodeName,
    DateTimeOffset StartedAtUtc,
    bool Recovering);

public sealed record JobExecutionCompleted(
    Guid RunId,
    string FireInstanceId,
    DateTimeOffset FinishedAtUtc,
    long DurationMs,
    string Status,
    string? Result);

public sealed record RunningJobInfo(string JobGroup, string JobName, string InstanceName);

public interface IJobExecutionLogStore
{
    Task RecordStartAsync(JobExecutionStarted started, CancellationToken cancellationToken);

    Task RecordCompletionAsync(JobExecutionCompleted completed, CancellationToken cancellationToken);

    Task<JobExecutionHistoryItemResponse?> GetLastExecutionAsync(string jobGroup, string jobName, CancellationToken cancellationToken);

    Task<IReadOnlyList<JobExecutionHistoryItemResponse>> GetRecentExecutionsAsync(string jobGroup, string jobName, int take, CancellationToken cancellationToken);
}
