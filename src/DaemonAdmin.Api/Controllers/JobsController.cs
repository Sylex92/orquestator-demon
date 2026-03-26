using DaemonPlatform.Quartz;
using Microsoft.AspNetCore.Mvc;

namespace DaemonAdmin.Api.Controllers;

[ApiController]
[Route("api/jobs")]
public sealed class JobsController(IJobAdministrationService jobAdministrationService) : ControllerBase
{
    [HttpGet]
    public Task<IReadOnlyList<DaemonPlatform.Contracts.Models.JobSummaryResponse>> GetJobs(CancellationToken cancellationToken)
        => jobAdministrationService.GetJobsAsync(cancellationToken);

    [HttpGet("{jobGroup}/{jobName}")]
    public async Task<IActionResult> GetJob(string jobGroup, string jobName, CancellationToken cancellationToken)
    {
        var job = await jobAdministrationService.GetJobAsync(jobGroup, jobName, cancellationToken);
        return job is null ? NotFound() : Ok(job);
    }

    [HttpGet("{jobGroup}/{jobName}/history")]
    public Task<IReadOnlyList<DaemonPlatform.Contracts.Models.JobExecutionHistoryItemResponse>> GetHistory(
        string jobGroup,
        string jobName,
        [FromQuery] int take = 20,
        CancellationToken cancellationToken = default)
        => jobAdministrationService.GetHistoryAsync(jobGroup, jobName, take, cancellationToken);

    [HttpPost("{jobGroup}/{jobName}/run-now")]
    public async Task<IActionResult> RunNow(string jobGroup, string jobName, CancellationToken cancellationToken)
    {
        var response = await jobAdministrationService.RunNowAsync(jobGroup, jobName, cancellationToken);
        return response.Success ? Ok(response) : NotFound(response);
    }

    [HttpPost("{jobGroup}/{jobName}/pause")]
    public async Task<IActionResult> Pause(string jobGroup, string jobName, CancellationToken cancellationToken)
    {
        var response = await jobAdministrationService.PauseAsync(jobGroup, jobName, cancellationToken);
        return response.Success ? Ok(response) : NotFound(response);
    }

    [HttpPost("{jobGroup}/{jobName}/resume")]
    public async Task<IActionResult> Resume(string jobGroup, string jobName, CancellationToken cancellationToken)
    {
        var response = await jobAdministrationService.ResumeAsync(jobGroup, jobName, cancellationToken);
        return response.Success ? Ok(response) : NotFound(response);
    }
}
