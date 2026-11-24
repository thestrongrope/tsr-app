using System.Globalization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ReportClassSessions;

// Slice: GET /reports/class-sessions?gender&level -> every active class the caller reaches with how many sessions it has recorded and what the last one covered. Contract: spec/api.yaml.
// PHP: routes/reports.php route_reports_class_sessions (:1141, api_require_class_sessions_report :1123), mis.php getClassSessionsReport (:2140). Queries: the class ids of the scope, one for the classes with their
// count and last session (PHP loads every session of every class, twice, and counts in PHP).
// Copied: classes whose level or teacher row is missing are still listed (left joins; the level then reads ""), "last" is the session with the latest day (the later id on a tie), the quran text is "surah" and ":verse"
// only when the verse is not 0 (unlike the history route), a class with no session has null for every "last" field, "levels" are read before "level" narrows the list.
// MariaDB to PostgreSQL: a NULL level order sorts first (nulls first).

internal static class ReportClassSessionsSlice
{
    internal sealed record Item(
        int ClassId, string Class, string Level, string? Teacher, int TotalSessions, string? LastDate, string? LastQuran, string? LastArabic, string? LastAqaed, string? LastAhkam, string? LastAkhlaq, string? LastOther);

    internal sealed record Answer(int Gender, IReadOnlyList<string> Levels, IReadOnlyList<Item> Classes);

    private sealed record Row(
        int Id, string Code, string? Level, string? Teacher, int Total, DateOnly? LastOn, int? Surah, int? Verse, string? Arabic, string? Aqaed, string? Ahkam, string? Akhlaq, string? Other);

    public static IEndpointRouteBuilder MapReportClassSessions(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/reports/class-sessions", HandleAsync).RequireMember(createsMember: true);
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

        var ids = await scope!.ClassIdsAsync(db, 0, ct);
        var rows = await db.ListAsync(
            $"""
                select c.id as "Id", c.code::text as "Code", cl.name::text as "Level", u.name::text as "Teacher",
                       (select count(1) from classes.class_sessions s where s.class_id = c.id)::int as "Total",
                       to_char(last.conducted_on, 'YYYY-MM-DD') as "LastOn", last.quran_recitation_surah as "Surah", last.quran_recitation_verse as "Verse",
                       last.arabic_topic::text as "Arabic", last.aqaed_topic::text as "Aqaed", last.ahkam_topic::text as "Ahkam", last.akhlaq_topic::text as "Akhlaq", last.other_topic::text as "Other"
                from classes.classes c
                left join classes.class_levels cl on cl.id = c.class_level_id
                left join membership.v_members u on u.token = c.teacher
                left join lateral (
                    select s.conducted_on, s.quran_recitation_surah, s.quran_recitation_verse, s.arabic_topic, s.aqaed_topic, s.ahkam_topic, s.akhlaq_topic, s.other_topic
                    from classes.class_sessions s where s.class_id = c.id order by s.conducted_on desc, s.id desc limit 1) last on true
                where c.id = any({ids})
                order by cl.sort_order nulls first, c.code
                """,
            r => new Row(
                r.Int("Id"), r.Text("Code"), r.TextOrNull("Level"), r.TextOrNull("Teacher"), r.Int("Total"), r.DayOrNull("LastOn"), r.IntOrNull("Surah"), r.IntOrNull("Verse"),
                r.TextOrNull("Arabic"), r.TextOrNull("Aqaed"), r.TextOrNull("Ahkam"), r.TextOrNull("Akhlaq"), r.TextOrNull("Other")),
            ct);

        var level = ReportScope.LevelOf(context);
        var items = rows.Where(r => level.Length == 0 || PhpCast.Str(r.Level) == level).Select(ToItem).ToList();
        return Results.Json(new Answer(scope.Gender, [.. rows.Select(r => PhpCast.Str(r.Level)).Distinct()], items), ClassesJson.Answers.ReportClassSessions);
    }

    private static Item ToItem(Row row)
    {
        var quran = row.LastOn is null ? null : (row.Surah?.ToString(CultureInfo.InvariantCulture) ?? string.Empty) + (row.Verse is null or 0 ? string.Empty : ":" + row.Verse.Value.ToString(CultureInfo.InvariantCulture));
        return new Item(
            row.Id, row.Code, PhpCast.Str(row.Level), PhpCast.StrOrNull(row.Teacher), row.Total, row.LastOn?.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture),
            PhpCast.StrOrNull(quran), PhpCast.StrOrNull(row.Arabic), PhpCast.StrOrNull(row.Aqaed), PhpCast.StrOrNull(row.Ahkam), PhpCast.StrOrNull(row.Akhlaq), PhpCast.StrOrNull(row.Other));
    }
}
