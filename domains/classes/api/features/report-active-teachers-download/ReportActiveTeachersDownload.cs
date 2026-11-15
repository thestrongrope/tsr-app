using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Platform.Api;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ReportActiveTeachersDownload;

// Slice: GET /reports/active-teachers/download?format=xlsx|pdf&gender -> the active teachers report as a file, one row per teacher. Contract: spec/api.yaml.
// PHP: routes/reports.php route_reports_active_teachers_download (:1558). Order as PHP: format (422, before the sign-in), sign-in, reports:read, then the same rows as the screen (domain/ActiveTeachers.cs). No 404: an empty report is a file with no rows.
// Title "Active teachers: Gents|Ladies", file "Active-teachers-Gents|Ladies.<format>". Writes nothing.

internal static class ReportActiveTeachersDownloadSlice
{
    private static readonly string[] Headers = ["Token", "Name", "Attending Class", "Self Teacher", "Max Level Conducted", "Total Classes", "Conducting Class"];

    public static IEndpointRouteBuilder MapReportActiveTeachersDownload(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/reports/active-teachers/download", HandleAsync).RequireMember(createsMember: true, precheck: ReportExport.FormatRefusal);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, ClassesContext db, Permissions permissions, ReportExport export, CancellationToken ct)
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

        var (scope, refusal) = await ReportScope.OpenAsync(context, permissions, caller, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var teachers = await ActiveTeachers.LoadAsync(db, scope!, ct);
        var gender = scope!.Gender == 2 ? "Ladies" : "Gents";
        IReadOnlyList<IReadOnlyList<object?>> rows =
        [
            .. teachers.Select(t => (IReadOnlyList<object?>)[t.Token, t.Name, t.AttendingClass, t.SelfTeacher, t.MaxLevel, t.TotalClasses, t.ConductingClasses]),
        ];
        return await export.DownloadAsync(format, "Active teachers: " + gender, [new ReportSection(gender, Headers, rows)], "Active-teachers-" + gender, ct);
    }
}
