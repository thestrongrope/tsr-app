using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ReportMcqAdherenceClass;

// Slice: GET /reports/mcq-adherence/{class_id}?gender -> {expected, conducted, pending, skipped, adherencePercent, mcqs[{topic, subject, lesson, name, status conducted|pending|skipped}]}: one class's standard MCQs. Contract: spec/api.yaml.
// PHP: routes/reports.php route_reports_mcq_adherence_class (:1485), api_reports_mcq_adherence_class (:1456). Same guard and gender as the list. A class out of reach or with no standard MCQs answers as a class with none (zeros, no MCQs, no 404). The MCQ code is in PHP's model row but not in the answer.
// QUIRK copied: {class_id} is cast as PHP's (int); 0 or a word means no narrowing, so the answer is the FIRST class of the whole report, the one with the worst adherence (domain/McqAdherenceReport.cs).

internal static class ReportMcqAdherenceClassSlice
{
    internal sealed record Mcq(string Topic, string Subject, string Lesson, string Name, string Status);

    internal sealed record Answer(int Expected, int Conducted, int Pending, int Skipped, PhpFloat AdherencePercent, IReadOnlyList<Mcq> Mcqs);

    public static IEndpointRouteBuilder MapReportMcqAdherenceClass(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/reports/mcq-adherence/{class_id}", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string class_id, HttpContext context, ClassesContext db, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var (report, refusal) = await McqAdherenceReport.OpenAsync(context, db, permissions, caller, ClassGuards.IdOf(class_id), ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var c = await McqAdherenceReport.FirstClassAsync(db, report!, ct);
        var mcqs = c.Items.Select(i => new Mcq(i.Topic, i.Subject, i.Lesson, i.Name, i.Status)).ToList();
        return Results.Json(new Answer(c.Expected, c.Conducted, c.Pending, c.Skipped, c.AdherencePercent, mcqs));
    }
}
