using Microsoft.Extensions.DependencyInjection;
using Quartz;
using Quartz.Spi;

namespace DaemonPlatform.Quartz;

public sealed class ScopedJobFactory(IServiceProvider serviceProvider) : IJobFactory
{
    private readonly Dictionary<IJob, IServiceScope> scopes = new();

    public IJob NewJob(TriggerFiredBundle bundle, IScheduler scheduler)
    {
        var scope = serviceProvider.CreateScope();
        try
        {
            var job = (IJob)scope.ServiceProvider.GetRequiredService(bundle.JobDetail.JobType);
            scopes[job] = scope;
            return job;
        }
        catch
        {
            scope.Dispose();
            throw;
        }
    }

    public void ReturnJob(IJob job)
    {
        if (scopes.Remove(job, out var scope))
        {
            scope.Dispose();
        }

        (job as IDisposable)?.Dispose();
    }
}
