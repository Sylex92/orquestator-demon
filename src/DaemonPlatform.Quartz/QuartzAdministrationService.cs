using DaemonPlatform.Contracts.Configuration;
using DaemonPlatform.Contracts.Models;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Options;
using Quartz;
using Quartz.Impl.Matchers;

namespace DaemonPlatform.Quartz;

public sealed class QuartzAdministrationService(
    ISchedulerFactory schedulerFactory,
    IJobExecutionLogStore executionLogStore,
    QuartzClusterRepository clusterRepository,
    IOptions<QuartzClusterOptions> quartzOptions,
    HealthCheckService healthCheckService) : IJobAdministrationService
{
    public async Task<IReadOnlyList<JobSummaryResponse>> GetJobsAsync(CancellationToken cancellationToken)
    {
        var scheduler = await schedulerFactory.GetScheduler(cancellationToken);
        var runningJobs = await clusterRepository.GetRunningJobsAsync(cancellationToken);
        var jobs = new List<JobSummaryResponse>();

        foreach (var group in await scheduler.GetJobGroupNames(cancellationToken))
        {
            var jobKeys = await scheduler.GetJobKeys(GroupMatcher<JobKey>.GroupEquals(group), cancellationToken);
            foreach (var jobKey in jobKeys.OrderBy(item => item.Name, StringComparer.OrdinalIgnoreCase))
            {
                jobs.Add(await BuildSummaryAsync(scheduler, jobKey, runningJobs, cancellationToken));
            }
        }

        return jobs;
    }

    public async Task<JobDetailsResponse?> GetJobAsync(string jobGroup, string jobName, CancellationToken cancellationToken)
    {
        var scheduler = await schedulerFactory.GetScheduler(cancellationToken);
        var key = new JobKey(jobName, jobGroup);
        if (!await scheduler.CheckExists(key, cancellationToken))
        {
            return null;
        }

        var runningJobs = await clusterRepository.GetRunningJobsAsync(cancellationToken);
        var summary = await BuildSummaryAsync(scheduler, key, runningJobs, cancellationToken);
        var history = await executionLogStore.GetRecentExecutionsAsync(jobGroup, jobName, 20, cancellationToken);
        return new JobDetailsResponse(summary, history);
    }

    public async Task<OperationResponse> RunNowAsync(string jobGroup, string jobName, CancellationToken cancellationToken)
    {
        var scheduler = await schedulerFactory.GetScheduler(cancellationToken);
        var key = new JobKey(jobName, jobGroup);
        if (!await scheduler.CheckExists(key, cancellationToken))
        {
            return new OperationResponse(false, "El job no existe.");
        }

        await scheduler.TriggerJob(key, cancellationToken: cancellationToken);
        return new OperationResponse(true, "Se solicitó la ejecución inmediata del job.");
    }

    public async Task<OperationResponse> PauseAsync(string jobGroup, string jobName, CancellationToken cancellationToken)
    {
        var scheduler = await schedulerFactory.GetScheduler(cancellationToken);
        var key = new JobKey(jobName, jobGroup);
        if (!await scheduler.CheckExists(key, cancellationToken))
        {
            return new OperationResponse(false, "El job no existe.");
        }

        await scheduler.PauseJob(key, cancellationToken);
        return new OperationResponse(true, "El job quedó en pausa.");
    }

    public async Task<OperationResponse> ResumeAsync(string jobGroup, string jobName, CancellationToken cancellationToken)
    {
        var scheduler = await schedulerFactory.GetScheduler(cancellationToken);
        var key = new JobKey(jobName, jobGroup);
        if (!await scheduler.CheckExists(key, cancellationToken))
        {
            return new OperationResponse(false, "El job no existe.");
        }

        await scheduler.ResumeJob(key, cancellationToken);
        return new OperationResponse(true, "El job se reanudó.");
    }

    public Task<IReadOnlyList<JobExecutionHistoryItemResponse>> GetHistoryAsync(string jobGroup, string jobName, int take, CancellationToken cancellationToken)
        => executionLogStore.GetRecentExecutionsAsync(jobGroup, jobName, take, cancellationToken);

    public async Task<SystemStatusResponse> GetSystemStatusAsync(CancellationToken cancellationToken)
    {
        var jobs = await GetJobsAsync(cancellationToken);
        var nodes = await clusterRepository.GetClusterNodesAsync(cancellationToken);
        var health = await healthCheckService.CheckHealthAsync(cancellationToken: cancellationToken);

        return new SystemStatusResponse(
            quartzOptions.Value.SchedulerName,
            jobs.Count,
            nodes.Count(node => node.ConsideredAlive),
            nodes,
            DateTimeOffset.UtcNow,
            health.Status != HealthStatus.Unhealthy);
    }

    private async Task<JobSummaryResponse> BuildSummaryAsync(
        IScheduler scheduler,
        JobKey key,
        IReadOnlyDictionary<string, RunningJobInfo> runningJobs,
        CancellationToken cancellationToken)
    {
        var jobDetail = await scheduler.GetJobDetail(key, cancellationToken);
        var triggers = await scheduler.GetTriggersOfJob(key, cancellationToken);
        var lastExecution = await executionLogStore.GetLastExecutionAsync(key.Group, key.Name, cancellationToken);
        var jobDescription = jobDetail?.Description ?? string.Empty;
        var durable = jobDetail?.Durable ?? false;
        var requestsRecovery = jobDetail?.RequestsRecovery ?? false;

        var triggerItems = new List<TriggerInfoResponse>();
        foreach (var trigger in triggers)
        {
            var state = await scheduler.GetTriggerState(trigger.Key, cancellationToken);
            triggerItems.Add(new TriggerInfoResponse(
                trigger.Key.Group,
                trigger.Key.Name,
                state.ToString(),
                trigger.GetNextFireTimeUtc(),
                trigger.GetPreviousFireTimeUtc()));
        }

        var sortedTriggers = triggerItems.OrderBy(item => item.NextFireTimeUtc ?? DateTimeOffset.MaxValue).ToArray();
        var isRunning = runningJobs.ContainsKey($"{key.Group}:{key.Name}");
        var effectiveState = isRunning
            ? "Running"
            : sortedTriggers.Any(item => string.Equals(item.TriggerState, "Paused", StringComparison.OrdinalIgnoreCase))
                ? "Paused"
                : "Scheduled";

        return new JobSummaryResponse(
            key.Group,
            key.Name,
            jobDescription,
            durable,
            requestsRecovery,
            effectiveState,
            sortedTriggers,
            sortedTriggers.FirstOrDefault(item => item.NextFireTimeUtc.HasValue)?.NextFireTimeUtc,
            sortedTriggers.FirstOrDefault(item => item.PreviousFireTimeUtc.HasValue)?.PreviousFireTimeUtc,
            lastExecution?.NodeName,
            lastExecution?.Status,
            lastExecution?.StartedAtUtc,
            isRunning);
    }
}
