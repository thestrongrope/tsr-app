using System.Globalization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ReportWeekly;

// Slice: GET /reports/weekly?gender&from&to&level (months MM-YYYY, default this month) -> every class the caller reaches and, for each week of the months, held (how many times), not held or not filled.
// PHP: routes/reports.php route_reports_weekly (:291, api_require_weekly_report :245). The query and its rules are domain/WeeklyReport.cs (shared with the download).

internal static class ReportWeeklySlice
{
    internal sealed record WeekItem(string Month, string Label, string From, string To);

    internal sealed record Answer(
        int Gender, string From, string To, IReadOnlyList<string> Levels, IReadOnlyList<WeekItem> Weeks, IReadOnlyList<WeeklyReport.ClassItem> Classes);

    public static IEndpointRouteBuilder MapReportWeekly(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/reports/weekly", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, ClassesContext db, Permissions permissions, TimeProvider clock, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var today = DateOnly.FromDateTime(clock.GetUtcNow().UtcDateTime);
        var (report, refusal) = await WeeklyReport.OpenAsync(context, db, permissions, caller, today, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        return Results.Json(new Answer(report!.Gender, report.From, report.To, report.Levels, WeekItems(report.Months), report.Classes));
    }

    private static List<WeekItem> WeekItems(IReadOnlyList<WeeklyGrid.Month> months) =>
    [
        .. months.SelectMany(m => m.Weeks.Select((days, i) =>
            new WeekItem(m.Label, "Wk " + (i + 1).ToString(CultureInfo.InvariantCulture), Day(days[0]), Day(days[^1])))),
    ];

    private static string Day(DateOnly day) => day.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
}
