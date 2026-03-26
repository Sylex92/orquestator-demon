using DaemonPlatform.Core.Runtime;
using Microsoft.Extensions.Logging;
using Quartz;

namespace DaemonPlatform.Quartz.Jobs;

[DisallowConcurrentExecution]
public sealed class JobDemoRapido(
    INodeIdentityAccessor nodeIdentityAccessor,
    IJobExecutionLogStore executionLogStore,
    ILogger<JobDemoRapido> logger)
    : ObservedJobBase<JobDemoRapido>(nodeIdentityAccessor, executionLogStore, logger)
{
    protected override async Task<string> ExecuteCoreAsync(IJobExecutionContext context, CancellationToken cancellationToken)
    {
        await Task.Delay(TimeSpan.FromMilliseconds(300), cancellationToken);
        return $"JobDemoRapido ejecutado por {Environment.MachineName}.";
    }
}
