using System.Globalization;
using System.Text.Json.Serialization;
using Microsoft.EntityFrameworkCore;

namespace Tsr.Classes.Api.Domain;

/// <summary>
/// The syllabus item PHP sends (routes/syllabus.php api_syllabus_item_spec), shared by the level list and the four admin routes: the row, its wire form (an empty description is null, a missing sort order is 0,
/// naive datetimes) and the reads of live rows. <c>sort_order</c> sorts NULL first, as MariaDB does.
/// </summary>
internal static class SyllabusItems
{
    private const string Naive = "yyyy-MM-dd'T'HH:mm:ss";
    private const int MaxRows = 20000;

    internal sealed record Row(
        int Id,
        int LevelId,
        string SubjectName,
        string? Description,
        string LinkType,
        string Url,
        int SortOrder,
        bool IsActive,
        DateTime CreatedAt,
        DateTime? ModifiedAt);

    internal sealed record Item(
        int Id,
        [property: JsonPropertyName("level_id")] int LevelId,
        [property: JsonPropertyName("subject_name")] string SubjectName,
        string? Description,
        [property: JsonPropertyName("link_type")] string LinkType,
        string Url,
        [property: JsonPropertyName("sort_order")] int SortOrder,
        [property: JsonPropertyName("is_active")] bool IsActive,
        [property: JsonPropertyName("created_at")] string CreatedAt,
        [property: JsonPropertyName("modified_at")] string? ModifiedAt);

    public static Item ToItem(Row r) => new(
        r.Id,
        r.LevelId,
        r.SubjectName,
        string.IsNullOrEmpty(r.Description) ? null : r.Description,
        r.LinkType,
        r.Url,
        r.SortOrder,
        r.IsActive,
        r.CreatedAt.ToString(Naive, CultureInfo.InvariantCulture),
        r.ModifiedAt?.ToString(Naive, CultureInfo.InvariantCulture));

    /// <summary>The live (not deleted) items of one level, active only, in PHP's order.</summary>
    public static async Task<List<Item>> ActiveOfLevelAsync(ClassesContext db, long levelId, CancellationToken ct)
    {
        var rows = await db.Database
            .SqlQuery<Row>($"""
                select id as "Id", level_id as "LevelId", subject_name as "SubjectName", description as "Description", link_type as "LinkType",
                       url as "Url", coalesce(sort_order, 0) as "SortOrder", is_active <> 0 as "IsActive",
                       created_at at time zone 'UTC' as "CreatedAt", modified_at at time zone 'UTC' as "ModifiedAt"
                from classes.syllabus
                where level_id = {levelId} and is_active = 1 and deleted_at is null
                order by sort_order nulls first, subject_name
                limit {MaxRows}
                """)
            .ToListAsync(ct);
        return rows.Select(ToItem).ToList();
    }

    /// <summary>Every live item (inactive ones too when asked), in PHP's order.</summary>
    public static async Task<List<Item>> LiveAsync(ClassesContext db, bool includeInactive, CancellationToken ct)
    {
        var rows = await db.Database
            .SqlQuery<Row>($"""
                select id as "Id", level_id as "LevelId", subject_name as "SubjectName", description as "Description", link_type as "LinkType",
                       url as "Url", coalesce(sort_order, 0) as "SortOrder", is_active <> 0 as "IsActive",
                       created_at at time zone 'UTC' as "CreatedAt", modified_at at time zone 'UTC' as "ModifiedAt"
                from classes.syllabus
                where deleted_at is null and ({includeInactive} or is_active = 1)
                order by sort_order nulls first, subject_name
                limit {MaxRows}
                """)
            .ToListAsync(ct);
        return rows.Select(ToItem).ToList();
    }

    /// <summary>One live item by id, or null (PHP syllabus->exists / get).</summary>
    public static async Task<Item?> LiveByIdAsync(ClassesContext db, long id, CancellationToken ct)
    {
        var rows = await db.Database
            .SqlQuery<Row>($"""
                select id as "Id", level_id as "LevelId", subject_name as "SubjectName", description as "Description", link_type as "LinkType",
                       url as "Url", coalesce(sort_order, 0) as "SortOrder", is_active <> 0 as "IsActive",
                       created_at at time zone 'UTC' as "CreatedAt", modified_at at time zone 'UTC' as "ModifiedAt"
                from classes.syllabus
                where id = {id} and deleted_at is null
                limit 1
                """)
            .ToListAsync(ct);
        return rows.Count == 0 ? null : ToItem(rows[0]);
    }
}
