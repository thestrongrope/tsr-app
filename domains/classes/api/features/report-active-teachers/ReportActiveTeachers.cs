using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ReportActiveTeachers;

// Slice: GET /reports/active-teachers?gender -> {gender, teachers[{token, name, attendingClass, selfTeacher, maxLevel, totalClasses, conductingClasses}]}: each teacher of the active classes the caller reaches, with the classes taught
// and the classes the teacher attends as a student. Contract: spec/api.yaml.
// PHP: routes/reports.php route_reports_active_teachers (:1534, api_require_active_teachers_report :1522). The query and its rules are domain/ActiveTeachers.cs (shared with the download).

internal static class ReportActiveTeachersSlice
{
    internal sealed record Answer(int Gender, IReadOnlyList<ActiveTeachers.Item> Teachers);

    public static IEndpointRouteBuilder MapReportActiveTeachers(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/reports/active-teachers", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, NpgsqlDataSource db, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var (scope, refusal) = await ReportScope.OpenAsync(context, permissions, caller, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        return Results.Json(new Answer(scope!.Gender, await ActiveTeachers.LoadAsync(db, scope, ct)), ClassesJson.Answers.ReportActiveTeachers);
    }
}
