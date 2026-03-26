using DaemonPlatform.Core.Runtime;
using Microsoft.Extensions.Logging;
using Quartz;

namespace DaemonPlatform.Quartz.Jobs;

[DisallowConcurrentExecution]
public sealed class JobDemoLento(
    INodeIdentityAccessor nodeIdentityAccessor,
    IJobExecutionLogStore executionLogStore,
    ILogger<JobDemoLento> logger)
    : ObservedJobBase<JobDemoLento>(nodeIdentityAccessor, executionLogStore, logger)
{
    protected override async Task<string> ExecuteCoreAsync(IJobExecutionContext context, CancellationToken cancellationToken)
    {
        var delaySeconds = context.MergedJobDataMap.GetInt("DelaySeconds");
        var totalDelay = TimeSpan.FromSeconds(delaySeconds <= 0 ? 150 : delaySeconds);
        var start = DateTimeOffset.UtcNow;

        while (DateTimeOffset.UtcNow - start < totalDelay)
        {
            logger.LogInformation(
                "JobDemoLento sigue ejecutándose. FireInstanceId={FireInstanceId}, Recovering={Recovering}.",
                context.FireInstanceId,
                context.Recovering);

            await Task.Delay(TimeSpan.FromSeconds(30), cancellationToken);
        }

        return $"JobDemoLento completado tras {totalDelay.TotalSeconds} segundos.";
    }
}
