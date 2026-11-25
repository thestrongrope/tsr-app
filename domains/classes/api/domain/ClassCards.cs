using System.Globalization;
using Microsoft.Extensions.Configuration;
using Npgsql;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

/// <summary>
/// The class card PHP sends from GET /classes and GET /classes/{id} (routes/classes.php api_class_spec, api_schedule_spec): the row the two queries share, its wire form
/// (PHP's api_cast: an empty text is null, a missing number is 0) and the schedule slots. The wire form is an ordered map, as PHP's array is; the list adds fields.
/// </summary>
internal static class ClassCards
{
    private const int MaxSlots = 20000;

    internal sealed record Row(
        int Id,
        string Code,
        string Name,
        int? Level,
        string? LevelName,
        int? Language,
        int? Gender,
        string Status,
        string? Location,
        string? Format,
        DateOnly? StartedOn,
        string? TeacherName,
        string? TeacherMobile,
        string? Role,
        string? JoinCode);

    internal sealed record Slot(int ClassId, int Day, int Hour, int Minute, string? Timezone);

    /// <summary>api_class_spec. <c>JoinCode</c> is the class's link only when the caller may share it (the teacher or a manager; each query decides).</summary>
    public static Dictionary<string, object?> ToCard(Row r, IConfiguration configuration) => new()
    {
        ["id"] = r.Id,
        ["code"] = r.Code,
        ["name"] = r.Name,
        ["level"] = r.Level ?? 0,
        ["levelName"] = Text(r.LevelName),
        ["language"] = r.Language,
        ["gender"] = r.Gender ?? 0,
        ["status"] = r.Status,
        ["location"] = Text(r.Location),
        ["teacherName"] = Text(r.TeacherName is null ? null : PhpText.HtmlDecode(r.TeacherName)),
        ["teacherMobile"] = Text(r.TeacherMobile is null ? null : PhpText.HtmlDecode(r.TeacherMobile)),
        ["format"] = Text(r.Format),
        ["startedOn"] = r.StartedOn?.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture),
        ["role"] = Text(r.Role),
        ["joinUrl"] = JoinUrl(configuration, r.JoinCode),
    };

    /// <summary>
    /// PHP ClassesModel::joinUrl: the public join page of a class, the public web base plus /join/ plus the class's link. PHP takes the base from REDIRECT_URI
    /// (public_web_base()); here it is the setting <c>TSR_PUBLIC_WEB_BASE</c>. Null without a base or without a link, and the app then hides its share tile.
    /// </summary>
    public static string? JoinUrl(IConfiguration configuration, string? link)
    {
        var publicWebBase = (configuration["TSR_PUBLIC_WEB_BASE"] ?? string.Empty).TrimEnd('/');
        if (publicWebBase.Length == 0 || string.IsNullOrEmpty(link))
        {
            return null;
        }

        return publicWebBase + "/join/" + link;
    }

    /// <summary>api_schedule_spec per slot.</summary>
    public static Dictionary<string, object?> ToSchedule(Slot s) => new()
    {
        ["day"] = s.Day,
        ["hour"] = s.Hour,
        ["minute"] = s.Minute,
        ["timezone"] = Text(s.Timezone),
    };

    public static async Task<ILookup<int, Slot>> SlotsAsync(NpgsqlDataSource source, int[] classIds, CancellationToken ct)
    {
        var rows = await source.ListAsync(
            $"""
            select class_id as "ClassId", coalesce(day, 0) as "Day", coalesce(hour, 0) as "Hour", coalesce(minute, 0) as "Minute", timezone as "Timezone"
            from classes.class_schedules
            where class_id = any({classIds}) and deleted_at is null
            order by class_id, day, hour, minute
            limit {MaxSlots}
            """,
            row => new Slot(row.Int("ClassId"), row.Int("Day"), row.Int("Hour"), row.Int("Minute"), row.TextOrNull("Timezone")),
            ct);
        return rows.ToLookup(s => s.ClassId);
    }

    private static string? Text(string? value) => string.IsNullOrEmpty(value) ? null : value;
}
