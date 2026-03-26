namespace DaemonPlatform.Contracts.Abstractions;

public interface ISecretProvider
{
    ValueTask<string> GetSecretAsync(string logicalName, CancellationToken cancellationToken = default);
}
