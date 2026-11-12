using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ClassCreate;

// Slice: POST /classes {gender, levelId, location, city, country, teacher, tags, schedules} -> create a class; 201 {classId}. Contract: spec/api.yaml.
// PHP: routes/class_manage.php route_class_create (:608), ClassesModel::create. Order: body, gender is the integer 1 or 2 (422), classes:create for that gender (403), levelId (422), location, city, country (required,
// <= 300 characters, trimmed), teacher (a candidate for the gender), tags, schedules (at least one slot; topics are checked but not stored), then the rate limit (409 "This class was just created": one class per
// gender, level, location, city and country a minute, counted even if the insert fails). The code is the level's code (SM AG MK AY B; SL ABL ML AL BL for ladies) and the name the level's name, each with the count of
// the level's and gender's classes plus one; the share link is ten random base-36 characters (PHP's trigger). Rows: the class, its live tags, its slots. Not written: language, format (the column defaults), audit.
// Deviation: a NUL byte in a text field is a 422 (PostgreSQL text cannot hold it). The rate limit is in memory (MemberRateLimit, keyed by a hash of the signature) where PHP keeps a file per signature.
// Event: classes.class_created (outbox). The admin_access_log row PHP writes goes through platform's published command.

internal static class ClassCreateSlice
{
    private const int MaxText = 300;
    private const int MaxRows = 20000;
    private const int LinkLength = 10;
    private const int LinkTries = 20;
    private const string Base36 = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    private static readonly string[] MenCodes = ["", "SM", "AG", "MK", "AY", "B"];
    private static readonly string[] WomenCodes = ["", "SL", "ABL", "ML", "AL", "BL"];

    internal sealed record ClassCreated(int ClassId, int CreatedBy);

    private sealed record Input(int Gender, int LevelId, string Location, string City, string Country, int Teacher, List<int> Tags, IReadOnlyList<ScheduleInput.Slot> Slots);

