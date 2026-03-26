using DaemonPlatform.Contracts.Models;

namespace DaemonAdmin.Web.Models;

public sealed record DashboardViewModel(
    SystemStatusResponse SystemStatus,
    IReadOnlyList<JobSummaryResponse> Jobs,
    string? FeedbackMessage);
