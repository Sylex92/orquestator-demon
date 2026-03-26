using System.Text.RegularExpressions;
using DaemonPlatform.Contracts.Abstractions;

namespace DaemonPlatform.Core.Configuration;

public sealed partial class ConnectionStringTemplateResolver(ISecretProvider secretProvider) : IConnectionStringResolver
{
    [GeneratedRegex(@"\{secret:(?<logicalName>[^}]+)\}", RegexOptions.IgnoreCase | RegexOptions.Compiled)]
    private static partial Regex SecretTokenRegex();

    public async Task<string> ResolveRequiredAsync(string template, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(template))
        {
            throw new InvalidOperationException("La cadena de conexión no puede estar vacía.");
        }

        var matches = SecretTokenRegex().Matches(template);
        if (matches.Count == 0)
        {
            return template;
        }

        var resolved = template;
        foreach (Match match in matches)
        {
            var logicalName = match.Groups["logicalName"].Value;
            var secret = await secretProvider.GetSecretAsync(logicalName, cancellationToken);
            resolved = resolved.Replace(match.Value, secret, StringComparison.OrdinalIgnoreCase);
        }

        return resolved;
    }
}
