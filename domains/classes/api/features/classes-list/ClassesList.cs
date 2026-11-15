using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ClassesList;

// Slice: GET /classes?include=managed&level&language&q -> the caller's active classes (taught, attended, and with include=managed the ones their classes:read reach covers). Contract: spec/api.yaml.
// PHP: routes/classes.php route_classes_list (classes.php:178), ClassesModel::listForUser / listingDetails / getSchedulesForClasses. Guard: classes:read (403), no gender needed.
// Copied quirks: q is a LIKE %q% on code or name with % and _ unescaped, and q "0" counts as empty (PHP empty()); level and language are (int) casts; studentCount counts every
// enrolment row without a removed_at (any status) plus the lines of extra_students, and is given only to role "managing". joinUrl (domain/ClassCards.cs JoinUrl) goes to the teacher and to whoever reaches the class, never to a student.

internal static class ClassesListSlice
{
    private const int MaxClasses = 5000;

    internal sealed record Listing(int Id, string? City, string? Country, int Students, string? ExtraStudents);

    internal sealed record TagRow(int ClassId, string Name);

    public static IEndpointRouteBuilder MapClassesList(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/classes", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, ClassesContext db, Permissions permissions, IConfiguration configuration, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await permissions.CanAsync(caller, "classes:read", AccessTarget.None, ct))
        {
            return Refusals.NotPermitted();
        }

        var reach = context.Request.Query["include"].LastOrDefault() == "managed"
            ? await permissions.ReachAsync(caller, "classes:read", ct)
            : null;
        var rows = await QueryAsync(context, db, caller.Token, reach, ct);
        var ids = rows.Select(r => r.Id).Distinct().ToArray();
        var slots = await ClassCards.SlotsAsync(db, ids, ct);
        var details = await DetailsAsync(db, ids, ct);
        var tags = await TagsAsync(db, ids, ct);

        var body = rows.Select(r =>
        {
            var card = ClassCards.ToCard(r, configuration);
            var detail = details.GetValueOrDefault(r.Id);
            card["city"] = detail?.City;
            card["country"] = detail?.Country;
            card["tags"] = tags[r.Id].ToList();
            card["studentCount"] = r.Role == "managing" && detail is not null ? StudentCount(detail) : null;
            card["schedules"] = slots[r.Id].Select(ClassCards.ToSchedule).ToList();
            return card;
        }).ToList();
        return Results.Json(body);
    }

    private static async Task<List<ClassCards.Row>> QueryAsync(HttpContext context, ClassesContext db, int token, Reach? reach, CancellationToken ct)
    {
        var level = IntFilter(context, "level");
        var language = IntFilter(context, "language");
        var q = context.Request.Query["q"].LastOrDefault();
        if (q is not null && q.Contains('\0'))
        {
            return []; // PostgreSQL text cannot hold a NUL byte, so nothing matches.
        }

        var pattern = string.IsNullOrEmpty(q) || q == "0" ? null : "%" + q + "%";
        var all = reach?.All ?? false;
        var gender = reach?.Gender;
        var reachedIds = reach?.ClassIds.ToArray() ?? [];
        var hasReach = all || gender is not null || reachedIds.Length > 0;

        return await db.Database
            .SqlQuery<ClassCards.Row>($"""
                select * from (select distinct c.id as "Id", c.code as "Code", c.name as "Name", c.class_level_id as "Level", cl.name as "LevelName", c.language_id as "Language",
                       c.gender as "Gender", c.status as "Status", c.location as "Location", c.format as "Format", c.started_on as "StartedOn",
                       t.name as "TeacherName", t.mobile as "TeacherMobile",
                       case when c.teacher = {token} then 'conducting' when {hasReach} and cs.token_no is null then 'managing' else 'attending' end as "Role",
                       case when (c.teacher = {token} or {all} or ({gender}::int is not null and c.gender = {gender}::int) or c.id = any({reachedIds}))
                                 and c.link <> '' then c.link::text end as "JoinCode"
                from classes.classes c
                left join classes.class_students cs on cs.class_id = c.id and cs.token_no = {token} and cs.status = 'A' and cs.removed_at is null
                left join classes.class_levels cl on cl.id = c.class_level_id
                left join membership.v_members t on t.token = c.teacher
                where c.status = 'A'
                  and ({level}::int is null or c.class_level_id = {level}::int)
                  and ({language}::int is null or c.language_id = {language}::int)
                  and ({pattern}::text is null or c.code like {pattern}::text or c.name like {pattern}::text)
                  and (cs.token_no = {token} or c.teacher = {token} or {all}
                       or ({gender}::int is not null and c.gender = {gender}::int) or c.id = any({reachedIds}))) x
                order by (x."Role" = 'conducting') desc, x."Id" desc
                limit {MaxClasses}
                """)
            .ToListAsync(ct);
    }

    // PHP: isset and not '' gives (int); anything else no filter.
    private static int? IntFilter(HttpContext context, string name)
    {
        var raw = context.Request.Query[name].LastOrDefault();
        return string.IsNullOrEmpty(raw) ? null : (int)Math.Clamp(PhpValue.IntOfText(raw), int.MinValue, int.MaxValue);
    }

    private static async Task<Dictionary<int, Listing>> DetailsAsync(ClassesContext db, int[] ids, CancellationToken ct)
    {
        var rows = await db.Database
            .SqlQuery<Listing>($"""
                select c.id as "Id", c.city as "City", c.country as "Country",
                       (select count(1) from classes.class_students s where s.class_id = c.id and s.removed_at is null)::int as "Students",
                       c.extra_students as "ExtraStudents"
                from classes.classes c where c.id = any({ids})
                """)
            .ToListAsync(ct);
        return rows.ToDictionary(r => r.Id);
    }

    private static async Task<ILookup<int, string>> TagsAsync(ClassesContext db, int[] ids, CancellationToken ct)
    {
        var rows = await db.Database
            .SqlQuery<TagRow>($"""
                select ct.class_id as "ClassId", t.name as "Name" from classes.class_tags ct
                join classes.tags t on t.id = ct.tag_id
                where ct.deleted_at is null and t.deleted_at is null and ct.class_id = any({ids})
                order by t.name
                """)
            .ToListAsync(ct);
        return rows.ToLookup(r => r.ClassId, r => r.Name);
    }

    // The enrolled rows plus one per line of extra_students (PHP count(explode("\n")); blank lines count, an empty field does not).
    private static int StudentCount(Listing detail) =>
        detail.Students + (string.IsNullOrEmpty(detail.ExtraStudents) ? 0 : detail.ExtraStudents.Split('\n').Length);
}
