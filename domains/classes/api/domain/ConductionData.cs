using System.Globalization;
using Microsoft.AspNetCore.Http;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

/// <summary>
/// What the six conduction slices read, in PHP's shapes (routes/conduction.php, SessionsModel): the guard chain, the class header with its roster, a session in the wire form, a session's attendance, the surah list,
/// and the day check. A session's five subject flags are true when the column holds '1' or 'Y' in either case (PHP's API writes 0/1, the older web form Y/N; the column is citext).
/// </summary>
internal static class ConductionData
{
    private const int MaxRows = 5000;

    internal sealed record Student(int Token, string Name, bool Present, int Recitation, bool Extra);

    internal sealed record ClassPayload(
        int Id,
        string Code,
        string Name,
        int Level,
        string? LevelName,
        int Gender,
        string Status,
        string? TeacherName,
        IReadOnlyList<Student> Students,
        IReadOnlyList<Student> ExtraStudents,
        int TotalStudents);

    internal sealed record SessionRow(
        int Id,
        int? ClassId,
        DateOnly ConductedOn,
        bool Conducted,
        int? Duration,
        int? Attendance,
        int? Surah,
        int? Verse,
        bool ArabicConducted,
        bool AqaedConducted,
        bool AhkamConducted,
        bool AkhlaqConducted,
        bool OtherConducted,
        string? ArabicTopic,
        string? AqaedTopic,
        string? AhkamTopic,
        string? AkhlaqTopic,
        string? OtherTopic,
        string? Reason,
        DateTimeOffset CreatedAt);

    /// <summary>PHP's api_conduction_session_spec.</summary>
    internal sealed record SessionItem(
        int Id,
        string ConductedOn,
        bool Conducted,
        int? Duration,
        int? Attendance,
        int? QuranRecitationSurah,
        int? QuranRecitationVerse,
        bool ArabicConducted,
        bool AqaedConducted,
        bool AhkamConducted,
        bool AkhlaqConducted,
        bool OtherConducted,
        string? ArabicTopic,
        string? AqaedTopic,
        string? AhkamTopic,
        string? AkhlaqTopic,
        string? OtherTopic,
        string? NonConductionReason,
        bool Editable);

    internal sealed record AttendanceItem(int Token, string Name, bool Present, int Recitation, bool Extra);

    internal sealed record Surah(int Id, string Name, string Arabic, int Verses);

    internal sealed record DayCheck(bool AlreadyConducted, bool SameWeek);

    private sealed record DayCounts(long Exact, long Week, long Slots);

    private sealed record HeaderRow(int Id, string Code, string Name, int Level, string? LevelName, int Gender, string Status, string? TeacherName, string? ExtraStudents);

    /// <summary>PHP's chain on every conduction route: the active class (404), then the permission on it (403, "manage this class"). <paramref name="action"/> is sessions:create or sessions:update.</summary>
    public static async Task<(ClassGuards.ClassHead? Head, IResult? Refusal)> OpenAsync(
        NpgsqlDataSource source, Permissions permissions, Caller caller, string classId, string action, CancellationToken ct)
    {
        var head = await ClassGuards.FindActiveClassAsync(source, ClassGuards.IdOf(classId), ct);
        if (head is null)
        {
            return (null, Refusals.ClassNotFound());
        }

        var allowed = await permissions.CanAsync(caller, action, AccessTarget.ForClass(head.Id), ct);
        return allowed ? (head, null) : (null, Problem.Detail(StatusCodes.Status403Forbidden, "You do not have permission to manage this class"));
    }

    public static string? Text(string? value) => string.IsNullOrEmpty(value) ? null : value;

