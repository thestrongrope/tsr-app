using System.Globalization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ReportClassSessionHistory;

// Slice: GET /reports/class-sessions/{class_id} -> the class's sessions, newest day first. A class that is missing, closed or out of the caller's reach answers 200 with no sessions (PHP does not say which classes exist).
// PHP: routes/reports.php route_reports_class_session_history (:1222, api_require_class_sessions_history :1174), mis.php getClassSessionHistory. Guard: reports:read with no target (any scope passes). Queries: the class's gender,
// the scope's ids (that class only), the sessions.
// Copied: the reach is asked for the class's OWN gender (a gender administrator reaches only their gender's classes, a coordinator the assigned ones); the quran text is "surah" and ":verse" only when the verse is not empty
// (so a verse of 0 shows as ":0", a missing surah as ""); a topic that is missing is "". Deviation: at most 5000 sessions (PHP has no bound).

internal static class ReportClassSessionHistorySlice
{
    private const int MaxSessions = 5000;

    internal sealed record Item(string Date, bool Held, string? Reason, string Quran, string Arabic, string Aqaed, string Ahkam, string Akhlaq, string Other);

    internal sealed record Answer(IReadOnlyList<Item> Sessions);

    private sealed record Row(DateOnly ConductedOn, short Conducted, string? Reason, int? Surah, int? Verse, string? Arabic, string? Aqaed, string? Ahkam, string? Akhlaq, string? Other);

    public static IEndpointRouteBuilder MapReportClassSessionHistory(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/reports/class-sessions/{class_id}", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string class_id, HttpContext context, ClassesContext db, Permissions permissions, CancellationToken ct)
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

        var classId = ClassGuards.IdOf(class_id);
        var genders = await db.Database
            .SqlQuery<int>($"""select coalesce(gender, 0) as "Value" from classes.classes where id = {classId} limit 1""")
            .ToListAsync(ct);
        if (genders.Count == 0)
        {
            return Results.Json(new Answer([]));
        }

        var reach = await permissions.ReachAsync(caller, "reports:read", ct);
        var reachable = await ReportScope.Of(reach, genders[0]).ClassIdsAsync(db, classId, ct);
        if (reachable.Length == 0)
        {
            return Results.Json(new Answer([]));
        }

        var rows = await db.Database
            .SqlQuery<Row>($"""
                select conducted_on as "ConductedOn", conducted as "Conducted", non_conduction_reason::text as "Reason", quran_recitation_surah as "Surah", quran_recitation_verse as "Verse",
                       arabic_topic::text as "Arabic", aqaed_topic::text as "Aqaed", ahkam_topic::text as "Ahkam", akhlaq_topic::text as "Akhlaq", other_topic::text as "Other"
                from classes.class_sessions
                where class_id = {classId}
                order by conducted_on desc, id desc
                limit {MaxSessions}
                """)
            .ToListAsync(ct);
        return Results.Json(new Answer([.. rows.Select(ToItem)]));
    }

    private static Item ToItem(Row row)
    {
        var quran = row.Surah?.ToString(CultureInfo.InvariantCulture) ?? string.Empty;
        if (quran.Length > 0 && row.Verse is not null)
        {
            quran += ":" + row.Verse.Value.ToString(CultureInfo.InvariantCulture);
        }

        return new Item(
            row.ConductedOn.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture), row.Conducted == 1, PhpCast.StrOrNull(row.Reason), quran,
            PhpCast.Str(row.Arabic), PhpCast.Str(row.Aqaed), PhpCast.Str(row.Ahkam), PhpCast.Str(row.Akhlaq), PhpCast.Str(row.Other));
    }
}
