namespace DaemonPlatform.Contracts.Configuration;

public sealed class PlatformNodeOptions
{
    public const string SectionName = "Platform";

    public string ApplicationName { get; set; } = "DaemonPlatform";

    public string Role { get; set; } = "Unknown";

    public string NodeName { get; set; } = string.Empty;

    public string EnvironmentName { get; set; } = "Production";
}
