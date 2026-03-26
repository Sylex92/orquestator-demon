using DaemonPlatform.Contracts.Abstractions;
using DaemonPlatform.Contracts.Configuration;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;

namespace DaemonPlatform.Secrets;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddCredentialManagerSecretProvider(
        this IServiceCollection services,
        IConfiguration configuration,
        ISecretProvider? bootstrapProvider = null)
    {
        services.Configure<SecretCatalogOptions>(configuration.GetSection(SecretCatalogOptions.SectionName));

        if (bootstrapProvider is CredentialManagerSecretProvider concreteProvider)
        {
            services.AddSingleton(concreteProvider);
            services.AddSingleton<ISecretProvider>(concreteProvider);
            return services;
        }

        services.AddSingleton<CredentialManagerSecretProvider>();
        services.AddSingleton<ISecretProvider>(serviceProvider =>
            serviceProvider.GetRequiredService<CredentialManagerSecretProvider>());

        return services;
    }

    public static ISecretProvider CreateBootstrapCredentialProvider(IConfiguration configuration)
    {
        var options = new SecretCatalogOptions();
        configuration.GetSection(SecretCatalogOptions.SectionName).Bind(options);
        return new CredentialManagerSecretProvider(Options.Create(options));
    }
}
