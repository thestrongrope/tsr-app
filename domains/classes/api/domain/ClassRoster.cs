using System.Globalization;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

/// <summary>
/// The roster payload PHP's class management answers with (class_manage.php api_manage_roster_for): <c>{students, removedStudents, mcqStudents, transferHistory}</c>. It is the
/// body of the roster reads and of the student actions (class-admin, edit a student), so they share this one file. A caller who may not update the class gets email, mobile and
/// notes as null, placed first (PHP's <c>[null...] + $row</c>); the transfer history is null unless the caller may transfer.
/// </summary>
internal static class ClassRoster
{
    private const int MaxRows = 5000;

    internal sealed record Student(int Token, string? Name, string? Email, string? Mobile, DateOnly? JoinedOn, string? Notes, bool McqAdmin);

    internal sealed record Removed(int Token, string? Name, string? Email, string? Mobile, DateTimeOffset? RemovedAt, string? RemovedReason, string? RemovedByName);

    internal sealed record Candidate(int Token, string? Name, string? Email, string? Mobile);

    internal sealed record Transfer(
        int StudentToken,
        string? StudentName,
        int FromClassId,
        string? FromClassCode,
        int ToClassId,
        string? ToClassCode,
        string? Type,
        string? Reason,
        string? TransferredBy,
        DateTimeOffset TransferredAt);

    /// <summary>What the caller may do on this class (PHP api_manage_can); the client shows an action only when it is true.</summary>
    internal sealed record Can(bool Update, bool Enrol, bool SetClassAdmin, bool Transfer)
    {
        public Dictionary<string, object?> ToWire() => new()
        {
            ["update"] = Update,
            ["enrol"] = Enrol,
            ["setClassAdmin"] = SetClassAdmin,
            ["transfer"] = Transfer,
        };
    }

    public static async Task<Can> CanAsync(Permissions permissions, Caller caller, int classId, CancellationToken ct)
    {
        var target = AccessTarget.ForClass(classId);
        return new Can(
            await permissions.CanAsync(caller, "classes:update", target, ct),
            await permissions.CanAsync(caller, "students:enrol", target, ct),
            await permissions.CanAsync(caller, "class-students:update", target, ct),
            await permissions.CanAsync(caller, "students:transfer", AccessTarget.None, ct));
    }

    // PHP getRemovedStudents: the member's latest enrolment row of the class, when it is removed and not a move to another class.
    // PHP getStudentsFromMCQs: members who answered a quiz of the class.
    // PHP getTransferHistory(0, classId): the transfers into or out of the class, newest first.
    public static Task<List<Student>> ActiveAsync(NpgsqlDataSource source, int classId, CancellationToken ct) =>
        source.ListAsync(
            $"""
            select m.token as "Token", m.name as "Name", u.email as "Email", m.mobile as "Mobile",
                   (min(cs.created_at) at time zone 'UTC')::date as "JoinedOn", max(cs.notes::text) as "Notes",
                   max(coalesce(cs.mcq_admin, 0)) > 0 as "McqAdmin"
            from classes.class_students cs
            join membership.v_members m on m.token = cs.token_no
            join identity.v_users u on u.id = m.user_id
            where cs.removed_at is null and cs.status = 'A' and cs.class_id = {classId}
            group by m.user_id, m.name, m.token, u.email, m.mobile
            order by m.name, m.token
            limit {MaxRows}
            """,
            row => new Student(row.Int("Token"), row.TextOrNull("Name"), row.TextOrNull("Email"), row.TextOrNull("Mobile"), row.Date("JoinedOn"), row.TextOrNull("Notes"), row.Bool("McqAdmin")),
            ct);

    public static Task<bool> IsActiveAsync(NpgsqlDataSource source, int classId, int token, CancellationToken ct) =>
        source.AnyAsync(
            $"""
            select 1 as "Value" from classes.class_students cs join membership.v_members m on m.token = cs.token_no
            where cs.removed_at is null and cs.status = 'A' and cs.class_id = {classId} and cs.token_no = {token}
            limit 1
            """,
            ct);

