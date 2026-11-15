using System.Globalization;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

// PHP's recitation leaderboard (QuranRecitationModel::getLeaderboardData, quranrecitation.php:17), shared by the students report (domain/StudentsReport.cs: its recitation column) and the leaderboard route and its download
// (GET /reports/quran-leaderboard, reports.php api_require_quran_leaderboard :1588). Every attendance mark of the range (held or not, any class, any gender, any level) is summed per token and RANKED (RANK(): ties share a rank), THEN the
// rows are limited to enrolments with status 'A' in an active class, to the level asked for, to the members whose own stored gender is the asked one, to the assigned classes when that is all the caller's reports:read reaches, and to
// totals of at least the minimum; so ranks are global. Copied: a member in two active classes is listed twice with the same rank; no demo-class exclusion; the enrolment's removed_at is not looked at (status only).
// Deviation: at most MaxRows rows when no limit is asked for (PHP has none); ties are ordered by token then class id (PHP: by the database).

internal static partial class QuranLeaderboard
{
    public const int TopRows = 100;

    public const int MaxRows = 50_000;

    public const string TooLong = "The range can cover at most five years";

    private const int MostDays = 5 * 366;

    internal sealed record Row(long Token, string? Name, string Class, long Total, long Rank, long Count);

    internal sealed record Loaded(int Gender, string From, string To, IReadOnlyList<string> Levels, long Total, IReadOnlyList<Row> Rows);

    private sealed record LevelRow(int Id, string Name);

    // PHP filter_var(FILTER_VALIDATE_INT): an optional sign and digits without a leading zero; [0-9], not \d.
    [GeneratedRegex("^[+-]?(0|[1-9][0-9]*)$")]
    private static partial Regex WholeNumber();

    /// <summary>PHP normaliseMinimum: the whole numbers from 0 up are kept; blank, negative, fractional, too large or non-numeric is 1.</summary>
    public static long Minimum(string? raw)
    {
        var text = PhpText.Trim(raw ?? string.Empty);
        if (!WholeNumber().IsMatch(text) || !long.TryParse(text, NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture, out var value))
        {
            return 1;
        }

        return value < 0 ? 1 : value;
    }

    /// <summary>PHP's date checks of the leaderboard: to defaults to today, from to a year before to (strtotime '-1 year': 29 February becomes 1 March); real days, from not after to, at most 5 x 366 days apart.</summary>
    public static (DateRange? Range, string? Refusal) CheckRange(string? from, string? to, DateOnly today)
    {
        to ??= today.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
        var toDay = ReportDates.ParseDay(to);
        if (toDay is null)
        {
            return (null, ReportDates.NotDates);
        }

        var fromDay = from is null ? YearBefore(toDay.Value) : ReportDates.ParseDay(from);
        if (fromDay is null)
        {
            return (null, ReportDates.NotDates);
        }

        from ??= fromDay.Value.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
        if (string.CompareOrdinal(from, to) > 0)
        {
            return (null, ReportDates.NotDates);
        }

        return toDay.Value.DayNumber - fromDay.Value.DayNumber > MostDays
            ? (null, TooLong)
            : (new DateRange(from, to, fromDay.Value, toDay.Value), null);
    }

    private static DateOnly? YearBefore(DateOnly day)
    {
        if (day.Year <= 1)
        {
            return null;
        }

        return day is { Month: 2, Day: 29 } ? new DateOnly(day.Year - 1, 3, 1) : day.AddYears(-1);
    }

