using System.Globalization;
using System.Text.Json.Nodes;
using Microsoft.AspNetCore.Http;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Domain;

/// <summary>
/// What the quiz competition admin slices share (PHP QuizAdminModel's seams and guards, models/quizadmin.php:~150-330 and ~520-600): the caller guard, the settings and the pre-checks every action makes,
/// the wall clock and stamps, the member data the eligibility reads, and the one outbox event per change. A change runs in one transaction under advisory lock <see cref="AssessmentLocks.QuizAdmin"/> (PHP's <c>quiz_admin</c> named lock).
/// </summary>
internal static class QuizAdmin
{
    /// <summary>PHP's `timeoffset` setting is IST in production (models/quizadmin.php:~205 comment): stamps and the sheet's "last updated" line use this wall clock.</summary>
    private static readonly TimeSpan WallOffset = TimeSpan.FromMinutes(330);

    private const int UserChunk = 100;
    private const int MaxStudents = 200_000;

    /// <summary>PHP api_authenticate + api_require('quiz:admin'): 401 or 403, else the caller.</summary>
    public static async Task<(Caller? Caller, IResult? Refusal)> GuardAsync(HttpContext context, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return (null, Problem.Unauthenticated());
        }

        return await permissions.CanAsync(caller, "quiz:admin", AccessTarget.None, ct)
            ? (caller, null)
            : (null, Refusals.NotPermitted());
    }

    public static IResult Busy() => Problem.Detail(StatusCodes.Status409Conflict, "Another quiz admin action is running. Try again in a moment.");

    /// <summary>The quiz settings document; empty settings when none was ever read. Never fetches (PHP settings()).</summary>
    public static async Task<QuizSettings> SettingsAsync(NpgsqlDataSource source, CancellationToken ct)
    {
        await using var tx = await source.BeginAsync(ct);
        return new QuizSettings(await QuizStateStore.LoadObjectAsync(tx, QuizStateStore.Settings, ct));
    }

    /// <summary>PHP requireSettings: 409 until the settings sheet was read once (and it asks for a number of episodes the sheets can serve).</summary>
    public static IResult? RequireSettings(QuizSettings settings)
    {
        if (!settings.Loaded)
        {
            return Problem.Detail(StatusCodes.Status409Conflict, "The quiz settings have not been loaded yet. Refresh them first.");
        }

        return settings.TotalQuizzes is < 1 or > QuizSettings.MaxEpisodes
            ? Problem.Detail(StatusCodes.Status409Conflict, $"The quiz settings need between 1 and {QuizSettings.MaxEpisodes} episodes.")
            : null;
    }

    /// <summary>The acting member as stamped: "Name (token)" (PHP actorLabel; the name is the member's profile name).</summary>
    public static async Task<string> ActorLabelAsync(DbTx tx, Caller caller, CancellationToken ct)
    {
        var token = caller.Token;
        var names = await tx.ListAsync($"""select coalesce(name, '') as "Value" from membership.v_members where token = {token}""", row => row.Text("Value"), ct);
        return (names.Count == 0 ? string.Empty : names[0]) + " (" + token.ToString(CultureInfo.InvariantCulture) + ")";
    }

    /// <summary>PHP get_current_time(): the wall clock (IST).</summary>
    public static DateTimeOffset Wall(TimeProvider clock) => clock.GetUtcNow().ToOffset(WallOffset);

    /// <summary>PHP nowOrOverride: the <c>today_override</c> setting when it is a date, else the wall clock. An override that is not a date is ignored (PHP would fail with a 500).</summary>
    public static DateTimeOffset NowOrOverride(QuizSettings settings, TimeProvider clock) => OverrideDate(settings) ?? Wall(clock);

    /// <summary>A date text of the settings (an episode's start and stop, the registration, the quiz stop, today_override) as PHP's new DateTime reads it for the formats the sheet holds.</summary>
    public static DateTimeOffset? ParseSettingsDate(string? text) =>
        !string.IsNullOrEmpty(text) && DateTimeOffset.TryParse(text, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out var date) ? date : null;

    /// <summary>The <c>today_override</c> setting as a date (+00:00 unless it carries an offset), or null when it is absent or not a date.</summary>
    public static DateTimeOffset? OverrideDate(QuizSettings settings) => ParseSettingsDate(settings.Str("today_override"));

    /// <summary>The wall clock's numbers labelled +00:00: how PHP's get_current_time() compares with dates read as UTC (it adds the offset and keeps the UTC label).</summary>
    public static DateTimeOffset WallLabelledUtc(TimeProvider clock) => new(Wall(clock).DateTime, TimeSpan.Zero);

    /// <summary>PHP stampFrom: ISO 8601 with the time's own offset (+05:30 for the wall clock, +00:00 for an override date).</summary>
    public static string Stamp(DateTimeOffset time) => time.ToString("yyyy-MM-dd'T'HH:mm:sszzz", CultureInfo.InvariantCulture);

    /// <summary>One outbox event per change: the action name only.</summary>
    public static Task EventAsync(DbTx tx, string action, TimeProvider clock, CancellationToken ct) =>
        Outbox.WriteAsync(tx, "assessment.quiz_state_changed", new QuizStateChanged(action), AssessmentJson.Default.QuizStateChanged, clock, ct);

    /// <summary>PHP feasibility() I/O wrapper: the downloaded participants, their member data (in chunks) and the enrolled students, through the rules of <see cref="QuizEligibility"/>.</summary>
    public static async Task<Feasibility> FeasibilityAsync(DbTx tx, QuizSettings settings, CancellationToken ct)
    {
        var days = ParticipantsOf(await QuizStateStore.LoadObjectAsync(tx, QuizStateStore.Participants, ct), settings.TotalQuizzes);
        var users = await UsersAsync(tx, days, settings, ct);
        var feasibility = QuizEligibility.Compute(days, users, settings);
        await tx.ExecuteAsync($"savepoint quiz_students", ct);
        try
        {
            var students = await StudentsAsync(tx, ct);
            return QuizEligibility.WithStudents(feasibility, students);
        }
        catch (System.Data.Common.DbException)
        {
            await tx.ExecuteAsync($"rollback to savepoint quiz_students", ct);
            return QuizEligibility.WithoutStudents(feasibility);
        }
    }

    public static IReadOnlyDictionary<int, List<Submission>> ParticipantsOf(JsonObject document, int total)
    {
        var days = new Dictionary<int, List<Submission>>();
        for (var day = 1; day <= total; day++)
        {
            var list = document[day.ToString(CultureInfo.InvariantCulture)] as JsonArray ?? [];
            days[day] = list.OfType<JsonObject>().Select(s => new Submission(QuizOverview.Text(s["token"]) ?? string.Empty, QuizOverview.Text(s["score"]) ?? string.Empty)).ToList();
        }

        return days;
    }

    /// <summary>The scoreboard's name and city per token (PHP participantInfo / readScoreboard).</summary>
    public static async Task<IReadOnlyDictionary<int, ParticipantInfo>> ParticipantInfoAsync(DbTx tx, CancellationToken ct)
    {
        var info = new Dictionary<int, ParticipantInfo>();
        foreach (var row in (await QuizStateStore.LoadArrayAsync(tx, QuizStateStore.Scoreboard, ct)).OfType<JsonArray>().Where(r => r.Count > 3))
        {
            var token = (int)Math.Clamp(PhpValue.IntOfText(QuizOverview.Text(row[1]) ?? string.Empty), int.MinValue, int.MaxValue);
            info[token] = new ParticipantInfo(QuizOverview.Text(row[2]), QuizOverview.Text(row[3]));
        }

        return info;
    }

    private sealed record UserRow(int Token, string? Name, string? City, string? Country);

    private static async Task<IReadOnlyDictionary<int, Member>> UsersAsync(
        DbTx tx, IReadOnlyDictionary<int, List<Submission>> days, QuizSettings settings, CancellationToken ct)
    {
        var tokens = days.Values.SelectMany(d => d).Select(s => (int)Math.Clamp(PhpValue.IntOfText(s.Token), int.MinValue, int.MaxValue)).Distinct().ToArray();
        var users = new Dictionary<int, Member>();
        var chunk = settings.Str("validation_chunks") is null ? UserChunk : (int)Math.Clamp(settings.Int("validation_chunks"), 1, 1000);
        foreach (var part in tokens.Chunk(chunk))
        {
            var rows = await tx.ListAsync(
                $"""
                select token as "Token", name as "Name", city as "City", country as "Country"
                from membership.v_members where token = any({part}) and token <> 0
                """,
                row => new UserRow(row.Int("Token"), row.TextOrNull("Name"), row.TextOrNull("City"), row.TextOrNull("Country")),
                ct);
            foreach (var row in rows)
            {
                users[row.Token] = new Member(row.Name ?? string.Empty, row.City ?? string.Empty, row.Country ?? string.Empty);
            }
        }

        return users;
    }

    /// <summary>PHP enrolledStudents: members enrolled in an active class and not removed.</summary>
    private static async Task<IReadOnlySet<int>> StudentsAsync(DbTx tx, CancellationToken ct) =>
        (await tx.ListAsync(
            $"""
            select distinct e.token_no as "Value" from classes.v_enrolments e
            join classes.v_classes c on c.id = e.class_id
            where c.status = 'A' and e.removed_at is null limit {MaxStudents}
            """,
            row => row.Int("Value"),
            ct)).ToHashSet();
}
