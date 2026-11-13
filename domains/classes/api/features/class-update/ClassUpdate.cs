using System.Globalization;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ClassUpdate;

// Slice: PUT /classes/{class_id} -> edit a class's details, teacher, tags and schedule; answers with the manage payload (domain/ManagePayload.cs). Contract: spec/api.yaml.
// PHP: routes/class_manage.php route_class_update (:475), api_manage_class_input, ClassesModel::update. Order: active complete class (404), classes:update on it (403, "manage this class"), body (422), then 422s:
// languageId, startedOn, format, address/city/country/location (<= 300 characters, trimmed, blank is null), teacher, tags, schedules. Level, gender, code, name, link, status and extra_students are not edited.
// Writes: classes (started_on, language_id, location, format, address, city, country, teacher, updated_by; no updated_at, as PHP), the tag diff, the schedule and topic diff (ScheduleWriter.ApplyAsync).
// Deviation: PHP runs the schedule diff outside the transaction of the class and tags; here it is one transaction. A NUL byte in a text field is a 422 (PostgreSQL text cannot hold it; PHP stores it).
// Event: classes.class_updated (outbox). The admin_access_log row PHP writes is platform's published command, called after the permission check and before the body is read (PHP api_log_admin_action).

internal static partial class ClassUpdateSlice
{
    private const int MaxText = 300;
    private const int MaxRows = 20000;
    private static readonly string[] TextFields = ["address", "city", "country", "location"];

    internal sealed record ClassUpdated(int ClassId, int ChangedBy);

    private sealed record Changes(
        int? LanguageId,
        string? StartedOn,
        string Format,
        Dictionary<string, string?> Text,
        int Teacher,
        List<int> Tags,
        IReadOnlyList<ScheduleInput.Slot> Slots);

    // [0-9], not \d: .NET's \d also matches other scripts' digits, which int.Parse then refuses.
    [GeneratedRegex(@"^([0-9]{4})-([0-9]{2})-([0-9]{2})$", RegexOptions.CultureInvariant | RegexOptions.NonBacktracking)]
    private static partial Regex DateShape();

