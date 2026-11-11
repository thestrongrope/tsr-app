using System.Globalization;
using System.Text;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ReportClassSessionsAll;

// Slice: GET /reports/class-sessions/download-all?gender -> every session of every class the caller reaches, as CSV (level ignored). 404 "No sessions to download" when there are none.
// PHP: routes/reports.php route_reports_class_sessions_download_all (:1206), mis.php getClassSessionsExport and classSessionsCsv. Queries: the class ids of the scope, the sessions. The file name carries the gender and the time (UTC).
// Copied: the quran cell is CONCAT(surah, ":" + verse when the verse is not null): empty when there is no surah, ":0" for a verse of 0; the level and teacher are left-joined (empty when missing);
// order: level order (nulls first), class code, day. Deviation: at most 200000 sessions (PHP has no bound; production holds about 24000).

internal static class ReportClassSessionsAllSlice
{
    private const int MaxSessions = 200000;

    private static readonly string[] Headers =
    [
        "Class Code", "Class Name", "Level", "Teacher", "Date", "Conducted", "Non-Conduction Reason", "Quran", "Arabic", "Aqaed", "Ahkam", "Akhlaq", "Other", "Attendance", "Duration",
    ];

    private sealed record Row(
        string Code, string? Name, string? Level, string? Teacher, DateOnly ConductedOn, short Conducted, string? Reason, int? Surah, int? Verse,
        string? Arabic, string? Aqaed, string? Ahkam, string? Akhlaq, string? Other, int? Attendance, int? Duration);

    public static IEndpointRouteBuilder MapReportClassSessionsAll(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/reports/class-sessions/download-all", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, ClassesContext db, Permissions permissions, TimeProvider clock, CancellationToken ct)
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

        var ids = await scope!.ClassIdsAsync(db, 0, ct);
        var rows = await db.Database
            .SqlQuery<Row>($"""
                select c.code::text as "Code", c.name::text as "Name", cl.name::text as "Level", u.name::text as "Teacher", s.conducted_on as "ConductedOn", s.conducted as "Conducted",
                       s.non_conduction_reason::text as "Reason", s.quran_recitation_surah as "Surah", s.quran_recitation_verse as "Verse",
                       s.arabic_topic::text as "Arabic", s.aqaed_topic::text as "Aqaed", s.ahkam_topic::text as "Ahkam", s.akhlaq_topic::text as "Akhlaq", s.other_topic::text as "Other",
                       s.attendance as "Attendance", s.duration as "Duration"
                from classes.class_sessions s
                join classes.classes c on c.id = s.class_id
                left join classes.class_levels cl on cl.id = c.class_level_id
                left join membership.v_members u on u.token = c.teacher
                where c.id = any({ids})
                order by cl.sort_order nulls first, c.code, s.conducted_on, s.id
                limit {MaxSessions}
                """)
            .ToListAsync(ct);

        var csv = ReportCsv.Build(Headers, [.. rows.Select(ToCells)]);
        if (csv is null)
        {
            return Problem.Detail(StatusCodes.Status404NotFound, "No sessions to download");
        }

        var name = (scope.Gender == 2 ? "Ladies" : "Gents") + "_" + clock.GetUtcNow().UtcDateTime.ToString("yyyyMMdd_HHmmss", CultureInfo.InvariantCulture);
        context.Response.Headers.ContentDisposition = "attachment; filename=\"Class_Sessions_Report_" + name + ".csv\"";
        return Results.Bytes(Encoding.UTF8.GetBytes(csv), "text/csv;charset=UTF-8");
    }

    private static IReadOnlyList<string?> ToCells(Row r)
    {
        var quran = r.Surah is null ? null : r.Surah.Value.ToString(CultureInfo.InvariantCulture) + (r.Verse is null ? string.Empty : ":" + r.Verse.Value.ToString(CultureInfo.InvariantCulture));
        return
        [
            r.Code, r.Name, r.Level, r.Teacher, r.ConductedOn.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture), r.Conducted == 1 ? "Yes" : "No", r.Reason, quran,
            r.Arabic, r.Aqaed, r.Ahkam, r.Akhlaq, r.Other, r.Attendance?.ToString(CultureInfo.InvariantCulture), r.Duration?.ToString(CultureInfo.InvariantCulture),
        ];
    }
}
