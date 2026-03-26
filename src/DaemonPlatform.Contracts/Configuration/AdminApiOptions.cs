namespace DaemonPlatform.Contracts.Configuration;

public sealed class AdminApiOptions
{
    public const string SectionName = "AdminApi";

    public string BaseUrl { get; set; } = "https://localhost:7041";
}
