using System.Text.Json;
using Microsoft.EntityFrameworkCore;

namespace Tsr.Notifications.Api.Domain;

/// <summary>An announcement's target as the request names it: one of <see cref="Audience.TargetTypes"/> and its raw values (a list, or the values of an object, as PHP's array).</summary>
internal sealed record Target(string Type, IReadOnlyList<JsonElement> Values);

/// <summary>
/// Who a notification reaches: PHP's <c>api_fcm_device_tokens</c> and <c>api_fcm_user_tokens</c> (api/mobile/lib/fcm.php) and <c>ClassNotificationsModel::audience</c>, ported; the device query and the
/// member query of CLASS_LEVEL still disagree as in PHP (see lane-notify-core-notes.md), GENDER uses one definition for both. Other domains are read through their published
/// views only: classes (<c>v_enrolments</c>, <c>v_classes</c>), identity (<c>v_users</c>) and membership (<c>v_members</c>). The demo cohort (email ending <c>@demo.invalid</c>) is left out
/// of every device list, and out of every member list but a class's. Every list is cut at <see cref="MaxRecipients"/> plus one, so the caller can refuse an audience that is too large.
/// </summary>
internal static class Audience
{
    public static readonly IReadOnlyList<string> TargetTypes = ["ALL_USERS", "CLASS_LEVEL", "GENDER", "TEACHERS"];

    /// <summary>PHP has no cap (about 445 devices today). A request over this many devices or members is refused, never cut.</summary>
    public const int MaxRecipients = 20000;

    private const int Fetch = MaxRecipients + 1;

    public static bool TooLarge(int count) => count > MaxRecipients;

    /// <summary>The values that are numeric, as whole numbers, each once (PHP <c>api_fcm_int_list</c>).</summary>
    public static int[] IntList(IReadOnlyList<JsonElement> values)
    {
        var ids = new List<int>();
        foreach (var value in values)
        {
            var numeric = value.ValueKind == JsonValueKind.Number || (value.ValueKind == JsonValueKind.String && PhpValue.IsNumeric(value.GetString()!));
            if (numeric)
            {
                var id = (int)Math.Clamp(PhpValue.ToInteger(value), int.MinValue, int.MaxValue);
                if (!ids.Contains(id))
                {
                    ids.Add(id);
                }
            }
        }

        return [.. ids];
    }

    /// <summary>FCM device tokens of the target, demo devices left out.</summary>
    public static async Task<List<string>> DevicesAsync(NotificationsContext db, Target target, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(target);
        var rows = target.Type switch
        {
            "ALL_USERS" => await db.Database.SqlQuery<string>($"""
                select distinct ud.device_id as "Value" from notifications.user_devices ud
                where ud.device_id <> '' and not exists (select 1 from notifications.user_devices d2 join identity.v_users du on du.token = d2.token where d2.device_id = ud.device_id and du.email ilike '%@demo.invalid')
                order by 1 limit {Fetch}
                """).ToListAsync(ct),
            "CLASS_LEVEL" => await LevelDevicesAsync(db, IntList(target.Values), ct),
            "GENDER" => await GenderDevicesAsync(db, target.Values, ct),
            "TEACHERS" => await TeacherDevicesAsync(db, IntList(target.Values), ct),
            _ => [],
        };
        return Clean(rows);
    }

    /// <summary>Member tokens of the target, for the inbox copies (above zero, demo members left out).</summary>
    public static async Task<List<int>> MemberTokensAsync(NotificationsContext db, Target target, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(target);
        return target.Type switch
        {
            "ALL_USERS" => await db.Database.SqlQuery<int>($"""
                select distinct u.token as "Value" from identity.v_users u join notifications.user_devices ud on u.token = ud.token
                where u.token > 0 and u.email not ilike '%@demo.invalid' order by 1 limit {Fetch}
                """).ToListAsync(ct),
            "CLASS_LEVEL" => await ClassMembersAsync(db, IntList(target.Values), ct),
            "GENDER" => await GenderMembersAsync(db, target.Values, ct),
            "TEACHERS" => await TeacherMembersAsync(db, IntList(target.Values), ct),
            _ => [],
        };
    }

    /// <summary>The active students of a class (enrolled, not removed), token above zero.</summary>
    public static async Task<List<int>> ClassStudentsAsync(NotificationsContext db, int classId, CancellationToken ct) =>
        await db.Database.SqlQuery<int>($"""
            select distinct cs.token_no as "Value" from classes.v_enrolments cs
            where cs.class_id = {classId} and cs.status = 'A' and cs.removed_at is null and cs.token_no > 0
            order by 1 limit {Fetch}
            """).ToListAsync(ct);

    /// <summary>Device tokens of those members, demo devices left out.</summary>
    public static async Task<List<string>> MemberDevicesAsync(NotificationsContext db, int[] tokens, CancellationToken ct) =>
        Clean(await db.Database.SqlQuery<string>($"""
            select distinct ud.device_id as "Value" from notifications.user_devices ud
            where ud.token = any({tokens}) and ud.device_id <> ''
              and not exists (select 1 from notifications.user_devices d2 join identity.v_users du on du.token = d2.token where d2.device_id = ud.device_id and du.email ilike '%@demo.invalid')
            order by 1 limit {Fetch}
            """).ToListAsync(ct));