    public static IEndpointRouteBuilder MapClassUpdate(this IEndpointRouteBuilder routes)
    {
        routes.MapPut("/classes/{class_id}", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(
        string class_id, HttpContext context, ClassesContext db, Permissions permissions, IConfiguration configuration, TimeProvider clock, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var head = await ClassGuards.FindActiveClassAsync(db, ClassGuards.IdOf(class_id), ct);
        if (head is null)
        {
            return Refusals.ClassNotFound();
        }

        if (!await permissions.CanAsync(caller, "classes:update", AccessTarget.ForClass(head.Id), ct))
        {
            return Problem.Detail(StatusCodes.Status403Forbidden, "You do not have permission to manage this class");
        }

        await ClassGuards.LogAdminAccessAsync(db, context, permissions, caller, ct);
        var (body, refusal) = await RequestBodies.ReadAsync(context.Request, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var changes = await ParseAsync(db, body!, head, ct);
        if (!changes.IsSuccess)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, changes.Error!);
        }

        await SaveAsync(db, clock, head.Id, changes.Value!, caller.Token, ct);
        return Results.Json(await ManagePayload.BuildAsync(db, permissions, configuration, caller, head.Id, ct));
    }

    private static async Task<Result<Changes>> ParseAsync(ClassesContext db, JsonBody body, ClassGuards.ClassHead head, CancellationToken ct)
    {
        if (!TryLanguage(body.Get("languageId"), out var language))
        {
            return Result.Fail<Changes>("languageId is not a known language");
        }

        var started = body.Get("startedOn");
        if (!IsNull(started) && !IsRealDate(started))
        {
            return Result.Fail<Changes>("startedOn must be a date as YYYY-MM-DD");
        }

        var format = body.Get("format");
        if (format.ValueKind != JsonValueKind.String || format.GetString() is not ("Online" or "Offline"))
        {
            return Result.Fail<Changes>("format must be Online or Offline");
        }

        var text = new Dictionary<string, string?>();
        foreach (var field in TextFields)
        {
            var parsed = OptionalText(body.Get(field), field);
            if (!parsed.IsSuccess)
            {
                return Result.Fail<Changes>(parsed.Error!);
            }

            text[field] = parsed.Value;
        }

        var teacher = await TeacherAsync(db, body.Get("teacher"), head, ct);
        if (!teacher.IsSuccess)
        {
            return Result.Fail<Changes>(teacher.Error!);
        }

        var tags = ParseTags(body.Get("tags"));
        if (!tags.IsSuccess)
        {
            return Result.Fail<Changes>(tags.Error!);
        }

        var topicIds = (await db.Database
            .SqlQuery<int>($"""select id as "Value" from classes.topics where deleted_at is null limit {MaxRows}""")
            .ToListAsync(ct)).ToHashSet();
        var slots = ScheduleInput.Parse(body.Get("schedules"), topicIds);
        if (!slots.IsSuccess)
        {
            return Result.Fail<Changes>(slots.Error!);
        }

        return Result.Ok(new Changes(language, IsNull(started) ? null : started.GetString(), format.GetString()!, text, teacher.Value, tags.Value!, slots.Value!));
    }

    private static bool IsNull(JsonElement value) => value.ValueKind is JsonValueKind.Null or JsonValueKind.Undefined;

    // PHP: isset(LANGUAGES[$value]) with array-key rules: an int, a whole float, true, or text that is a canonical integer, naming 1 to 3.
    private static bool TryLanguage(JsonElement value, out int? language)
    {
        language = null;
        if (IsNull(value))
        {
            return true;
        }

        long id;
        switch (value.ValueKind)
        {
            case JsonValueKind.True:
                id = 1;
                break;
            case JsonValueKind.Number when value.TryGetDouble(out var number) && number == Math.Floor(number):
                id = (long)number;
                break;
            case JsonValueKind.String when Regex.IsMatch(value.GetString() ?? string.Empty, @"^(0|[1-9][0-9]{0,9})$", RegexOptions.CultureInvariant, TimeSpan.FromSeconds(1)):
                id = long.Parse(value.GetString()!, CultureInfo.InvariantCulture);
                break;
            default:
                return false;
        }

        if (id is < 1 or > 3)
        {
            return false;
        }

        language = (int)id;
        return true;
    }

    // DateTime::createFromFormat('Y-m-d') whose format() equals the input: four digits, two, two, a real day.
    private static bool IsRealDate(JsonElement value)
    {
        var match = value.ValueKind == JsonValueKind.String ? DateShape().Match(value.GetString()!) : null;
        if (match is not { Success: true })
        {
            return false;
        }

        var year = int.Parse(match.Groups[1].Value, CultureInfo.InvariantCulture);
        var month = int.Parse(match.Groups[2].Value, CultureInfo.InvariantCulture);
        var day = int.Parse(match.Groups[3].Value, CultureInfo.InvariantCulture);
        return year >= 1 && month is >= 1 and <= 12 && day >= 1 && day <= DateTime.DaysInMonth(year, month);
    }

    private static Result<string?> OptionalText(JsonElement value, string field)
    {
        if (IsNull(value))
        {
            return Result.Ok<string?>(null);
        }

        var text = value.ValueKind == JsonValueKind.String ? value.GetString()! : null;
        if (text is null || PhpText.CodePointCount(text) > MaxText)
        {
            return Result.Fail<string?>($"{field} must be at most 300 characters");
        }

        if (text.Contains('\0'))
        {
            return Result.Fail<string?>($"{field} must not contain a NUL byte");
        }

        var trimmed = PhpText.Trim(text);
        return Result.Ok<string?>(trimmed.Length == 0 ? null : trimmed);
    }

    private static async Task<Result<int>> TeacherAsync(ClassesContext db, JsonElement value, ClassGuards.ClassHead head, CancellationToken ct)
    {
        if (!PhpValue.IsInt(value, out var number) || number <= 0)
        {
            return Result.Fail<int>("teacher is required");
        }

        var teacher = (int)Math.Min(number, int.MaxValue);
        var current = await db.Database
            .SqlQuery<int>($"""select coalesce(teacher, 0) as "Value" from classes.classes where id = {head.Id}""")
            .SingleAsync(ct);
        if (teacher != current && !await TeacherSearch.IsCandidateAsync(db, teacher, head.Gender == 1, ct))
        {
            return Result.Fail<int>("teacher is not a member who can be assigned");
        }

        return Result.Ok(teacher);
    }

    private static Result<List<int>> ParseTags(JsonElement value)
    {
        var ids = new List<int>();
        if (IsNull(value))
        {
            return Result.Ok(ids);
        }

        if (value.ValueKind is not (JsonValueKind.Array or JsonValueKind.Object))
        {
            return Result.Fail<List<int>>("tags must be a list of tag ids");
        }

        foreach (var (_, tag) in JsonBody.Entries(value))
        {
            if (!PhpValue.IsInt(tag, out var id))
            {
                return Result.Fail<List<int>>("tags must be a list of tag ids");
            }

            ids.Add((int)Math.Clamp(id, int.MinValue, int.MaxValue));
        }

        return Result.Ok(ids);
    }

    private static async Task SaveAsync(ClassesContext db, TimeProvider clock, int classId, Changes c, int by, CancellationToken ct)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        var started = c.StartedOn is null ? (DateOnly?)null : DateOnly.ParseExact(c.StartedOn, "yyyy-MM-dd", CultureInfo.InvariantCulture);
        await db.Database.ExecuteSqlAsync(
            $"""
            update classes.classes set started_on = {started}, language_id = {c.LanguageId}, location = {c.Text["location"]}, format = {c.Format}, address = {c.Text["address"]},
                   city = {c.Text["city"]}, country = {c.Text["country"]}, teacher = {c.Teacher}, updated_by = {by}
            where id = {classId}
            """,
            ct);
        await SaveTagsAsync(db, classId, c.Tags, by, ct);
        await ScheduleWriter.ApplyAsync(db, classId, c.Slots, by, ct);
        await Outbox.WriteAsync(db, "classes.class_updated", new ClassUpdated(classId, by), clock, ct);
        await transaction.CommitAsync(ct);
    }

