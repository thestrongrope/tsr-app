using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Platform.Api;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ReportClassSessionHistoryDownload;

// Slice: GET /reports/class-sessions/{class_id}/download?format=xlsx|pdf -> the class's session history as a file, oldest session first, numbered. Contract: spec/api.yaml.
// PHP: routes/reports.php route_reports_class_session_history_download (:1235). Order as PHP: format (422, before the sign-in), sign-in, reports:read (no target), then the same sessions as the screen (domain/ClassSessionHistory.cs):
// a class that is missing or out of reach is a file with headers only (no 404, PHP does not say which classes exist). Title "Class sessions", file "Class-sessions-<class_id>.<format>" with the id as written in the path, cut to safe characters. Writes nothing.

internal static class ReportClassSessionHistoryDownloadSlice
{
    private static readonly string[] Headers = ["#", "Date", "Held", "Quran", "Arabic", "Aqaed", "Ahkam", "Akhlaq", "Other"];

    public static IEndpointRouteBuilder MapReportClassSessionHistoryDownload(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/reports/class-sessions/{class_id}/download", HandleAsync).RequireMember(createsMember: true, precheck: ReportExport.FormatRefusal);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string class_id, HttpContext context, ClassesContext db, Permissions permissions, ReportExport export, CancellationToken ct)
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

        if (!await permissions.CanAsync(caller, "reports:read", AccessTarget.None, ct))
        {
            return Refusals.NotPermitted();
        }

        var newestFirst = await ClassSessionHistory.LoadAsync(db, permissions, caller, ClassGuards.IdOf(class_id), ct);
        IReadOnlyList<IReadOnlyList<object?>> rows =
        [
            .. newestFirst.Reverse().Select((s, i) => (IReadOnlyList<object?>)[i + 1, s.Date, s.Held ? "Yes" : "No", s.Quran, s.Arabic, s.Aqaed, s.Ahkam, s.Akhlaq, s.Other]),
        ];
        return await export.DownloadAsync(format, "Class sessions", [new ReportSection("Sessions recorded for the class", Headers, rows)], "Class-sessions-" + class_id, ct);
    }
}