    public static IEndpointRouteBuilder MapClassCreate(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/classes", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, ClassesContext db, Permissions permissions, MemberRateLimit limit, TimeProvider clock, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var (body, refusal) = await RequestBodies.ReadAsync(context.Request, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        if (!PhpValue.IsInt(body!.Get("gender"), out var gender) || gender is not (1 or 2))
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, "gender must be 1 (gents) or 2 (ladies)");
        }

        if (!await permissions.CanAsync(caller, "classes:create", AccessTarget.ForGender((int)gender), ct))
        {
            return Problem.Detail(StatusCodes.Status403Forbidden, "You do not have permission to create a class");
        }

        await ClassGuards.LogAdminAccessAsync(db, context, permissions, caller, ct);
        var input = await ParseAsync(db, body, (int)gender, ct);
        if (!input.IsSuccess)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, input.Error!);
        }

        if (!limit.Allow("class_create", Signature(input.Value!), 1, 60))
        {
            return Problem.Detail(StatusCodes.Status409Conflict, "This class was just created");
        }

        var id = await SaveAsync(db, clock, input.Value!, caller.Token, ct);
        return Results.Json(new Dictionary<string, object?> { ["classId"] = id }, statusCode: StatusCodes.Status201Created);
    }

    // PHP keys the limit by the lower-cased signature itself; a member-token key is an int, so the signature is hashed to one (a collision only makes two different classes share a minute).
    private static int Signature(Input i)
    {
        var text = string.Join('|', i.Gender, i.LevelId, i.Location, i.City, i.Country).ToLowerInvariant();
        return BitConverter.ToInt32(SHA256.HashData(Encoding.UTF8.GetBytes(text)), 0);
    }

    private static async Task<Result<Input>> ParseAsync(ClassesContext db, JsonBody body, int gender, CancellationToken ct)
    {
        if (!PhpValue.IsInt(body.Get("levelId"), out var level) || level <= 0)
        {
            return Result.Fail<Input>("levelId is required");
        }

        var texts = new List<string>();
        foreach (var field in new[] { "location", "city", "country" })
        {
            var text = RequiredText(body.Get(field), field);
            if (!text.IsSuccess)
            {
                return Result.Fail<Input>(text.Error!);
            }

            texts.Add(text.Value!);
        }

        if (!PhpValue.IsInt(body.Get("teacher"), out var teacher) || teacher <= 0)
        {
            return Result.Fail<Input>("teacher is required");
        }

        var token = (int)Math.Min(teacher, int.MaxValue);
        if (!await TeacherSearch.IsCandidateAsync(db, token, gender == 1, ct))
        {
            return Result.Fail<Input>("teacher is not a member who can be assigned");
        }

        var tags = ParseTags(body.Get("tags"));
        if (!tags.IsSuccess)
        {
            return Result.Fail<Input>(tags.Error!);
        }

        var topicIds = (await db.Database
            .SqlQuery<int>($"""select id as "Value" from classes.topics where deleted_at is null limit {MaxRows}""")
            .ToListAsync(ct)).ToHashSet();
        var slots = ScheduleInput.Parse(body.Get("schedules"), topicIds);
        if (!slots.IsSuccess)
        {
            return Result.Fail<Input>(slots.Error!);
        }

        return slots.Value!.Count == 0
            ? Result.Fail<Input>("schedules needs at least one weekly slot")
            : Result.Ok(new Input(gender, (int)Math.Min(level, int.MaxValue), texts[0], texts[1], texts[2], token, tags.Value!, slots.Value!));
    }

    private static Result<string> RequiredText(JsonElement value, string field)
    {
        var text = value.ValueKind == JsonValueKind.String ? value.GetString()! : null;
        if (text is null || PhpText.Trim(text).Length == 0)
        {
            return Result.Fail<string>($"{field} is required");
        }

        if (PhpText.CodePointCount(text) > MaxText)
        {
            return Result.Fail<string>($"{field} must be at most 300 characters");
        }

        return text.Contains('\0') ? Result.Fail<string>($"{field} must not contain a NUL byte") : Result.Ok(PhpText.Trim(text));
    }

    private static Result<List<int>> ParseTags(JsonElement value)
    {
        var ids = new List<int>();
        if (value.ValueKind is JsonValueKind.Null or JsonValueKind.Undefined)
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

    private static async Task<int> SaveAsync(ClassesContext db, TimeProvider clock, Input input, int by, CancellationToken ct)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        var count = await db.Database
            .SqlQuery<int>($"""select count(*)::int as "Value" from classes.classes where class_level_id = {input.LevelId} and gender = {input.Gender}""")
            .SingleAsync(ct) + 1;
        var levelNames = await db.Database
            .SqlQuery<string>($"""select name as "Value" from classes.class_levels where id = {input.LevelId} limit 1""")
            .ToListAsync(ct);
        var codes = input.Gender == 1 ? MenCodes : WomenCodes;
        var code = input.LevelId < codes.Length ? codes[input.LevelId] + count : count.ToString(System.Globalization.CultureInfo.InvariantCulture);
        var name = (levelNames.Count == 0 ? "Unknown" : levelNames[0]) + count;
        var link = await NewLinkAsync(db, ct);

        var id = await db.Database
            .SqlQuery<int>($"""select nextval(pg_get_serial_sequence('classes.classes', 'id'))::int as "Value" """)
            .SingleAsync(ct);
        await db.Database.ExecuteSqlAsync(
            $"""
            insert into classes.classes (id, code, link, name, class_level_id, gender, location, city, country, teacher, created_by)
            values ({id}, {code}, {link}, {name}, {input.LevelId}, {input.Gender}, {input.Location}, {input.City}, {input.Country}, {input.Teacher}, {by})
            """,
            ct);
        await InsertTagsAsync(db, id, input.Tags, by, ct);
        foreach (var slot in input.Slots)
        {
            await db.Database.ExecuteSqlAsync(
                $"""
                insert into classes.class_schedules (class_id, day, hour, minute, timezone, created_by)
                values ({id}, {slot.Day}, {slot.Hour}, {slot.Minute}, {slot.Timezone}, {by})
                """,
                ct);
        }

        await Outbox.WriteAsync(db, "classes.class_created", new ClassCreated(id, by), clock, ct);
        await transaction.CommitAsync(ct);
        return id;
    }

    private static async Task InsertTagsAsync(ClassesContext db, int classId, List<int> submitted, int by, CancellationToken ct)
    {
        var requested = submitted.ToArray();
        var valid = await db.Database
            .SqlQuery<int>($"""select id as "Value" from classes.tags where deleted_at is null and id = any({requested}) limit {MaxRows}""")
            .ToListAsync(ct);
        foreach (var tag in valid)
        {
            await db.Database.ExecuteSqlAsync(
                $"""
                insert into classes.class_tags (class_id, tag_id, created_by) values ({classId}, {tag}, {by})
                on conflict (class_id, tag_id) do update set deleted_at = null, deleted_by = null
                """,
                ct);
        }
    }

    // PHP's trigger classes_before_create: ten random base-36 characters, redrawn while another class has them (bounded here).
    private static async Task<string> NewLinkAsync(ClassesContext db, CancellationToken ct)
    {
        for (var attempt = 0; attempt < LinkTries; attempt++)
        {
            var link = string.Create(LinkLength, 0, static (span, _) =>
            {
                for (var i = 0; i < span.Length; i++)
                {
                    span[i] = Base36[RandomNumberGenerator.GetInt32(Base36.Length)];
                }
            });
            if (!await LinkTakenAsync(db, link, ct))
            {
                return link;
            }
        }

        throw new InvalidOperationException("Could not draw an unused class link.");
    }

    internal static async Task<bool> LinkTakenAsync(ClassesContext db, string link, CancellationToken ct) =>
        (await db.Database.SqlQuery<int>($"""select 1 as "Value" from classes.classes where link = {link}::citext limit 1""").ToListAsync(ct)).Count > 0;
}
