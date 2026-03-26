namespace DaemonPlatform.Contracts.Configuration;

public sealed class SecretCatalogOptions
{
    public const string SectionName = "Secrets";

    public Dictionary<string, string> LogicalToCredentialTarget { get; set; } = new(StringComparer.OrdinalIgnoreCase);
}