    private static List<string> Clean(List<string> rows) =>
        [.. rows.Select(PhpText.Trim).Where(t => t.Length > 0).Distinct(StringComparer.Ordinal)];

    // The device query matches the class LEVEL id and ignores removed_at and the class's status (PHP).
    private static async Task<List<string>> LevelDevicesAsync(NotificationsContext db, int[] levels, CancellationToken ct) =>
        levels.Length == 0
            ? []
            : await db.Database.SqlQuery<string>($"""
                select distinct ud.device_id as "Value"
                from notifications.user_devices ud
                join classes.v_enrolments cs on ud.token = cs.token_no
                join classes.v_classes c on cs.class_id = c.id
                where cs.status = 'A' and c.class_level_id = any({levels}) and ud.device_id <> ''
                  and not exists (select 1 from notifications.user_devices d2 join identity.v_users du on du.token = d2.token where d2.device_id = ud.device_id and du.email ilike '%@demo.invalid')
                order by 1 limit {Fetch}
                """).ToListAsync(ct);

    // The member query matches the class id (not the level) and the enrolment must not be removed (PHP's divergence, kept).
    private static async Task<List<int>> ClassMembersAsync(NotificationsContext db, int[] classes, CancellationToken ct) =>
        classes.Length == 0
            ? []
            : await db.Database.SqlQuery<int>($"""
                select distinct cs.token_no as "Value" from classes.v_enrolments cs
                where cs.class_id = any({classes}) and cs.status = 'A' and cs.removed_at is null and cs.token_no > 0
                  and not exists (select 1 from identity.v_users du where du.token = cs.token_no and du.email ilike '%@demo.invalid')
                order by 1 limit {Fetch}
                """).ToListAsync(ct);

    // ONE definition of "members of gender g" for both lists (owner decision, 12 Nov 2026; PHP's member query differed and wrote inbox rows for members the push never reached):
    // the FIRST value, numeric and 1 or 2, matched against the member's gender. Anything else is nobody.
    private static string? GenderCode(IReadOnlyList<JsonElement> values)
    {
        var first = values.Count > 0 ? IntList([values[0]]) : [];
        return first.Length == 1 && first[0] is (1 or 2) ? first[0].ToString(System.Globalization.CultureInfo.InvariantCulture) : null;
    }

    private static async Task<List<string>> GenderDevicesAsync(NotificationsContext db, IReadOnlyList<JsonElement> values, CancellationToken ct)
    {
        var gender = GenderCode(values);
        if (gender is null)
        {
            return [];
        }

        return await db.Database.SqlQuery<string>($"""
            select distinct ud.device_id as "Value"
            from notifications.user_devices ud
            join membership.v_members m on m.token = ud.token
            where m.gender = {gender} and ud.device_id <> ''
              and not exists (select 1 from notifications.user_devices d2 join identity.v_users du on du.token = d2.token where d2.device_id = ud.device_id and du.email ilike '%@demo.invalid')
            order by 1 limit {Fetch}
            """).ToListAsync(ct);
    }

    // Members with a device to push to, whose gender is the same code as above; a member of that gender whose only devices are shared with a demo member is left out too, as in the push.
    private static async Task<List<int>> GenderMembersAsync(NotificationsContext db, IReadOnlyList<JsonElement> values, CancellationToken ct)
    {
        var gender = GenderCode(values);
        if (gender is null)
        {
            return [];
        }

        return await db.Database.SqlQuery<int>($"""
            select distinct m.token as "Value"
            from membership.v_members m join notifications.user_devices ud on m.token = ud.token
            where m.token > 0 and m.gender = {gender} and ud.device_id <> ''
              and not exists (select 1 from notifications.user_devices d2 join identity.v_users du on du.token = d2.token where d2.device_id = ud.device_id and du.email ilike '%@demo.invalid')
            order by 1 limit {Fetch}
            """).ToListAsync(ct);
    }

    // No usable class id means every active class's teacher (PHP).
    private static async Task<List<string>> TeacherDevicesAsync(NotificationsContext db, int[] classes, CancellationToken ct) =>
        await db.Database.SqlQuery<string>($"""
            select distinct ud.device_id as "Value"
            from notifications.user_devices ud join classes.v_classes c on ud.token = c.teacher
            where c.status = 'A' and (cardinality({classes}) = 0 or c.id = any({classes})) and ud.device_id <> ''
              and not exists (select 1 from notifications.user_devices d2 join identity.v_users du on du.token = d2.token where d2.device_id = ud.device_id and du.email ilike '%@demo.invalid')
            order by 1 limit {Fetch}
            """).ToListAsync(ct);

    private static async Task<List<int>> TeacherMembersAsync(NotificationsContext db, int[] classes, CancellationToken ct) =>
        await db.Database.SqlQuery<int>($"""
            select distinct c.teacher as "Value" from classes.v_classes c
            where c.teacher is not null and c.teacher > 0 and c.status = 'A' and (cardinality({classes}) = 0 or c.id = any({classes}))
              and not exists (select 1 from identity.v_users du where du.token = c.teacher and du.email ilike '%@demo.invalid')
            order by 1 limit {Fetch}
            """).ToListAsync(ct);
}