    // PHP: the submitted ids that are live tags; added ones are (re)activated, ids the class had and no longer lists are soft-deleted.
    private static async Task SaveTagsAsync(ClassesContext db, int classId, List<int> submitted, int by, CancellationToken ct)
    {
        var requested = submitted.ToArray();
        var valid = (await db.Database
            .SqlQuery<int>($"""select id as "Value" from classes.tags where deleted_at is null and id = any({requested}) limit {MaxRows}""")
            .ToListAsync(ct)).ToHashSet();
        var current = (await db.Database
            .SqlQuery<int>($"""
                select t.id as "Value" from classes.class_tags ct join classes.tags t on t.id = ct.tag_id
                where ct.class_id = {classId} and t.deleted_at is null and ct.deleted_at is null limit {MaxRows}
                """)
            .ToListAsync(ct)).ToHashSet();

        foreach (var tag in valid.Except(current))
        {
            await db.Database.ExecuteSqlAsync(
                $"""
                insert into classes.class_tags (class_id, tag_id, created_by) values ({classId}, {tag}, {by})
                on conflict (class_id, tag_id) do update set deleted_at = null, deleted_by = null
                """,
                ct);
        }

        foreach (var tag in current.Except(valid))
        {
            await db.Database.ExecuteSqlAsync(
                $"update classes.class_tags set deleted_at = now(), deleted_by = {by} where class_id = {classId} and tag_id = {tag} and deleted_at is null",
                ct);
        }
    }
}
