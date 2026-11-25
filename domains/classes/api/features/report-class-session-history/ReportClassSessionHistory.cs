using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ReportClassSessionHistory;

// Slice: GET /reports/class-sessions/{class_id} -> the class's sessions, newest day first. A class that is missing, closed or out of the caller's reach answers 200 with no sessions (PHP does not say which classes exist).
// PHP: routes/reports.php route_reports_class_session_history (:1222, api_require_class_sessions_history :1174). Guard: reports:read with no target. The query and its rules are domain/ClassSessionHistory.cs (shared with the download).

internal static class ReportClassSessionHistorySlice
{
    internal sealed record Answer(IReadOnlyList<ClassSessionHistory.Item> Sessions);

    public static IEndpointRouteBuilder MapReportClassSessionHistory(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/reports/class-sessions/{class_id}", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string class_id, HttpContext context, NpgsqlDataSource db, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await permissions.CanAsync(caller, "reports:read", AccessTarget.None, ct))
        {
            return Refusals.NotPermitted();
        }

        return Results.Json(new Answer(await ClassSessionHistory.LoadAsync(db, permissions, caller, ClassGuards.IdOf(class_id), ct)), ClassesJson.Answers.ReportClassSessionHistory);
    }
}