    /// <summary>
    /// PHP api_require_quran_leaderboard, in its order: the gender (locked by quran-leaderboard:read, else the one asked for), that permission for the gender (403), the dates (422), the level by name (422 "Unknown level"), then the rows
    /// (<paramref name="limit"/> null: every ranked row). The caller is signed in already.
    /// </summary>
    public static async Task<(Loaded? Report, IResult? Refusal)> OpenAsync(
        HttpContext context, ClassesContext db, Permissions permissions, Caller caller, DateOnly today, int? limit, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(context);
        ArgumentNullException.ThrowIfNull(permissions);
        ArgumentNullException.ThrowIfNull(caller);
        var reach = await permissions.ReachAsync(caller, "quran-leaderboard:read", ct);
        var asked = context.Request.Query["gender"];
        var gender = ReportScope.GenderOf(reach.GenderLock, asked.Count == 0 ? null : asked[^1]);
        if (!await permissions.CanAsync(caller, "quran-leaderboard:read", AccessTarget.ForGender(gender), ct))
        {
            return (null, Refusals.NotPermitted());
        }

        var (range, invalid) = CheckRange(ReportMonths.Param(context, "from"), ReportMonths.Param(context, "to"), today);
        if (invalid is not null)
        {
            return (null, Problem.Detail(StatusCodes.Status422UnprocessableEntity, invalid));
        }

        var levels = await LevelsAsync(db, ct);
        var level = ReportScope.LevelOf(context);
        var levelId = 0;
        if (level.Length > 0)
        {
            var found = levels.FirstOrDefault(l => string.Equals(l.Name, level, StringComparison.Ordinal));
            if (found is null)
            {
                return (null, Problem.Detail(StatusCodes.Status422UnprocessableEntity, "Unknown level"));
            }

            levelId = found.Id;
        }

        var minimum = Minimum(ReportMonths.Param(context, "minimum"));
        var assigned = (await permissions.ReachAsync(caller, "reports:read", ct)).AssignedOnlyIds;
        var rows = await RankedAsync(db, gender, assigned, range!, levelId, minimum, limit, ct);
        return (new Loaded(gender, range!.From, range.To, [.. levels.Select(l => l.Name)], rows.Count == 0 ? 0 : rows[0].Count, rows), null);
    }

    /// <summary>
    /// The query: the ranking, then the enrolments. <paramref name="levelId"/> 0 is every level; <paramref name="assigned"/> null is no class limit (PHP assignedOnlyIds of reports:read; an empty list shows nothing);
    /// <paramref name="limit"/> null is every row (at most <see cref="MaxRows"/>). Each row carries the count before the limit (PHP SQL_CALC_FOUND_ROWS).
    /// </summary>
    public static async Task<List<Row>> RankedAsync(
        ClassesContext db, int gender, IReadOnlyList<int>? assigned, DateRange range, int levelId, long minimum, int? limit, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(db);
        ArgumentNullException.ThrowIfNull(range);
        var from = range.FromDay;
        var to = range.ToDay;
        var genderText = gender.ToString(CultureInfo.InvariantCulture);
        var limited = assigned is not null;
        int[] assignedIds = assigned is null ? [] : [.. assigned];
        var rows = limit ?? MaxRows;
        return await db.Database
            .SqlQuery<Row>($"""
                with ranked as (
                    select ca.token, sum(ca.recitation) as total, rank() over (order by sum(ca.recitation) desc) as rnk
                    from classes.class_attendance ca
                    join classes.class_sessions s on s.id = ca.session_id
                    where s.conducted_on between {from} and {to}
                    group by ca.token)
                select ra.token::bigint as "Token", u.name::text as "Name", c.code::text as "Class", ra.total::bigint as "Total", ra.rnk::bigint as "Rank",
                       count(*) over () as "Count"
                from ranked ra
                join classes.class_students cs on cs.token_no = ra.token
                join classes.classes c on c.id = cs.class_id
                join membership.v_members u on u.token = ra.token
                where cs.status = 'A' and c.status = 'A' and u.gender = {genderText}
                  and ({levelId} = 0 or c.class_level_id = {levelId})
                  and ({limited} = false or c.id = any({assignedIds}))
                  and ra.total >= {minimum}
                order by ra.rnk, ra.token, c.id
                limit {rows}
                """)
            .ToListAsync(ct);
    }

    // PHP ClassesModel::getLevels (id to name, in listLevels order): the levels by sort order.
    private static async Task<List<LevelRow>> LevelsAsync(ClassesContext db, CancellationToken ct) =>
        await db.Database
            .SqlQuery<LevelRow>($"""select id as "Id", name::text as "Name" from classes.class_levels order by sort_order, id limit 1000""")
            .ToListAsync(ct);
}
