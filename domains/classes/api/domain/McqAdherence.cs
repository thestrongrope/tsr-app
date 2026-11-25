using Npgsql;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

/// <summary>
/// PHP <c>ClassesModel::getClassMcqAdherence</c> for many classes at once (PHP calls it once per class): the standard MCQs of each class's level and language and the class's latest live copy of each.
/// Shared by the pending report (figures only) and the MCQ adherence reports (figures and the list). Reads assessment only through <c>v_standard_mcqs</c> and <c>v_class_mcq_copies</c>.
/// </summary>
internal static class McqAdherence
{
    private const int MaxItems = 200000;

    internal sealed record Figures(int ClassId, int Expected, int Conducted, int Pending);

    internal sealed record Item(int ClassId, string Code, string Topic, string Subject, string Lesson, string Name, string Status, DateTimeOffset? PublishedAt);

    /// <summary>A row per class with at least one standard MCQ: how many are expected, conducted (a copy with a publish time) and pending (a copy without one). One query.</summary>
    public static async Task<List<Figures>> FiguresAsync(NpgsqlDataSource db, int[] ids, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(db);
        ArgumentNullException.ThrowIfNull(ids);
        return await db.ListAsync(
            $"""
            select c.id as "ClassId", count(*)::int as "Expected",
                   (count(*) filter (where k.quiz_id is not null and k.published_at is not null))::int as "Conducted",
                   (count(*) filter (where k.quiz_id is not null and k.published_at is null))::int as "Pending"
            from classes.classes c
            join assessment.v_standard_mcqs m on m.level_id = c.class_level_id and m.language_id = coalesce(c.language_id, 1)
            left join assessment.v_class_mcq_copies k on k.class_id = c.id and k.mcq_code = m.code
            where c.id = any({ids})
            group by c.id
            """,
            r => new Figures(r.Int("ClassId"), r.Int("Expected"), r.Int("Conducted"), r.Int("Pending")),
            ct);
    }

    /// <summary>
    /// Every standard MCQ of the classes with its status (conducted, pending or skipped), in PHP's order: topic, subject, sort order (none first, as MariaDB), lesson, name (then code, which PHP leaves undefined). Row cap 200000.
    /// </summary>
    public static async Task<List<Item>> ItemsAsync(NpgsqlDataSource db, int[] ids, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(db);
        ArgumentNullException.ThrowIfNull(ids);
        return await db.ListAsync(
            $"""
            select c.id as "ClassId", m.code::text as "Code", m.topic::text as "Topic", m.subject::text as "Subject", m.lesson::text as "Lesson", m.name::text as "Name",
                   case when k.quiz_id is null then 'skipped' when k.published_at is null then 'pending' else 'conducted' end as "Status",
                   k.published_at as "PublishedAt"
            from classes.classes c
            join assessment.v_standard_mcqs m on m.level_id = c.class_level_id and m.language_id = coalesce(c.language_id, 1)
            left join assessment.v_class_mcq_copies k on k.class_id = c.id and k.mcq_code = m.code
            where c.id = any({ids})
            order by c.id, m.topic, m.subject, m.sort_order nulls first, m.lesson, m.name, m.code
            limit {MaxItems}
            """,
            r => new Item(r.Int("ClassId"), r.Text("Code"), r.Text("Topic"), r.Text("Subject"), r.Text("Lesson"), r.Text("Name"), r.Text("Status"), r.InstantOrNull("PublishedAt")),
            ct);
    }

    /// <summary>PHP <c>round($conducted * 100 / $expected, 1)</c>; no MCQ is 0.</summary>
    public static PhpFloat Percent(int conducted, int expected) =>
        expected <= 0 ? new PhpFloat(0) : PhpFloat.Round(conducted * 100m / expected, 1);
}
