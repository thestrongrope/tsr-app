using Npgsql;

namespace Tsr.Classes.Api.Domain;

/// <summary>PHP <c>MisModel::details()</c> as the weekly report and the this-week screen read it (both through <c>weeklyReport</c>): the sessions of classes whose level and teacher exist.</summary>
internal static class WeeklySessions
{
    private const int MaxRows = 100000;

    private sealed record SessionRow(int ClassId, DateOnly ConductedOn, int Conducted);

    /// <summary>The conducted flag of each class on each day of the window; of two sessions on one day the later (higher id) wins. Bound: 100000 sessions, oldest first.</summary>
    public static async Task<Dictionary<int, Dictionary<DateOnly, int>>> ByClassAndDayAsync(NpgsqlDataSource db, int[] ids, DateOnly start, DateOnly end, CancellationToken ct)
    {
        var rows = await db.ListAsync(
            $"""
            select s.class_id as "ClassId", s.conducted_on as "ConductedOn", s.conducted::int as "Conducted"
            from classes.class_sessions s
            join classes.classes c on c.id = s.class_id
            join classes.class_levels cl on cl.id = c.class_level_id
            join membership.v_members t on t.token = c.teacher
            where s.conducted_on >= {start} and s.conducted_on <= {end} and c.id = any({ids})
            order by s.id
            limit {MaxRows}
            """,
            r => new SessionRow(r.Int("ClassId"), r.Date("ConductedOn"), r.Int("Conducted")),
            ct);
        var byClass = new Dictionary<int, Dictionary<DateOnly, int>>();
        foreach (var row in rows)
        {
            if (!byClass.TryGetValue(row.ClassId, out var days))
            {
                days = [];
                byClass[row.ClassId] = days;
            }

            days[row.ConductedOn] = row.Conducted;
        }

        return byClass;
    }
}
