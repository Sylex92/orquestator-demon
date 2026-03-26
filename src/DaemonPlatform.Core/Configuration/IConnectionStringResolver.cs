namespace DaemonPlatform.Core.Configuration;

public interface IConnectionStringResolver
{
    Task<string> ResolveRequiredAsync(string template, CancellationToken cancellationToken = default);
}
