using DaemonPlatform.Contracts.Configuration;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace DaemonPlatform.Quartz;

public sealed class QuartzStorageHealthCheck(ResolvedConnectionStrings connectionStrings) : IHealthCheck
{
    public async Task<HealthCheckResult> CheckHealthAsync(HealthCheckContext context, CancellationToken cancellationToken = default)
    {
        try
        {
            await using var connection = new SqlConnection(connectionStrings.Quartz);
            await connection.OpenAsync(cancellationToken);
            await using var command = new SqlCommand("SELECT 1;", connection);
            await command.ExecuteScalarAsync(cancellationToken);
            return HealthCheckResult.Healthy("Conectividad con SQL de Quartz OK.");
        }
        catch (Exception ex)
        {
            return HealthCheckResult.Unhealthy("No se pudo conectar al SQL compartido de Quartz.", ex);
        }
    }
}
