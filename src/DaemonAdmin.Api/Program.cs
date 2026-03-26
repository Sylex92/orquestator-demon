using DaemonPlatform.Contracts.Configuration;
using DaemonPlatform.Core.Configuration;
using DaemonPlatform.Core.Extensions;
using DaemonPlatform.Core.Logging;
using DaemonPlatform.Quartz;
using DaemonPlatform.Secrets;
using DaemonAdmin.Api.Infrastructure;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;

var builder = WebApplication.CreateBuilder(args);

builder.Configuration.AddJsonFile("appsettings.Local.json", optional: true, reloadOnChange: false);

var nodeSettingsFile = Environment.GetEnvironmentVariable("DAEMON_NODE_SETTINGS_FILE");
if (!string.IsNullOrWhiteSpace(nodeSettingsFile))
{
    builder.Configuration.AddJsonFile(nodeSettingsFile, optional: false, reloadOnChange: false);
}

builder.Logging.AddPlatformLogging(builder.Configuration);

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
builder.Services.AddDaemonQuartzAdministrationServices(builder.Configuration, resolvedConnectionStrings);
builder.Services.AddTransient<CorrelationIdMiddleware>();
builder.Services.AddControllers();

var app = builder.Build();

app.UseMiddleware<CorrelationIdMiddleware>();
app.UseHttpsRedirection();
app.MapControllers();
app.MapHealthChecks("/health/live");
app.MapHealthChecks("/health/ready", new HealthCheckOptions());

app.Run();