    public static Task<bool> IsRemovedAsync(NpgsqlDataSource source, int classId, int token, CancellationToken ct) =>
        source.AnyAsync(
            $"""
            select 1 as "Value"
            from classes.class_students cs
            join membership.v_members m on m.token = cs.token_no
            where cs.removed_at is not null and cs.class_id = {classId} and cs.token_no = {token}
              and cs.id = (select max(l.id) from classes.class_students l where l.class_id = cs.class_id and l.token_no = cs.token_no)
              and coalesce(cs.removed_reason, '') not like 'Transfer to class #%'
              and coalesce(cs.removed_reason, '') not like 'Promotion to class #%'
              and coalesce(cs.removed_reason, '') not like 'Demotion to class #%'
            limit 1
            """,
            ct);

    private static Task<List<Removed>> RemovedAsync(NpgsqlDataSource source, int classId, CancellationToken ct) =>
        source.ListAsync(
            $"""
            select m.token as "Token", m.name as "Name", u.email as "Email", m.mobile as "Mobile", cs.removed_at as "RemovedAt",
                   cs.removed_reason::text as "RemovedReason", r.name as "RemovedByName"
            from classes.class_students cs
            join membership.v_members m on m.token = cs.token_no
            join identity.v_users u on u.id = m.user_id
            left join membership.v_members r on r.token = cs.removed_by
            where cs.removed_at is not null and cs.class_id = {classId}
              and cs.id = (select max(l.id) from classes.class_students l where l.class_id = cs.class_id and l.token_no = cs.token_no)
              and coalesce(cs.removed_reason, '') not like 'Transfer to class #%'
              and coalesce(cs.removed_reason, '') not like 'Promotion to class #%'
              and coalesce(cs.removed_reason, '') not like 'Demotion to class #%'
            order by m.name, m.token
            limit {MaxRows}
            """,
            row => new Removed(
                row.Int("Token"),
                row.TextOrNull("Name"),
                row.TextOrNull("Email"),
                row.TextOrNull("Mobile"),
                row.InstantOrNull("RemovedAt"),
                row.TextOrNull("RemovedReason"),
                row.TextOrNull("RemovedByName")),
            ct);

    private static Task<List<Candidate>> QuizTakersAsync(NpgsqlDataSource source, int classId, CancellationToken ct) =>
        source.ListAsync(
            $"""
            select m.token as "Token", m.name as "Name", u.email as "Email", m.mobile as "Mobile"
            from membership.v_members m
            join identity.v_users u on u.id = m.user_id
            where m.token in (select r.token from assessment.v_quiz_results r where r.class_id = {classId})
            order by m.name, m.token
            limit {MaxRows}
            """,
            row => new Candidate(row.Int("Token"), row.TextOrNull("Name"), row.TextOrNull("Email"), row.TextOrNull("Mobile")),
            ct);

    private static Task<List<Transfer>> TransfersAsync(NpgsqlDataSource source, int classId, CancellationToken ct) =>
        source.ListAsync(
            $"""
            select st.token_no as "StudentToken", s.name as "StudentName", st.from_class_id as "FromClassId", fc.code as "FromClassCode",
                   st.to_class_id as "ToClassId", tc.code as "ToClassCode", st.type as "Type", st.reason::text as "Reason",
                   ab.name as "TransferredBy", st.transferred_at as "TransferredAt"
            from classes.student_transfers st
            join membership.v_members s on s.token = st.token_no
            join classes.classes fc on fc.id = st.from_class_id
            join classes.classes tc on tc.id = st.to_class_id
            join membership.v_members ab on ab.token = st.transferred_by
            where st.from_class_id = {classId} or st.to_class_id = {classId}
            order by st.transferred_at desc, st.id desc
            limit {MaxRows}
            """,
            row => new Transfer(
                row.Int("StudentToken"),
                row.TextOrNull("StudentName"),
                row.Int("FromClassId"),
                row.TextOrNull("FromClassCode"),
                row.Int("ToClassId"),
                row.TextOrNull("ToClassCode"),
                row.TextOrNull("Type"),
                row.TextOrNull("Reason"),
                row.TextOrNull("TransferredBy"),
                row.Instant("TransferredAt")),
            ct);

    public static async Task<Dictionary<string, object?>> BuildAsync(NpgsqlDataSource source, Permissions permissions, Caller caller, int classId, CancellationToken ct)
    {
        var can = await CanAsync(permissions, caller, classId, ct);
        return await BuildAsync(source, classId, can, ct);
    }

