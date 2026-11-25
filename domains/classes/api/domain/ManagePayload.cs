using System.Globalization;
using Microsoft.Extensions.Configuration;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

/// <summary>
/// Everything the manage screen needs in one read (PHP class_manage.php api_manage_payload): the class, its tags, its schedule with each slot's topics, the lookups to pick from, what the
/// caller may do, the roster (domain/ClassRoster.cs) and, for a caller who may transfer, the classes a student can move to. GET /classes/{id}/manage and PUT /classes/{id} answer with it.
/// </summary>
internal static class ManagePayload
{
    private const int MaxRows = 20000;

    private static readonly (int Id, string Name)[] Languages = [(1, "English"), (2, "Urdu"), (3, "Gujarati")];

    private sealed record ClassRow(
        int Id,
        string Code,
        string Name,
        int? LevelId,
        string? LevelName,
        int? Gender,
        string? GenderName,
        int? LanguageId,
        DateOnly? StartedOn,
        string? Format,
        string? Address,
        string? City,
        string? Country,
        string? Location,
        int? Teacher,
        string? TeacherName,
        string? Link);

    private sealed record Option(int Id, string? Name);

    private sealed record Slot(int Id, int Day, int Hour, int Minute, string? Timezone);

    private sealed record SlotTopic(int Id, int ScheduleId, int TopicId);

    private sealed record Destination(int Id, string Code, string? Name);

    public static async Task<Dictionary<string, object?>> BuildAsync(
        NpgsqlDataSource source, Permissions permissions, IConfiguration configuration, Caller caller, int classId, CancellationToken ct)
    {
        var rows = await source.ListAsync(
            $"""
            select c.id as "Id", c.code as "Code", c.name as "Name", c.class_level_id as "LevelId", cl.name as "LevelName", c.gender as "Gender", g.name as "GenderName",
                   c.language_id as "LanguageId", to_char(c.started_on, 'YYYY-MM-DD') as "StartedOn", c.format as "Format", c.address as "Address", c.city as "City", c.country as "Country",
                   c.location as "Location", c.teacher as "Teacher", t.name as "TeacherName", c.link::text as "Link"
            from classes.classes c
            join platform.v_genders g on g.id = c.gender
            join classes.class_levels cl on cl.id = c.class_level_id
            join membership.v_members t on t.token = c.teacher
            where c.id = {classId} and c.status = 'A'
            limit 1
            """,
            ReadClass,
            ct);
        if (rows.Count == 0)
        {
            throw new InvalidOperationException("The class vanished between the guard and the payload.");
        }

        var can = await ClassRoster.CanAsync(permissions, caller, classId, ct);
        var payload = new Dictionary<string, object?>
        {
            ["class"] = ClassWire(rows[0], configuration),
            ["tags"] = OptionsWire(await TagsAsync(source, classId, ct)),
            ["schedules"] = await SchedulesWireAsync(source, classId, ct),
            ["lookups"] = new Dictionary<string, object?>
            {
                ["languages"] = Languages.Select(l => new Dictionary<string, object?> { ["id"] = l.Id, ["name"] = l.Name }).ToList(),
                ["tags"] = OptionsWire(await TagsAsync(source, null, ct)),
                ["topics"] = OptionsWire(await TopicsAsync(source, ct)),
                ["timezones"] = Timezones.All,
            },
            ["can"] = can.ToWire(),
        };
        foreach (var (key, value) in await ClassRoster.BuildAsync(source, classId, can, ct))
        {
            payload[key] = value;
        }

        payload["destinations"] = can.Transfer ? await DestinationsAsync(source, permissions, caller, classId, ct) : null;
        return payload;
    }

    private static ClassRow ReadClass(DbRow row) => new(
        row.Int("Id"),
        row.Text("Code"),
        row.Text("Name"),
        row.IntOrNull("LevelId"),
        row.TextOrNull("LevelName"),
        row.IntOrNull("Gender"),
        row.TextOrNull("GenderName"),
        row.IntOrNull("LanguageId"),
        row.DateOrNull("StartedOn"),
        row.TextOrNull("Format"),
        row.TextOrNull("Address"),
        row.TextOrNull("City"),
        row.TextOrNull("Country"),
        row.TextOrNull("Location"),
        row.IntOrNull("Teacher"),
        row.TextOrNull("TeacherName"),
        row.TextOrNull("Link"));

    private static Task<List<Option>> TagsAsync(NpgsqlDataSource source, int? classId, CancellationToken ct) =>
        classId is int id
            ? source.ListAsync(
                $"""
                select t.id as "Id", t.name as "Name" from classes.class_tags ct join classes.tags t on t.id = ct.tag_id
                where ct.class_id = {id} and t.deleted_at is null and ct.deleted_at is null
                order by t.name, t.id
                limit {MaxRows}
                """,
                ReadOption,
                ct)
            : source.ListAsync(
                $"""select id as "Id", name as "Name" from classes.tags where deleted_at is null order by name, id limit {MaxRows}""",
                ReadOption,
                ct);

