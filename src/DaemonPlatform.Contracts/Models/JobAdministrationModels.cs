namespace DaemonPlatform.Contracts.Models;

public sealed record TriggerInfoResponse(
    string TriggerGroup,
    string TriggerName,
    string TriggerState,
    DateTimeOffset? NextFireTimeUtc,
    DateTimeOffset? PreviousFireTimeUtc);

public sealed record JobExecutionHistoryItemResponse(
    Guid RunId,
    string JobGroup,
    string JobName,
    string NodeName,
    DateTimeOffset StartedAtUtc,
    DateTimeOffset? FinishedAtUtc,
    long? DurationMs,
    string Status,
    string? Result,
    string? FireInstanceId,
    bool Recovering);

public sealed record JobSummaryResponse(
    string JobGroup,
    string JobName,
    string Description,
    bool Durable,
    bool RequestsRecovery,
    string EffectiveState,
    IReadOnlyList<TriggerInfoResponse> Triggers,
    DateTimeOffset? NextFireTimeUtc,
    DateTimeOffset? PreviousFireTimeUtc,
    string? LastExecutionNode,
    string? LastExecutionStatus,
    DateTimeOffset? LastStartedAtUtc,
    bool IsRunning);

public sealed record JobDetailsResponse(
    JobSummaryResponse Summary,
    IReadOnlyList<JobExecutionHistoryItemResponse> History);

public sealed record ClusterNodeStatusResponse(
    string InstanceName,
    DateTimeOffset LastCheckinUtc,
    TimeSpan CheckinInterval,
    bool ConsideredAlive);

public sealed record SystemStatusResponse(
    string SchedulerName,
    int ConfiguredJobs,
    int ActiveNodes,
    IReadOnlyList<ClusterNodeStatusResponse> Nodes,
    DateTimeOffset RetrievedAtUtc,
    bool QuartzStorageReachable);

public sealed record OperationResponse(bool Success, string Message);
