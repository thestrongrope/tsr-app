using System.Globalization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ReportWeekly;

// Slice: GET /reports/weekly?gender&from&to&level (months MM-YYYY, default this month) -> every class the caller reaches and, for each week of the months, held (how many times), not held or not filled.
// PHP: routes/reports.php route_reports_weekly (:291, api_require_weekly_report :245), mis.php weeklyReport. Queries: the class ids of the scope, the classes, the sessions.
// Scope as PHP's reportClasses: the reports:read reach AND, for a caller whose classes:read is assigned-only, those classes only. A class whose teacher has no member row loses its sessions (PHP's inner join).
// Copied: a day with two sessions counts once (the later wins), the week cells follow WeeklyGrid, "level" narrows by exact name after the list of levels is read.

internal static class ReportWeeklySlice
{
    private const int MaxSessions = 100000;

    internal sealed record WeekItem(string Month, string Label, string From, string To);

    internal sealed record CellItem(string Status, int Sessions);

    internal sealed record ClassItem(int ClassId, string Level, string Class, string? Teacher, IReadOnlyList<CellItem> Weeks);

    internal sealed record Answer(int Gender, string From, string To, IReadOnlyList<string> Levels, IReadOnlyList<WeekItem> Weeks, IReadOnlyList<ClassItem> Classes);

    private sealed record ClassRow(int Id, string Level, string Code, string? TeacherName);

    private sealed record SessionRow(int ClassId, DateOnly ConductedOn, int Conducted);

    public static IEndpointRouteBuilder MapReportWeekly(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/reports/weekly", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, ClassesContext db, Permissions permissions, TimeProvider clock, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var (scope, refusal) = await ReportScope.OpenAsync(context, permissions, caller, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var today = DateOnly.FromDateTime(clock.GetUtcNow().UtcDateTime);
        var from = ReportMonths.Param(context, "from") ?? today.ToString("MM-yyyy", CultureInfo.InvariantCulture);
        var to = ReportMonths.Param(context, "to") ?? from;
        var invalid = ReportMonths.Check(from, to, limitToTwelve: true);
        if (invalid is not null)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, invalid);
        }

        var ids = await scope!.ClassIdsAsync(db, 0, ct);
        var assigned = (await permissions.ReachAsync(caller, "classes:read", ct)).AssignedOnlyIds;
        if (assigned is not null)
        {
            ids = [.. ids.Intersect(assigned)];
        }

        var classes = await ClassesAsync(db, ids, ct);
        var (start, end) = ReportCalendar.Window(from, to, today);
        var sessions = await SessionsAsync(db, ids, start, end, ct);
        var months = WeeklyGrid.Months(start, end);

        var level = ReportScope.LevelOf(context);
        var items = classes
            .Where(c => level.Length == 0 || c.Level == level)
            .Select(c => ToItem(c, sessions.GetValueOrDefault(c.Id) ?? [], months))
            .ToList();
        return Results.Json(new Answer(scope.Gender, from, to, [.. classes.Select(c => c.Level).Distinct()], WeekItems(months), items));
    }

    // PHP getAll: the class's level must exist (inner join), the teacher's name may be missing (left join); order gender, level order, id.
    private static async Task<List<ClassRow>> ClassesAsync(ClassesContext db, int[] ids, CancellationToken ct) =>
        await db.Database
            .SqlQuery<ClassRow>($"""
                select c.id as "Id", cl.name::text as "Level", c.code::text as "Code", u.name::text as "TeacherName"
                from classes.classes c
                join classes.class_levels cl on cl.id = c.class_level_id
                left join membership.v_members u on u.token = c.teacher
                where c.id = any({ids})
                order by c.gender, cl.sort_order, c.id
                """)
            .ToListAsync(ct);

    // PHP details(): the sessions of the window of classes whose level and teacher exist; one flag per class and day, the later session wins.
    private static async Task<Dictionary<int, Dictionary<DateOnly, int>>> SessionsAsync(ClassesContext db, int[] ids, DateOnly start, DateOnly end, CancellationToken ct)
    {
        var rows = await db.Database
            .SqlQuery<SessionRow>($"""
                select s.class_id as "ClassId", s.conducted_on as "ConductedOn", s.conducted::int as "Conducted"
                from classes.class_sessions s
                join classes.classes c on c.id = s.class_id
                join classes.class_levels cl on cl.id = c.class_level_id
                join membership.v_members t on t.token = c.teacher
                where s.conducted_on >= {start} and s.conducted_on <= {end} and c.id = any({ids})
                order by s.id
                limit {MaxSessions}
                """)
            .ToListAsync(ct);
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

    private static ClassItem ToItem(ClassRow c, Dictionary<DateOnly, int> conducted, IReadOnlyList<WeeklyGrid.Month> months)
    {
        var cells = months
            .SelectMany(m => m.Weeks)
            .Select(days => WeeklyGrid.Read(WeeklyGrid.CellOf(conducted, days)))
            .Select(cell => new CellItem(cell.Status, cell.Sessions))
            .ToList();
        return new ClassItem(c.Id, c.Level, c.Code, PhpCast.StrOrNull(c.TeacherName), cells);
    }

    private static List<WeekItem> WeekItems(IReadOnlyList<WeeklyGrid.Month> months) =>
    [
        .. months.SelectMany(m => m.Weeks.Select((days, i) =>
            new WeekItem(m.Label, "Wk " + (i + 1).ToString(CultureInfo.InvariantCulture), Day(days[0]), Day(days[^1])))),
    ];

    private static string Day(DateOnly day) => day.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
}