    private static Task<List<Option>> TopicsAsync(NpgsqlDataSource source, CancellationToken ct) =>
        source.ListAsync($"""select id as "Id", name as "Name" from classes.topics where deleted_at is null order by id limit {MaxRows}""", ReadOption, ct);

    private static Option ReadOption(DbRow row) => new(row.Int("Id"), row.TextOrNull("Name"));

    private static async Task<List<Dictionary<string, object?>>> SchedulesWireAsync(NpgsqlDataSource source, int classId, CancellationToken ct)
    {
        var slots = await source.ListAsync(
            $"""
            select id as "Id", coalesce(day, 0) as "Day", coalesce(hour, 0) as "Hour", coalesce(minute, 0) as "Minute", timezone as "Timezone"
            from classes.class_schedules where class_id = {classId} and deleted_at is null order by id limit {MaxRows}
            """,
            row => new Slot(row.Int("Id"), row.Int("Day"), row.Int("Hour"), row.Int("Minute"), row.TextOrNull("Timezone")),
            ct);
        var topics = (await source.ListAsync(
            $"""
            select st.id as "Id", st.class_schedule_id as "ScheduleId", coalesce(st.topic_id, 0) as "TopicId"
            from classes.class_schedule_topics st join classes.class_schedules s on s.id = st.class_schedule_id
            where s.class_id = {classId} and s.deleted_at is null and st.deleted_at is null
            order by st.id
            limit {MaxRows}
            """,
            row => new SlotTopic(row.Int("Id"), row.Int("ScheduleId"), row.Int("TopicId")),
            ct)).ToLookup(t => t.ScheduleId);
        return slots.Select(s => new Dictionary<string, object?>
        {
            ["id"] = s.Id,
            ["day"] = s.Day,
            ["hour"] = s.Hour,
            ["minute"] = s.Minute,
            ["timezone"] = s.Timezone ?? string.Empty,
            ["topics"] = topics[s.Id].Select(t => new Dictionary<string, object?> { ["id"] = t.Id, ["topicId"] = t.TopicId }).ToList(),
        }).ToList();
    }

    private static async Task<List<Dictionary<string, object?>>> DestinationsAsync(NpgsqlDataSource source, Permissions permissions, Caller caller, int classId, CancellationToken ct)
    {
        var assigned = (await permissions.ReachAsync(caller, "classes:read", ct)).AssignedOnlyIds;
        var all = assigned is null;
        var ids = (assigned ?? []).ToArray();
        var rows = await source.ListAsync(
            $"""
            select c.id as "Id", c.code as "Code", c.name as "Name"
            from classes.classes c join classes.class_levels cl on cl.id = c.class_level_id
            where c.status = 'A' and c.id <> {classId} and ({all} or c.id = any({ids}))
            order by c.gender, cl.sort_order, c.id
            limit {MaxRows}
            """,
            row => new Destination(row.Int("Id"), row.Text("Code"), row.TextOrNull("Name")),
            ct);
        return rows.Select(d => new Dictionary<string, object?> { ["id"] = d.Id, ["code"] = d.Code, ["name"] = Text(d.Name) ?? string.Empty }).ToList();
    }

    // joinUrl: whoever may open the manage screen may share the class (PHP api_manage_payload), so no caller check here.
    private static Dictionary<string, object?> ClassWire(ClassRow c, IConfiguration configuration) => new()
    {
        ["id"] = c.Id,
        ["code"] = c.Code,
        ["name"] = Text(c.Name) ?? string.Empty,
        ["levelId"] = c.LevelId ?? 0,
        ["levelName"] = c.LevelName ?? string.Empty,
        ["gender"] = c.Gender ?? 0,
        ["genderName"] = c.GenderName ?? string.Empty,
        ["languageId"] = c.LanguageId,
        ["startedOn"] = c.StartedOn?.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture),
        ["format"] = c.Format ?? string.Empty,
        ["address"] = Text(Empty(c.Address)),
        ["city"] = Text(Empty(c.City)),
        ["country"] = Text(Empty(c.Country)),
        ["location"] = Text(Empty(c.Location)),
        ["teacher"] = c.Teacher ?? 0,
        ["teacherName"] = Text(Empty(c.TeacherName)),
        ["joinUrl"] = ClassCards.JoinUrl(configuration, c.Link),
    };

    private static List<Dictionary<string, object?>> OptionsWire(List<Option> options) =>
        options.Select(o => new Dictionary<string, object?> { ["id"] = o.Id, ["name"] = Text(Empty(o.Name)) }).ToList();

    // PHP getAll() as the caller sees it: every active class (only the assigned ones for a caller whose classes:read is assigned-only), minus this one.
    private static string? Empty(string? value) => string.IsNullOrEmpty(value) ? null : value;

    private static string? Text(string? value) => value is null ? null : PhpText.HtmlDecode(value);
}
