using System.Text.Json;
using Npgsql;

namespace Tsr.Notifications.Api.Domain;

/// <summary>Who a notification went to, in words: a summary and the names behind it.</summary>
internal sealed record AudienceDescription(string Summary, List<string> Items);

/// <summary>Names looked up once for a page of history: level, class and teacher names by id.</summary>
internal sealed record AudienceNames(Dictionary<int, string> Levels, Dictionary<int, string> Classes, Dictionary<int, string> Teachers);

/// <summary>
/// PHP's <c>MobileNotificationsModel::describe</c>: the audience read from the criteria the sender recorded (ALL_USERS, CLASS_LEVEL level ids, GENDER 1 or 2, TEACHERS class ids, CLASS a class id
/// as <c>value</c> or <c>class_id</c>, CC_NUDGE a teacher token); anything else comes back under its own type name.
/// </summary>
internal static class AudienceWords
{
    /// <summary>The ids the words will need, by kind, so one query each serves the whole page.</summary>
    public static (List<int> Levels, List<int> Classes, List<int> Teachers) IdsNeeded(IEnumerable<JsonElement?> criteria)
    {
        var levels = new List<int>();
        var classes = new List<int>();
        var teachers = new List<int>();
        foreach (var c in criteria)
        {
            switch (Criteria.TypeOf(c))
            {
                case "CLASS_LEVEL":
                    levels.AddRange(Criteria.PositiveIds(Values(c)));
                    break;
                case "TEACHERS" or "CLASS":
                    classes.AddRange(Criteria.PositiveIds(ClassValues(c!.Value)));
                    break;
                case "CC_NUDGE" when Present(c!.Value, "teacher", out var teacher):
                    teachers.AddRange(Criteria.PositiveIds([teacher]));
                    break;
            }
        }

        return (levels, classes, teachers);
    }

    public static AudienceDescription Describe(JsonElement? criteria, AudienceNames names)
    {
        ArgumentNullException.ThrowIfNull(names);
        var type = Criteria.TypeOf(criteria);
        switch (type)
        {
            case "ALL_USERS":
                return new AudienceDescription("All users", []);
            case "CLASS_LEVEL":
                return new AudienceDescription("Students of class levels", Values(criteria).Select(v => Name(names.Levels, Id(v), "Level {0} (removed)")).ToList());
            case "GENDER":
                var first = Values(criteria).FirstOrDefault();
                var word = first.ValueKind == JsonValueKind.Undefined ? string.Empty : PhpValue.Text(first);
                return new AudienceDescription(word switch { "1" => "Gents", "2" => "Ladies", _ => "One gender" }, []);
            case "TEACHERS" or "CLASS":
                var summary = type == "TEACHERS" ? "Teachers of classes" : "Students of a class";
                return new AudienceDescription(summary, ClassValues(criteria!.Value).Select(v => Name(names.Classes, Id(v), "Class {0} (removed)")).ToList());
            case "CC_NUDGE":
                var teacher = Present(criteria!.Value, "teacher", out var value) ? Id(value) : 0;
                return new AudienceDescription("Reminder to one teacher", [names.Teachers.GetValueOrDefault(teacher) ?? "Teacher " + teacher.ToString(System.Globalization.CultureInfo.InvariantCulture)]);
            default:
                return new AudienceDescription(type.Length > 0 ? type : "Unknown", []);
        }
    }

    /// <summary>The values of the criteria's <c>value</c> when it is a list or object (PHP <c>is_array</c>), else none.</summary>
    private static List<JsonElement> Values(JsonElement? criteria) =>
        criteria is { ValueKind: JsonValueKind.Object } c && c.TryGetProperty("value", out var value) && value.ValueKind is JsonValueKind.Array or JsonValueKind.Object
            ? JsonBody.Entries(value).Select(e => e.Value).ToList()
            : [];

    private static List<JsonElement> ClassValues(JsonElement criteria)
    {
        var values = Values(criteria);
        if (Present(criteria, "class_id", out var classId))
        {
            values.Add(classId);
        }

        return values;
    }

    private static bool Present(JsonElement criteria, string name, out JsonElement value)
    {
        value = default;
        return criteria.ValueKind == JsonValueKind.Object && criteria.TryGetProperty(name, out value) && value.ValueKind != JsonValueKind.Null;
    }

    private static int Id(JsonElement value) => (int)Math.Clamp(PhpValue.ToInteger(value), int.MinValue, int.MaxValue);

    private static string Name(Dictionary<int, string> names, int id, string missing) =>
        names.TryGetValue(id, out var name) ? name : string.Format(System.Globalization.CultureInfo.InvariantCulture, missing, id);

    public sealed record Named(int Id, string Name);

    private static Named ReadNamed(DbRow row) => new(row.Int("Id"), row.Text("Name"));

    public static async Task<AudienceNames> LookUpAsync(NpgsqlDataSource source, (List<int> Levels, List<int> Classes, List<int> Teachers) ids, CancellationToken ct)
    {
        var levelIds = ids.Levels.Distinct().ToArray();
        var teacherIds = ids.Teachers.Distinct().ToArray();
        var levels = levelIds.Length == 0
            ? []
            : (await source.ListAsync($"""select id as "Id", trim(name) as "Name" from classes.v_class_levels where id = any({levelIds})""", ReadNamed, ct)).ToDictionary(n => n.Id, n => n.Name);
        var teachers = teacherIds.Length == 0
            ? []
            : (await source.ListAsync($"""select distinct on (token) token as "Id", trim(coalesce(name, '')) as "Name" from membership.v_members where token = any({teacherIds}) order by token, user_id""", ReadNamed, ct)).ToDictionary(n => n.Id, n => n.Name);
        return new AudienceNames(levels, await Criteria.ClassNamesAsync(source, ids.Classes, ct), teachers);
    }
}
