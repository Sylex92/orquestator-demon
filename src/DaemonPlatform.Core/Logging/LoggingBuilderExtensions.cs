using DaemonPlatform.Contracts.Configuration;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace DaemonPlatform.Core.Logging;

public static class LoggingBuilderExtensions
{
    public static ILoggingBuilder AddPlatformLogging(this ILoggingBuilder builder, IConfiguration configuration)
    {
        builder.ClearProviders();
        builder.AddJsonConsole(options => options.IncludeScopes = true);

        var fileOptions = configuration.GetSection(FileLoggingOptions.SectionName).Get<FileLoggingOptions>() ?? new FileLoggingOptions();
        if (fileOptions.Enabled)
        {
            builder.Services.Configure<FileLoggingOptions>(configuration.GetSection(FileLoggingOptions.SectionName));
            builder.Services.AddSingleton<ILoggerProvider, FileJsonLoggerProvider>();
        }

        return builder;
    }
}
