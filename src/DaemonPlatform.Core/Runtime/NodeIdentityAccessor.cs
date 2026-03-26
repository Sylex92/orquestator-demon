using DaemonPlatform.Contracts.Configuration;
using Microsoft.Extensions.Options;

namespace DaemonPlatform.Core.Runtime;

public sealed class NodeIdentityAccessor(IOptions<PlatformNodeOptions> options) : INodeIdentityAccessor
{
    public string GetCurrentNodeName()
    {
        var configured = options.Value.NodeName?.Trim();
        return string.IsNullOrWhiteSpace(configured) ? Environment.MachineName : configured;
    }
}