    public static string DayText(DateOnly day) => day.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);

    public static DateOnly Today(TimeProvider clock) => DateOnly.FromDateTime(clock.GetUtcNow().UtcDateTime);

    /// <summary>The class header every conduction screen carries: the class, its current roster (PHP getStudents) and its extra students, all marked absent.</summary>
    public static async Task<ClassPayload> HeaderAsync(NpgsqlDataSource source, int classId, CancellationToken ct)
    {
        var rows = await source.ListAsync(
            $"""
                select c.id as "Id", c.code as "Code", c.name as "Name", coalesce(c.class_level_id, 0) as "Level", cl.name as "LevelName", c.gender as "Gender",
                       c.status as "Status", t.name as "TeacherName", c.extra_students as "ExtraStudents"
                from classes.classes c
                join classes.class_levels cl on cl.id = c.class_level_id
                left join membership.v_members t on t.token = c.teacher
                where c.id = {classId}
                """,
            row => new HeaderRow(
                row.Int("Id"),
                row.Text("Code"),
                row.Text("Name"),
                row.Int("Level"),
                row.TextOrNull("LevelName"),
                row.Int("Gender"),
                row.Text("Status"),
                row.TextOrNull("TeacherName"),
                row.TextOrNull("ExtraStudents")),
            ct);
        var row = rows.Single();
        var roster = await ClassRoster.ActiveAsync(source, classId, ct);
        var students = roster.Select(s => new Student(s.Token, s.Name ?? string.Empty, false, 0, false)).ToList();
        var extras = ConductionRules.ExtraStudentsOf(row.ExtraStudents).Select(e => new Student(e.Token, e.Name, false, 0, true)).ToList();
        return new ClassPayload(row.Id, row.Code, row.Name, row.Level, Text(row.LevelName), row.Gender, row.Status, Text(row.TeacherName), students, extras, students.Count + extras.Count);
    }

    public static async Task<List<Surah>> HolyQuranAsync(NpgsqlDataSource source, CancellationToken ct) =>
        await source.ListAsync(
            $"""select id as "Id", coalesce(surah, '') as "Name", coalesce(arabic, '') as "Arabic", verses as "Verses" from content.v_quran order by id limit {MaxRows}""",
            row => new Surah(row.Int("Id"), row.Text("Name"), row.Text("Arabic"), row.Int("Verses")),
            ct);

    public static SessionItem ToItem(SessionRow s, DateTimeOffset now) => new(
        s.Id,
        DayText(s.ConductedOn),
        s.Conducted,
        s.Duration,
        s.Attendance,
        s.Surah,
        s.Verse,
        s.ArabicConducted,
        s.AqaedConducted,
        s.AhkamConducted,
        s.AkhlaqConducted,
        s.OtherConducted,
        Text(s.ArabicTopic),
        Text(s.AqaedTopic),
        Text(s.AhkamTopic),
        Text(s.AkhlaqTopic),
        Text(s.OtherTopic),
        Text(s.Reason),
        ConductionRules.IsEditable(s.CreatedAt, now));

    /// <summary>PHP getById's row (no deleted_at filter), or null.</summary>
    public static async Task<SessionRow?> GetSessionAsync(NpgsqlDataSource source, long sessionId, CancellationToken ct)
    {
        var rows = await GetSessionsAsync(source, [sessionId], ct);
        return rows.Count == 0 ? null : rows[0];
    }

    /// <summary>The rows of these session ids, in the order given (an id that is no session is left out).</summary>
    public static async Task<List<SessionRow>> GetSessionsAsync(NpgsqlDataSource source, long[] sessionIds, CancellationToken ct)
    {
        var ids = sessionIds.Where(id => id is >= int.MinValue and <= int.MaxValue).Select(id => (int)id).ToArray();
        var rows = await source.ListAsync(
            $"""
                select id as "Id", class_id as "ClassId", conducted_on as "ConductedOn", conducted = 1 as "Conducted", duration as "Duration", attendance as "Attendance",
                       quran_recitation_surah as "Surah", quran_recitation_verse as "Verse",
                       arabic_conducted in ('1', 'Y') as "ArabicConducted", aqaed_conducted in ('1', 'Y') as "AqaedConducted", ahkam_conducted in ('1', 'Y') as "AhkamConducted",
                       akhlaq_conducted in ('1', 'Y') as "AkhlaqConducted", other_conducted in ('1', 'Y') as "OtherConducted",
                       arabic_topic as "ArabicTopic", aqaed_topic as "AqaedTopic", ahkam_topic as "AhkamTopic", akhlaq_topic as "AkhlaqTopic", other_topic as "OtherTopic",
                       non_conduction_reason as "Reason", created_at as "CreatedAt"
                from classes.class_sessions
                where id = any({ids})
                limit {MaxRows}
                """,
            row => new SessionRow(
                row.Int("Id"),
                row.IntOrNull("ClassId"),
                row.Date("ConductedOn"),
                row.Bool("Conducted"),
                row.IntOrNull("Duration"),
                row.IntOrNull("Attendance"),
                row.IntOrNull("Surah"),
                row.IntOrNull("Verse"),
                row.Bool("ArabicConducted"),
                row.Bool("AqaedConducted"),
                row.Bool("AhkamConducted"),
                row.Bool("AkhlaqConducted"),
                row.Bool("OtherConducted"),
                row.TextOrNull("ArabicTopic"),
                row.TextOrNull("AqaedTopic"),
                row.TextOrNull("AhkamTopic"),
                row.TextOrNull("AkhlaqTopic"),
                row.TextOrNull("OtherTopic"),
                row.TextOrNull("Reason"),
                row.Instant("CreatedAt")),
            ct);
        return rows.OrderBy(r => Array.IndexOf(sessionIds, (long)r.Id)).ToList();
    }

    public static async Task<List<AttendanceItem>> AttendanceAsync(NpgsqlDataSource source, int sessionId, CancellationToken ct) =>
        await source.ListAsync(
            $"""
                select coalesce(m.token, ca.token) as "Token", coalesce(m.name, ca.name, '') as "Name", ca.present = 1 as "Present", ca.recitation as "Recitation", ca.extra_student = 1 as "Extra"
                from classes.class_attendance ca
                left join membership.v_members m on m.token = ca.token and ca.extra_student = 0
                where ca.session_id = {sessionId}
                order by ca.id
                limit {MaxRows}
                """,
            row => new AttendanceItem(row.Int("Token"), row.Text("Name"), row.Bool("Present"), row.Int("Recitation"), row.Bool("Extra")),
            ct);

    /// <summary>PHP getSessionByDate: a session already on the day (any state), and whether the day's Monday-to-Sunday week already holds as many sessions as the class has schedule rows (deleted ones too, at least one). <paramref name="excludeId"/> 0 excludes nothing.</summary>
    public static async Task<DayCheck> CheckDayAsync(DbTx tx, int classId, DateOnly day, int excludeId, CancellationToken ct)
    {
        var (monday, sunday) = ConductionRules.WeekOf(day);
        var rows = await tx.ListAsync(
            $"""
                select (select count(*) from classes.class_sessions where class_id = {classId} and id <> {excludeId} and conducted_on = {day}) as "Exact",
                       (select count(*) from classes.class_sessions where class_id = {classId} and id <> {excludeId} and conducted_on between {monday} and {sunday}) as "Week",
                       (select count(*) from classes.class_schedules where class_id = {classId}) as "Slots"
                """,
            row => new DayCounts(row.Long("Exact"), row.Long("Week"), row.Long("Slots")),
            ct);
        var counts = rows.Single();
        return new DayCheck(counts.Exact > 0, counts.Week >= Math.Max(counts.Slots, 1));
    }
}
