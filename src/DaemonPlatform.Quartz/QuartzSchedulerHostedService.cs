using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Quartz;
using Quartz.Spi;

namespace DaemonPlatform.Quartz;

public sealed class QuartzSchedulerHostedService(
    ISchedulerFactory schedulerFactory,
    IJobFactory jobFactory,
    DemoJobCatalogBootstrapper bootstrapper,
    ILogger<QuartzSchedulerHostedService> logger) : IHostedService
{
    private IScheduler? scheduler;

    public async Task StartAsync(CancellationToken cancellationToken)
    {
        scheduler = await schedulerFactory.GetScheduler(cancellationToken);
        scheduler.JobFactory = jobFactory;
        await bootstrapper.EnsureScheduledAsync(scheduler, cancellationToken);
        await scheduler.Start(cancellationToken);
        logger.LogInformation(
            "Quartz scheduler iniciado. SchedulerName={SchedulerName}, SchedulerInstanceId={SchedulerInstanceId}.",
            scheduler.SchedulerName,
            scheduler.SchedulerInstanceId);
    }

    public async Task StopAsync(CancellationToken cancellationToken)
    {
        if (scheduler is null)
        {
            return;
        }

        logger.LogInformation("Apagando Quartz scheduler.");
        await scheduler.Shutdown(waitForJobsToComplete: true, cancellationToken);
    }
}
