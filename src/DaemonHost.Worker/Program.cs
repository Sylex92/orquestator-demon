using DaemonPlatform.Contracts.Configuration;
using DaemonPlatform.Core.Configuration;
using DaemonPlatform.Core.Extensions;
using DaemonPlatform.Core.Logging;
using DaemonPlatform.Quartz;
using DaemonPlatform.Secrets;

var builder = Host.CreateApplicationBuilder(args);

builder.Configuration.AddJsonFile("appsettings.Local.json", optional: true, reloadOnChange: false);

var nodeSettingsFile = Environment.GetEnvironmentVariable("DAEMON_NODE_SETTINGS_FILE");
if (!string.IsNullOrWhiteSpace(nodeSettingsFile))
{
    builder.Configuration.AddJsonFile(nodeSettingsFile, optional: false, reloadOnChange: false);
}

builder.Logging.AddPlatformLogging(builder.Configuration);
builder.Services.AddWindowsService(options => options.ServiceName = "DaemonPlatform.Worker");

var bootstrapSecretProvider = DaemonPlatform.Secrets.ServiceCollectionExtensions.CreateBootstrapCredentialProvider(builder.Configuration);
var bootstrapResolver = new ConnectionStringTemplateResolver(bootstrapSecretProvider);
var quartzOptions = builder.Configuration.GetSection(QuartzClusterOptions.SectionName).Get<QuartzClusterOptions>() ?? new QuartzClusterOptions();
var historyOptions = builder.Configuration.GetSection(ExecutionHistoryOptions.SectionName).Get<ExecutionHistoryOptions>() ?? new ExecutionHistoryOptions();
var historyTemplate = string.IsNullOrWhiteSpace(historyOptions.ConnectionStringTemplate)
    ? quartzOptions.ConnectionStringTemplate
    : historyOptions.ConnectionStringTemplate;

var resolvedConnectionStrings = new ResolvedConnectionStrings(
    await bootstrapResolver.ResolveRequiredAsync(quartzOptions.ConnectionStringTemplate),
    await bootstrapResolver.ResolveRequiredAsync(historyTemplate));

builder.Services.AddPlatformCoreServices(builder.Configuration);
builder.Services.AddCredentialManagerSecretProvider(builder.Configuration, bootstrapSecretProvider);
builder.Services.AddDaemonQuartzWorkerServices(builder.Configuration, resolvedConnectionStrings);

var host = builder.Build();
await host.RunAsync();
