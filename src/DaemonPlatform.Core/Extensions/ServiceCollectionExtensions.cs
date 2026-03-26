using DaemonPlatform.Contracts.Configuration;
using DaemonPlatform.Core.Configuration;
using DaemonPlatform.Core.Runtime;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace DaemonPlatform.Core.Extensions;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddPlatformCoreServices(this IServiceCollection services, IConfiguration configuration)
    {
        services.Configure<PlatformNodeOptions>(configuration.GetSection(PlatformNodeOptions.SectionName));
        services.AddSingleton<INodeIdentityAccessor, NodeIdentityAccessor>();
        services.AddSingleton<IConnectionStringResolver, ConnectionStringTemplateResolver>();

        return services;
    }
}
