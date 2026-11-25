using System.Globalization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ReportConduction;

// Slice: GET /reports/conduction?gender&year&week&level -> the week's conduction of every class the caller reaches and the figures over the weeks around it. Contract: spec/api.yaml.
// PHP: routes/reports.php route_reports_conduction (:100, api_require_conduction_report :66), models/mis.php conductionReport. Queries: the class ids of the scope, then one for the rows. The rows and their narrowing to a level
// are domain/ConductionReport.cs (shared with the download).
// Quirks copied: a class that held two sessions in a week has two week rows (and counts twice); weekOf is the dates of the last row of the week; "level" narrows by exact name after the figures.

internal static class ReportConductionSlice
{
    internal sealed record WeekRef(int Year, int Week);

    internal sealed record ClassItem(
        string Level, string Gender, string Class, string? Teacher, int Expected, int Conducted, int NotFilled, int NotConducted, int Students, int Attendance,
        int PercentNotFilled, int PercentConduction, int PercentAttendance);

    internal sealed record WeekItem(
        int ClassId, string Level, string Class, string? Teacher, string Status, string? ConductedOn, string? Reason, int? Duration, int? Attendance, int Registered, int Extra);

    internal sealed record Answer(
        int Gender, int Year, int Week, WeekRef? Previous, WeekRef? Next, string WeekOf, string SummaryStart, string SummaryEnd,
        IReadOnlyList<string> Levels, IReadOnlyList<ClassItem> Classes, IReadOnlyList<WeekItem> LastWeek);

    public static IEndpointRouteBuilder MapReportConduction(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/reports/conduction", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, NpgsqlDataSource db, Permissions permissions, TimeProvider clock, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var today = DateOnly.FromDateTime(clock.GetUtcNow().UtcDateTime);
        var (report, refusal) = await ConductionReport.OpenAsync(context, db, permissions, caller, today, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var shaped = ConductionReport.Shape(report!, ReportScope.LevelOf(context));
        var (previous, next) = ReportCalendar.Neighbours(report!.Year, report.Week, today);

        return Results.Json(new Answer(
            report.Gender, report.Year, report.Week, Ref(previous), Ref(next), shaped.WeekOf, shaped.SummaryStart, shaped.SummaryEnd,
            shaped.Levels, [.. shaped.Classes.Select(ToItem)], [.. shaped.LastWeek.Select(ToWeek)]), ClassesJson.Answers.ReportConduction);
    }

    private static WeekRef? Ref(ReportCalendar.Week? week) => week is { } w ? new WeekRef(w.Year, w.Number) : null;

    private static ClassItem ToItem(ConductionReport.ClassFigures f) =>
        new(f.Level, f.Gender, f.Class, PhpCast.StrOrNull(f.Teacher), f.Expected, f.Conducted, f.NotFilled, f.NotConducted, f.Students, f.Attendance, f.PercentNotFilled, f.PercentConduction, f.PercentAttendance);

    private static WeekItem ToWeek(ConductionReport.Row r) =>
        new(r.Id, r.Level, r.Class, PhpCast.StrOrNull(r.Teacher), r.Conducted, r.ConductedOn?.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture), PhpCast.StrOrNull(r.Reason), r.Duration, r.Attendance, r.Registered ?? 0, r.Extra ?? 0);
}
