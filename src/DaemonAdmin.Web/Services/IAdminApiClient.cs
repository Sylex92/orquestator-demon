using DaemonPlatform.Contracts.Models;

namespace DaemonAdmin.Web.Services;

public interface IAdminApiClient
{
    Task<SystemStatusResponse> GetSystemStatusAsync(CancellationToken cancellationToken);

    Task<IReadOnlyList<JobSummaryResponse>> GetJobsAsync(CancellationToken cancellationToken);

    Task<JobDetailsResponse?> GetJobAsync(string jobGroup, string jobName, CancellationToken cancellationToken);

    Task<OperationResponse> RunNowAsync(string jobGroup, string jobName, CancellationToken cancellationToken);

    Task<OperationResponse> PauseAsync(string jobGroup, string jobName, CancellationToken cancellationToken);

    Task<OperationResponse> ResumeAsync(string jobGroup, string jobName, CancellationToken cancellationToken);
}
