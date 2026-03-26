namespace DaemonPlatform.Contracts.Configuration;

public sealed class FileLoggingOptions
{
    public const string SectionName = "Logging:File";

    public bool Enabled { get; set; }

    public string Path { get; set; } = "logs/platform.log.jsonl";
}
