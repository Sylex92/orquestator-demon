using System.Diagnostics;
using DaemonAdmin.Web.Models;
using DaemonAdmin.Web.Services;
using Microsoft.AspNetCore.Mvc;

namespace DaemonAdmin.Web.Controllers;

public sealed class HomeController(IAdminApiClient adminApiClient) : Controller
{
    [HttpGet]
    public async Task<IActionResult> Index(CancellationToken cancellationToken)
    {
        var viewModel = new DashboardViewModel(
            await adminApiClient.GetSystemStatusAsync(cancellationToken),
            await adminApiClient.GetJobsAsync(cancellationToken),
            TempData["Feedback"]?.ToString());

        return View(viewModel);
    }

    [HttpGet]
    public async Task<IActionResult> Details(string jobGroup, string jobName, CancellationToken cancellationToken)
    {
        var details = await adminApiClient.GetJobAsync(jobGroup, jobName, cancellationToken);
        return details is null ? NotFound() : View(details);
    }

    [HttpPost]
    public async Task<IActionResult> RunNow(string jobGroup, string jobName, CancellationToken cancellationToken)
    {
        var response = await adminApiClient.RunNowAsync(jobGroup, jobName, cancellationToken);
        TempData["Feedback"] = response.Message;
        return RedirectToAction(nameof(Index));
    }

    [HttpPost]
    public async Task<IActionResult> Pause(string jobGroup, string jobName, CancellationToken cancellationToken)
    {
        var response = await adminApiClient.PauseAsync(jobGroup, jobName, cancellationToken);
        TempData["Feedback"] = response.Message;
        return RedirectToAction(nameof(Index));
    }

    [HttpPost]
    public async Task<IActionResult> Resume(string jobGroup, string jobName, CancellationToken cancellationToken)
    {
        var response = await adminApiClient.ResumeAsync(jobGroup, jobName, cancellationToken);
        TempData["Feedback"] = response.Message;
        return RedirectToAction(nameof(Index));
    }

    [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
    public IActionResult Error()
    {
        return View(new ErrorViewModel { RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier });
    }
}
