using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ReportMcqAdherence;

// Slice: GET /reports/mcq-adherence?gender -> {gender, levels[], classes[{classId, class, level, teacher, expected, conducted, pending, skipped, adherencePercent}]}: a line per class with standard MCQs, worst adherence first. Contract: spec/api.yaml.
// PHP: routes/reports.php route_reports_mcq_adherence (:1434, guard :1415). Order as PHP: sign-in, reports:read for the gender (403). No dates. The queries and rules are domain/McqAdherenceReport.cs and McqAdherence.cs (the pending report's MCQ query).
// Copied: `teacher` is null when the class has no teacher name; adherencePercent is a float rounded to one decimal; `levels` lists the levels in the order they appear.

internal static class ReportMcqAdherenceSlice
{
    internal sealed record Line(int ClassId, string Class, string Level, string? Teacher, int Expected, int Conducted, int Pending, int Skipped, PhpFloat AdherencePercent);

    internal sealed record Answer(int Gender, IReadOnlyList<string> Levels, IReadOnlyList<Line> Classes);

    public static IEndpointRouteBuilder MapReportMcqAdherence(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/reports/mcq-adherence", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, ClassesContext db, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var (report, refusal) = await McqAdherenceReport.OpenAsync(context, db, permissions, caller, 0, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var classes = report!.Lines.Select(l => new Line(l.ClassId, l.Class, l.Level, l.Teacher, l.Expected, l.Conducted, l.Pending, l.Skipped, l.AdherencePercent)).ToList();
        return Results.Json(new Answer(report.Gender, [.. classes.Select(c => c.Level).Distinct()], classes));
    }
}
