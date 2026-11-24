using System.Globalization;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

/// <summary>
/// One class's sessions, newest day first, for the screen (GET /reports/class-sessions/{class_id}) and the download (its /download). PHP: mis.php getClassSessionHistory. Guard: reports:read with no target (any scope passes), checked by the caller.
/// A class that is missing, closed or out of the caller's reach gives no sessions (PHP does not say which classes exist). Queries: the class's gender, the scope's ids (that class only), the sessions.
/// Copied: the reach is asked for the class's OWN gender (a gender administrator reaches only their gender's classes, a coordinator the assigned ones); the quran text is "surah" and ":verse" only when the verse is not empty
/// (so a verse of 0 shows as ":0", a missing surah as ""); a topic that is missing is "". Deviation: at most 5000 sessions (PHP has no bound).
/// </summary>
internal static class ClassSessionHistory
{
    private const int MaxSessions = 5000;

    internal sealed record Item(string Date, bool Held, string? Reason, string Quran, string Arabic, string Aqaed, string Ahkam, string Akhlaq, string Other);

    private sealed record Row(DateOnly ConductedOn, short Conducted, string? Reason, int? Surah, int? Verse, string? Arabic, string? Aqaed, string? Ahkam, string? Akhlaq, string? Other);

    public static async Task<IReadOnlyList<Item>> LoadAsync(NpgsqlDataSource db, Permissions permissions, Caller caller, long classId, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(db);
        ArgumentNullException.ThrowIfNull(permissions);
        ArgumentNullException.ThrowIfNull(caller);
        var genders = await db.ListAsync($"""select coalesce(gender, 0) as "Gender" from classes.classes where id = {classId} limit 1""", r => r.Int("Gender"), ct);
        if (genders.Count == 0)
        {
            return [];
        }

        var reach = await permissions.ReachAsync(caller, "reports:read", ct);
        var reachable = await ReportScope.Of(reach, genders[0]).ClassIdsAsync(db, classId, ct);
        if (reachable.Length == 0)
        {
            return [];
        }

        var rows = await db.ListAsync(
            $"""
            select conducted_on as "ConductedOn", conducted as "Conducted", non_conduction_reason::text as "Reason", quran_recitation_surah as "Surah", quran_recitation_verse as "Verse",
                   arabic_topic::text as "Arabic", aqaed_topic::text as "Aqaed", ahkam_topic::text as "Ahkam", akhlaq_topic::text as "Akhlaq", other_topic::text as "Other"
            from classes.class_sessions
            where class_id = {classId}
            order by conducted_on desc, id desc
            limit {MaxSessions}
            """,
            r => new Row(
                r.Date("ConductedOn"), r.Short("Conducted"), r.TextOrNull("Reason"), r.IntOrNull("Surah"), r.IntOrNull("Verse"),
                r.TextOrNull("Arabic"), r.TextOrNull("Aqaed"), r.TextOrNull("Ahkam"), r.TextOrNull("Akhlaq"), r.TextOrNull("Other")),
            ct);
        return [.. rows.Select(ToItem)];
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
