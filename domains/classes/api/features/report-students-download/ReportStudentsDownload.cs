using System.Globalization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Platform.Api;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ReportStudentsDownload;

// Slice: GET /reports/students/download?format=xlsx|pdf&gender&from&to&level&class -> the screen's students narrowed to the level and class named (exact text, trimmed), best TSR score first, then name (lower-case ASCII), then token. Contract: spec/api.yaml.
// PHP: routes/reports.php route_reports_students_download (:694). Order as PHP: format (422, before the sign-in), sign-in, reports:read, dates (422), then the same students as the screen (domain/StudentsReport.cs): the file holds email-free
// figures only (token, name, class, scores). No 404: no student is a file with headers only. The token is text in the file (PHP's api_cast makes it a string). Title "Student performance: Gents|Ladies, <from> to <to>", file "Students-Gents|Ladies-<from>-to-<to>.<format>". Writes nothing.

internal static class ReportStudentsDownloadSlice
{
    private static readonly string[] Headers =
    [
        "Token", "Name", "Level", "Class", "Sessions", "Attendance %", "MCQs", "MCQs attempted %", "MCQ performance %", "Recitation", "Recitation per session", "TSR score %",
    ];

    public static IEndpointRouteBuilder MapReportStudentsDownload(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/reports/students/download", HandleAsync).RequireMember(createsMember: true, precheck: ReportExport.FormatRefusal);
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
        var (report, refusal) = await StudentsReport.OpenAsync(context, db, permissions, caller, today, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var level = ReportScope.LevelOf(context);
        var className = Last(context, "class");
        IReadOnlyList<IReadOnlyList<object?>> rows =
        [
            .. report!.Students
                .Where(s => (level.Length == 0 || s.Level == level) && (className.Length == 0 || s.Class == className))
                .OrderByDescending(s => s.TsrScore)
                .ThenBy(s => PhpText.LowerAscii(s.Name), StringComparer.Ordinal)
                .ThenBy(s => long.Parse(s.Token, CultureInfo.InvariantCulture))
                .Select(s => (IReadOnlyList<object?>)[s.Token, s.Name, s.Level, s.Class, s.Sessions, s.Attendance, s.TotalMcqs, s.McqAttempted, s.McqPerformance, s.Recitation, s.RecitationAvg.Value, s.TsrScore]),
        ];
        var gender = report.Gender == 2 ? "Ladies" : "Gents";
        var period = report.From + " to " + report.To;
        return await export.DownloadAsync(format, $"Student performance: {gender}, {period}", [new ReportSection(period, Headers, rows)], $"Students-{gender}-{report.From}-to-{report.To}", ct);
    }

    /// <summary>PHP <c>trim((string) ($_GET[name] ?? ''))</c>: the last value given, trimmed.</summary>
    private static string Last(HttpContext context, string name)
    {
        var values = context.Request.Query[name];
        return values.Count == 0 ? string.Empty : PhpText.Trim(values[^1] ?? string.Empty);
    }
}
