using DaemonPlatform.Contracts.Models;

namespace DaemonPlatform.Quartz;

public interface IJobAdministrationService
{
    Task<IReadOnlyList<JobSummaryResponse>> GetJobsAsync(CancellationToken cancellationToken);

    Task<JobDetailsResponse?> GetJobAsync(string jobGroup, string jobName, CancellationToken cancellationToken);

    Task<OperationResponse> RunNowAsync(string jobGroup, string jobName, CancellationToken cancellationToken);

    Task<OperationResponse> PauseAsync(string jobGroup, string jobName, CancellationToken cancellationToken);

    Task<OperationResponse> ResumeAsync(string jobGroup, string jobName, CancellationToken cancellationToken);

    Task<IReadOnlyList<JobExecutionHistoryItemResponse>> GetHistoryAsync(string jobGroup, string jobName, int take, CancellationToken cancellationToken);

    Task<SystemStatusResponse> GetSystemStatusAsync(CancellationToken cancellationToken);
}
