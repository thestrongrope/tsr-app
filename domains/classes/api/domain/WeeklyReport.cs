using System.Globalization;
using Microsoft.AspNetCore.Http;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

/// <summary>
/// The weekly report as data, for the screen (GET /reports/weekly) and the download (its /download): every class the caller reaches and, for each week of the months asked for, held (how many times), not held or not filled.
/// PHP: routes/reports.php api_require_weekly_report (:245), mis.php weeklyReport. Queries: the class ids of the scope, the classes, the sessions.
/// Scope as PHP's reportClasses: the reports:read reach AND, for a caller whose classes:read is assigned-only, those classes only. A class whose teacher has no member row loses its sessions (PHP's inner join).
/// Copied: a day with two sessions counts once (the later wins), the week cells follow WeeklyGrid, "level" narrows by exact name after the list of levels is read.
/// </summary>
internal static class WeeklyReport
{
    internal sealed record CellItem(string Status, int Sessions);

    internal sealed record ClassItem(int ClassId, string Level, string Class, string? Teacher, IReadOnlyList<CellItem> Weeks);

    internal sealed record Loaded(int Gender, string From, string To, IReadOnlyList<string> Levels, IReadOnlyList<WeeklyGrid.Month> Months, IReadOnlyList<ClassItem> Classes);

    private sealed record ClassRow(int Id, string Level, string Code, string? TeacherName);

    /// <summary>The gender and reports:read (403), then the months (422), then the report. PHP's order.</summary>
    public static async Task<(Loaded? Report, IResult? Refusal)> OpenAsync(HttpContext context, NpgsqlDataSource db, Permissions permissions, Caller caller, DateOnly today, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(context);
        var (scope, refusal) = await ReportScope.OpenAsync(context, permissions, caller, ct);
        if (refusal is not null)
        {
            return (null, refusal);
        }

        var from = ReportMonths.Param(context, "from") ?? today.ToString("MM-yyyy", CultureInfo.InvariantCulture);
        var to = ReportMonths.Param(context, "to") ?? from;
        var invalid = ReportMonths.Check(from, to, limitToTwelve: true);
        if (invalid is not null)
        {
            return (null, Problem.Detail(StatusCodes.Status422UnprocessableEntity, invalid));
        }

        var ids = await ReportScope.KeepAssignedAsync(await scope!.ClassIdsAsync(db, 0, ct), permissions, caller, ct);
        var classes = await ClassesAsync(db, ids, ct);
        var (start, end) = ReportCalendar.Window(from, to, today);
        var sessions = await WeeklySessions.ByClassAndDayAsync(db, ids, start, end, ct);
        var months = WeeklyGrid.Months(start, end);

        var level = ReportScope.LevelOf(context);
        var items = classes
            .Where(c => level.Length == 0 || c.Level == level)
            .Select(c => ToItem(c, sessions.GetValueOrDefault(c.Id) ?? [], months))
            .ToList();
        return (new Loaded(scope.Gender, from, to, [.. classes.Select(c => c.Level).Distinct()], months, items), null);
    }

    // PHP getAll: the class's level must exist (inner join), the teacher's name may be missing (left join); order gender, level order, id.
    private static async Task<List<ClassRow>> ClassesAsync(NpgsqlDataSource db, int[] ids, CancellationToken ct) =>
        await db.ListAsync(
            $"""
                select c.id as "Id", cl.name::text as "Level", c.code::text as "Code", u.name::text as "TeacherName"
                from classes.classes c
                join classes.class_levels cl on cl.id = c.class_level_id
                left join membership.v_members u on u.token = c.teacher
                where c.id = any({ids})
                order by c.gender, cl.sort_order, c.id
                """,
            r => new ClassRow(r.Int("Id"), r.Text("Level"), r.Text("Code"), r.TextOrNull("TeacherName")),
            ct);

    private static ClassItem ToItem(ClassRow c, Dictionary<DateOnly, int> conducted, IReadOnlyList<WeeklyGrid.Month> months)
    {
        var cells = months
            .SelectMany(m => m.Weeks)
            .Select(days => WeeklyGrid.Read(WeeklyGrid.CellOf(conducted, days)))
            .Select(cell => new CellItem(cell.Status, cell.Sessions))
            .ToList();
        return new ClassItem(c.Id, c.Level, c.Code, PhpCast.StrOrNull(c.TeacherName), cells);
    }
}
