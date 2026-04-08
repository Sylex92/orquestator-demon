using System.Diagnostics;
using DaemonPlatform.Core.Runtime;
using Microsoft.Extensions.Logging;
using Quartz;

namespace DaemonPlatform.Quartz;

public abstract class ObservedJobBase<TJob>(
    INodeIdentityAccessor nodeIdentityAccessor,
    IJobExecutionLogStore executionLogStore,
    ILogger<TJob> logger) : IJob
    where TJob : class
{
    protected ILogger<TJob> Logger => logger;

    public async Task Execute(IJobExecutionContext context)
    {
        var runId = Guid.NewGuid();
        var startedAtUtc = DateTimeOffset.UtcNow;
        var nodeName = nodeIdentityAccessor.GetCurrentNodeName();
        var trigger = context.Trigger.Key;

        using var scope = logger.BeginScope(new Dictionary<string, object?>
        {
            ["RunId"] = runId,
            ["NodeName"] = nodeName,
            ["JobName"] = context.JobDetail.Key.Name,
            ["JobGroup"] = context.JobDetail.Key.Group,
            ["FireInstanceId"] = context.FireInstanceId
        });

        await executionLogStore.RecordStartAsync(
            new JobExecutionStarted(
                runId,
                context.Scheduler.SchedulerName,
                context.JobDetail.Key.Group,
                context.JobDetail.Key.Name,
                trigger.Group,
                trigger.Name,
                context.FireInstanceId,
                nodeName,
                startedAtUtc,
                context.Recovering),
            context.CancellationToken);

        logger.LogInformation("Inicio de job {JobGroup}.{JobName} en nodo {NodeName}.", context.JobDetail.Key.Group, context.JobDetail.Key.Name, nodeName);

        var stopwatch = Stopwatch.StartNew();
        var status = "Succeeded";
        string? result = null;

        try
        {
            result = await ExecuteCoreAsync(context, context.CancellationToken);
            context.Result = result;
        }
        catch (OperationCanceledException) when (context.CancellationToken.IsCancellationRequested)
        {
            status = "Canceled";
            result = "La ejecución fue cancelada.";
            throw;
        }
        catch (Exception ex)
        {
            status = "Failed";
            result = ex.Message;
            logger.LogError(ex, "El job {JobGroup}.{JobName} terminó con error.", context.JobDetail.Key.Group, context.JobDetail.Key.Name);
            throw;
        }
        finally
        {
            stopwatch.Stop();
            await executionLogStore.RecordCompletionAsync(
                new JobExecutionCompleted(runId, context.FireInstanceId, DateTimeOffset.UtcNow, stopwatch.ElapsedMilliseconds, status, result),
                context.CancellationToken);

            logger.LogInformation(
                "Fin de job {JobGroup}.{JobName} en nodo {NodeName}. Estado={Status}. DuraciónMs={DurationMs}.",
                context.JobDetail.Key.Group,
                context.JobDetail.Key.Name,
                nodeName,
                status,
                stopwatch.ElapsedMilliseconds);
        }
    }

    protected abstract Task<string> ExecuteCoreAsync(IJobExecutionContext context, CancellationToken cancellationToken);
}
