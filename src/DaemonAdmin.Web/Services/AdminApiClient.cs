using System.Net.Http.Json;
using DaemonPlatform.Contracts.Models;

namespace DaemonAdmin.Web.Services;

public sealed class AdminApiClient(HttpClient httpClient) : IAdminApiClient
{
    public async Task<SystemStatusResponse> GetSystemStatusAsync(CancellationToken cancellationToken)
        => await httpClient.GetFromJsonAsync<SystemStatusResponse>("api/system/status", cancellationToken)
           ?? throw new InvalidOperationException("La API no devolvió estado del sistema.");

    public async Task<IReadOnlyList<JobSummaryResponse>> GetJobsAsync(CancellationToken cancellationToken)
        => await httpClient.GetFromJsonAsync<IReadOnlyList<JobSummaryResponse>>("api/jobs", cancellationToken)
           ?? Array.Empty<JobSummaryResponse>();

    public Task<JobDetailsResponse?> GetJobAsync(string jobGroup, string jobName, CancellationToken cancellationToken)
        => httpClient.GetFromJsonAsync<JobDetailsResponse>($"api/jobs/{jobGroup}/{jobName}", cancellationToken);

    public Task<OperationResponse> RunNowAsync(string jobGroup, string jobName, CancellationToken cancellationToken)
        => PostAsync($"api/jobs/{jobGroup}/{jobName}/run-now", cancellationToken);

    public Task<OperationResponse> PauseAsync(string jobGroup, string jobName, CancellationToken cancellationToken)
        => PostAsync($"api/jobs/{jobGroup}/{jobName}/pause", cancellationToken);

    public Task<OperationResponse> ResumeAsync(string jobGroup, string jobName, CancellationToken cancellationToken)
        => PostAsync($"api/jobs/{jobGroup}/{jobName}/resume", cancellationToken);

    private async Task<OperationResponse> PostAsync(string uri, CancellationToken cancellationToken)
    {
        using var response = await httpClient.PostAsync(uri, content: null, cancellationToken);
        var payload = await response.Content.ReadFromJsonAsync<OperationResponse>(cancellationToken: cancellationToken);
        return payload ?? new OperationResponse(response.IsSuccessStatusCode, response.ReasonPhrase ?? "Operación ejecutada.");
    }
}
