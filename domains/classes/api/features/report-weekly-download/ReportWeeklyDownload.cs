using System.Globalization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Platform.Api;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ReportWeeklyDownload;

// Slice: GET /reports/weekly/download?format=xlsx|pdf&gender&from&to&level -> the whole range in one table, a row per class (Class, Level, Teacher) and a column per week with the screen's words (Held, Held (n), Not held, Not filled). Contract: spec/api.yaml.
// PHP: routes/reports.php route_reports_weekly_download (:324). Order as PHP: format (422, before the sign-in), sign-in, reports:read, months (422), then the same classes as the screen (domain/WeeklyReport.cs). No 404: no class is a file with headers only.
// Title "Weekly report: Gents|Ladies, <from>[ to <to>]", file "Weekly-Gents|Ladies-<from>[-to-<to>].<format>" (the months are validated MM-YYYY). Writes nothing.

internal static class ReportWeeklyDownloadSlice
{
    public static IEndpointRouteBuilder MapReportWeeklyDownload(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/reports/weekly/download", HandleAsync).RequireMember(createsMember: true, precheck: ReportExport.FormatRefusal);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, NpgsqlDataSource db, Permissions permissions, ReportExport export, TimeProvider clock, CancellationToken ct)
    {
        if (!ReportExport.TryGetFormat(context, out var format))
        {
            return ReportExport.FormatRefusal(context)!;
        }

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

        var gender = report!.Gender == 2 ? "Ladies" : "Gents";
        var sameMonth = report.From == report.To;
        var period = sameMonth ? report.From : report.From + " to " + report.To;
        string[] headers = ["Class", "Level", "Teacher", .. report.Months.SelectMany(m => m.Weeks.Select((_, i) => m.Label + " Wk " + (i + 1).ToString(CultureInfo.InvariantCulture)))];
        IReadOnlyList<IReadOnlyList<object?>> rows = [.. report.Classes.Select(Row)];
        var filename = "Weekly-" + gender + "-" + report.From + (sameMonth ? string.Empty : "-to-" + report.To);
        return await export.DownloadAsync(format, $"Weekly report: {gender}, {period}", [new ReportSection(period, headers, rows)], filename, ct);
    }

    private static IReadOnlyList<object?> Row(WeeklyReport.ClassItem c) =>
        [c.Class, c.Level, c.Teacher, .. c.Weeks.Select(Word)];

    private static string Word(WeeklyReport.CellItem week) => week.Status switch
    {
        "held" when week.Sessions > 1 => "Held (" + week.Sessions.ToString(CultureInfo.InvariantCulture) + ")",
        "held" => "Held",
        "notHeld" => "Not held",
        _ => "Not filled",
    };
}
