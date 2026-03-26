using DaemonPlatform.Contracts.Configuration;
using DaemonPlatform.Quartz.Jobs;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Quartz;

namespace DaemonPlatform.Quartz;

public sealed class DemoJobCatalogBootstrapper(
    IOptions<DemoJobsOptions> demoJobsOptions,
    IOptions<QuartzClusterOptions> quartzOptions,
    ILogger<DemoJobCatalogBootstrapper> logger)
{
    public async Task EnsureScheduledAsync(IScheduler scheduler, CancellationToken cancellationToken)
    {
        await EnsureFastJobAsync(scheduler, cancellationToken);
        await EnsureSlowJobAsync(scheduler, cancellationToken);
        logger.LogInformation("Catálogo demo Quartz sincronizado. Scheduler={SchedulerName}.", quartzOptions.Value.SchedulerName);
    }

    private async Task EnsureFastJobAsync(IScheduler scheduler, CancellationToken cancellationToken)
    {
        var job = JobBuilder.Create<JobDemoRapido>()
            .WithIdentity(QuartzKeys.FastJobKey)
            .StoreDurably()
            .RequestRecovery()
            .WithDescription("Job demo rápido para validar ejecución distribuida cada minuto.")
            .Build();

        var trigger = TriggerBuilder.Create()
            .WithIdentity(QuartzKeys.FastTriggerKey)
            .ForJob(QuartzKeys.FastJobKey)
            .WithDescription("Trigger cron de JobDemoRapido.")
            .WithCronSchedule(demoJobsOptions.Value.FastCron, cron => cron.WithMisfireHandlingInstructionDoNothing())
            .Build();

        await UpsertAsync(scheduler, job, trigger, cancellationToken);
    }

    private async Task EnsureSlowJobAsync(IScheduler scheduler, CancellationToken cancellationToken)
    {
        var job = JobBuilder.Create<JobDemoLento>()
            .WithIdentity(QuartzKeys.SlowJobKey)
            .StoreDurably()
            .RequestRecovery()
            .UsingJobData("DelaySeconds", demoJobsOptions.Value.SlowDurationSeconds)
            .WithDescription("Job demo lento para validar failover y recovery.")
            .Build();

        var trigger = TriggerBuilder.Create()
            .WithIdentity(QuartzKeys.SlowTriggerKey)
            .ForJob(QuartzKeys.SlowJobKey)
            .WithDescription("Trigger cron de JobDemoLento.")
            .WithCronSchedule(demoJobsOptions.Value.SlowCron, cron => cron.WithMisfireHandlingInstructionDoNothing())
            .Build();

        await UpsertAsync(scheduler, job, trigger, cancellationToken);
    }

    private async Task UpsertAsync(IScheduler scheduler, IJobDetail job, ITrigger trigger, CancellationToken cancellationToken)
    {
        await scheduler.AddJob(
            job,
            replace: quartzOptions.Value.OverwriteExistingJobs,
            storeNonDurableWhileAwaitingScheduling: true,
            cancellationToken: cancellationToken);

        if (await scheduler.CheckExists(trigger.Key, cancellationToken))
        {
            await scheduler.RescheduleJob(trigger.Key, trigger, cancellationToken);
            return;
        }

        await scheduler.ScheduleJob(trigger, cancellationToken);
    }
}