    public static async Task<Dictionary<string, object?>> BuildAsync(NpgsqlDataSource source, int classId, Can can, CancellationToken ct)
    {
        var students = await ActiveAsync(source, classId, ct);
        var removed = await RemovedAsync(source, classId, ct);
        var listed = students.Select(s => s.Token).Concat(removed.Select(r => r.Token)).ToHashSet();
        var candidates = (await QuizTakersAsync(source, classId, ct)).Where(c => !listed.Contains(c.Token)).ToList();
        var history = can.Transfer ? (await TransfersAsync(source, classId, ct)).Select(TransferWire).ToList() : null;

        return new Dictionary<string, object?>
        {
            ["students"] = students.Select(s => StudentWire(s, can.Update)).ToList(),
            ["removedStudents"] = removed.Select(r => RemovedWire(r, can.Update)).ToList(),
            ["mcqStudents"] = candidates.Select(c => CandidateWire(c, can.Update)).ToList(),
            ["transferHistory"] = history,
        };
    }

    public static Dictionary<string, object?> StudentWire(Student s, bool withContacts)
    {
        var wire = BlankedFirst(withContacts);
        wire["token"] = s.Token;
        wire["name"] = Text(s.Name) ?? string.Empty;
        wire["email"] = withContacts ? Empty(s.Email) : null;
        wire["mobile"] = withContacts ? Empty(s.Mobile) : null;
        wire["joinedOn"] = s.JoinedOn?.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
        wire["notes"] = withContacts ? Text(Empty(s.Notes)) : null;
        wire["mcqAdmin"] = s.McqAdmin;
        return wire;
    }

    private static Dictionary<string, object?> RemovedWire(Removed r, bool withContacts)
    {
        var wire = BlankedFirst(withContacts);
        wire["token"] = r.Token;
        wire["name"] = Text(r.Name) ?? string.Empty;
        wire["email"] = withContacts ? Empty(r.Email) : null;
        wire["mobile"] = withContacts ? Empty(r.Mobile) : null;
        wire["removedAt"] = DateTimeText(r.RemovedAt);
        wire["removedReason"] = Text(Empty(r.RemovedReason));
        wire["removedByName"] = Text(Empty(r.RemovedByName));
        return wire;
    }

    private static Dictionary<string, object?> CandidateWire(Candidate c, bool withContacts)
    {
        var wire = BlankedFirst(withContacts);
        wire["token"] = c.Token;
        wire["name"] = Text(c.Name) ?? string.Empty;
        wire["email"] = withContacts ? Empty(c.Email) : null;
        wire["mobile"] = withContacts ? Empty(c.Mobile) : null;
        return wire;
    }

    private static Dictionary<string, object?> TransferWire(Transfer t) => new()
    {
        ["studentToken"] = t.StudentToken,
        ["studentName"] = Text(t.StudentName) ?? string.Empty,
        ["fromClassId"] = t.FromClassId,
        ["fromClassCode"] = t.FromClassCode ?? string.Empty,
        ["toClassId"] = t.ToClassId,
        ["toClassCode"] = t.ToClassCode ?? string.Empty,
        ["type"] = t.Type ?? string.Empty,
        ["reason"] = Text(Empty(t.Reason)),
        ["transferredBy"] = Text(Empty(t.TransferredBy)),
        ["transferredAt"] = DateTimeText(t.TransferredAt),
    };

    // PHP: ['email' => null, 'mobile' => null, 'notes' => null] + $row. The three keys come first; the later assignments keep their place.
    private static Dictionary<string, object?> BlankedFirst(bool withContacts)
    {
        var wire = new Dictionary<string, object?>();
        if (!withContacts)
        {
            wire["email"] = null;
            wire["mobile"] = null;
            wire["notes"] = null;
        }

        return wire;
    }

    // api_cast datetime: 'Y-m-d H:i:s' with a T.
    private static string? DateTimeText(DateTimeOffset? value) =>
        value?.UtcDateTime.ToString("yyyy-MM-dd'T'HH:mm:ss", CultureInfo.InvariantCulture);

    private static string? Empty(string? value) => string.IsNullOrEmpty(value) ? null : value;

    private static string? Text(string? value) => value is null ? null : PhpText.HtmlDecode(value);
}
