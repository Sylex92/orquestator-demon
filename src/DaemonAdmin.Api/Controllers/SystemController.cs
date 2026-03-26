using DaemonPlatform.Quartz;
using Microsoft.AspNetCore.Mvc;

namespace DaemonAdmin.Api.Controllers;

[ApiController]
[Route("api/system")]
public sealed class SystemController(IJobAdministrationService jobAdministrationService) : ControllerBase
{
    [HttpGet("status")]
    public Task<DaemonPlatform.Contracts.Models.SystemStatusResponse> GetStatus(CancellationToken cancellationToken)
        => jobAdministrationService.GetSystemStatusAsync(cancellationToken);
}
