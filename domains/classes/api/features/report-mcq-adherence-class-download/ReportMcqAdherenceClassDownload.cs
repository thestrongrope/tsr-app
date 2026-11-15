using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Platform.Api;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ReportMcqAdherenceClassDownload;

// Slice: GET /reports/mcq-adherence/{class_id}/download?format=xlsx|pdf&gender -> the class's standard MCQs in the screen's order with their status (Topic, Subject, Lesson, Name, Status). Contract: spec/api.yaml.
// PHP: routes/reports.php route_reports_mcq_adherence_class_download (:1495). Order as PHP: format (422, before the sign-in), sign-in, reports:read, then the same class as the class route (domain/McqAdherenceReport.cs, including the {class_id} 0 quirk). No 404.
// Title "MCQ adherence", heading "<conducted> of <expected> conducted (<percent>%), <pending> pending, <skipped> skipped", status as a word (Conducted, Pending, Skipped), file "MCQ-adherence-<class_id>.<format>" (the id as written in the path, cut to safe characters). Writes nothing.

internal static class ReportMcqAdherenceClassDownloadSlice
{
    private static readonly string[] Headers = ["Topic", "Subject", "Lesson", "Name", "Status"];

    public static IEndpointRouteBuilder MapReportMcqAdherenceClassDownload(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/reports/mcq-adherence/{class_id}/download", HandleAsync).RequireMember(createsMember: true, precheck: ReportExport.FormatRefusal);
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

        var (report, refusal) = await McqAdherenceReport.OpenAsync(context, db, permissions, caller, ClassGuards.IdOf(class_id), ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var c = await McqAdherenceReport.FirstClassAsync(db, report!, ct);
        IReadOnlyList<IReadOnlyList<object?>> rows = [.. c.Items.Select(i => (IReadOnlyList<object?>)[i.Topic, i.Subject, i.Lesson, i.Name, Word(i.Status)])];
        var heading = $"{c.Conducted} of {c.Expected} conducted ({McqAdherenceReport.Text(c.AdherencePercent)}%), {c.Pending} pending, {c.Skipped} skipped";
        return await export.DownloadAsync(format, "MCQ adherence", [new ReportSection(heading, Headers, rows)], "MCQ-adherence-" + class_id, ct);
    }

    private static string Word(string status) => status switch
    {
        "conducted" => "Conducted",
        "pending" => "Pending",
        _ => "Skipped",
    };
}
