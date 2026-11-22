using System.Data.Common;
using System.Globalization;
using System.Text;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Npgsql;
using Tsr.Content.Api;
using Tsr.Content.Api.Domain;

namespace Tsr.Db.Tests;

/// <summary>
/// The golden set-up of content's characterisation tests (issue 100, plan "Golden files"): the template <c>content_golden_template</c>, migrated as production and seeded
/// with the synthetic content set (copied by today's refresh at the fixed instant), three surahs, four stub articles and one member, and the one call of a content copy
/// that the new tests make. A scenario is <see cref="GoldenScenario"/> on <see cref="Set"/>.
/// </summary>
internal static class ContentGolden
{
    /// <summary>A member who can sign in to the surah list: token 900001 or more, an email on .invalid.</summary>
    public const int Member = 900001;

    /// <summary>The seeded surah with Arabic marks, one with no Arabic name, and one with a non-ASCII name holding characters JSON may escape.</summary>
    public const string OddSurahName = "Ünï Sûra \"Q\" <b> + &amp;";

    public static GoldenSet Set { get; } = new(
        "content",
        "content_golden_template",
        SeedAsync,
        [
            "content.published_articles|select row_to_json(t)::text from content.published_articles t order by t.slug collate \"C\"",
            "content.categories|select row_to_json(t)::text from content.categories t order by t.slug collate \"C\"",
            "content.publications|select row_to_json(t)::text from content.publications t order by t.position",
            "content.refresh_state|select row_to_json(t)::text from content.refresh_state t order by t.id",
        ],
        null);

    /// <summary>The synthetic content files of the repository (db/synthetic/content).</summary>
    public static string SyntheticDirectory => Path.Combine(TestDatabase.RepoRoot(), "db", "synthetic", "content");

    /// <summary>
    /// One content copy over <paramref name="directory"/>, as the worker and the deploy job make it: a new scope of <paramref name="services"/>, no log.
    /// This is the one call of the copy in the golden tests; the issue's task 9 changes its argument from the context to the data source.
    /// </summary>
    public static async Task<RefreshOutcome> TickAsync(IServiceProvider services, string? directory, TimeProvider clock, Func<CancellationToken, Task>? beforeCommit = null)
    {
        await using var scope = services.CreateAsyncScope();
        return await ContentRefresh.TickAsync(
            scope.ServiceProvider.GetRequiredService<ContentContext>(), directory, clock, NullLogger.Instance, beforeCommit, CancellationToken.None);
    }

    /// <summary>What a copy answered, as a transcript line.</summary>
    public static string Describe(RefreshOutcome outcome) => outcome.Cause is null ? outcome.Result.ToString() : outcome.Result + ": " + outcome.Cause;

    /// <summary>A clock that always reads <paramref name="minutes"/> minutes after the scenarios' fixed instant.</summary>
    public static TimeProvider ClockAfter(int minutes) => new At(DateTimeOffset.Parse(GoldenScenario.Instant, CultureInfo.InvariantCulture).AddMinutes(minutes));

    /// <summary>Copies the synthetic content files into <paramref name="files"/>, so a test can change one.</summary>
    public static void CopySyntheticInto(ContentTestFiles files)
    {
        foreach (var path in Directory.EnumerateFiles(SyntheticDirectory, "*.md", SearchOption.AllDirectories).Order(StringComparer.Ordinal))
        {
            var folder = Path.GetFileName(Path.GetDirectoryName(path))!;
            if (string.Equals(Path.GetDirectoryName(path), SyntheticDirectory, StringComparison.Ordinal))
            {
                continue;
            }

            files.Write(folder, Path.GetFileName(path), File.ReadAllText(path));
        }
    }

    /// <summary>The exception and everything it wraps, outermost first.</summary>
    public static IEnumerable<Exception> Chain(Exception failure)
    {
        for (var next = failure; next is not null; next = next.InnerException)
        {
            yield return next;
        }
    }

    /// <summary>
    /// What a failed call is written as in a golden file: that it threw, and the SqlState of the database error inside it. Never the exception's type, which the conversion is allowed to change;
    /// a failure with no database error inside it is an assertion failure of the caller, so it is written as such.
    /// </summary>
    public static string DescribeFailure(Exception failure)
    {
        var database = Chain(failure).OfType<PostgresException>().FirstOrDefault();
        return database is null ? "threw, with no database error inside" : "threw, database error " + database.SqlState;
    }

    /// <summary>Whether a database error (a <see cref="DbException"/>) is somewhere in the failure.</summary>
    public static bool HoldsDatabaseError(Exception failure) => Chain(failure).Any(e => e is DbException);

    private static async Task SeedAsync(string ownerConnection)
    {
        var sql = new StringBuilder();
        sql.Append(CultureInfo.InvariantCulture, $"insert into identity.users (token, email, firebase_uid) values ({Member}, '{MembershipTestKit.EmailOf(Member)}', 'uid-{Member}'); ");
        sql.Append(CultureInfo.InvariantCulture, $"insert into membership.member_profiles (user_id, name, gender) select id, 'Gold Reader', '1' from identity.users where token = {Member}; ");
        sql.Append("delete from content.holy_quran; ");
        sql.Append("insert into content.holy_quran (id, surah, arabic, verses) values ");
        sql.Append("(1, 'Al-Fatiha', 'ٱلْفَاتِحَة', 7), (2, 'Al-Baqara', null, 286), ");
        sql.Append(CultureInfo.InvariantCulture, $"(3, {MembershipTestKit.Quote(OddSurahName)}, 'آلِ عِمْرَان', 200); ");
        // Two published at the same instant (the id breaks the tie), one not yet, one never: the rule of the old list is in its query.
        sql.Append("delete from content.articles; ");
        sql.Append("insert into content.articles (slug, title, body, published_at) values ");
        sql.Append("('stub-old', 'Stub Old', 'Invented body of the old stub.', timestamptz '2025-12-31 23:59:59+00'), ");
        sql.Append("('stub-twin', 'Stub Twin', E'Twin body with <angle brackets>, a plus + and a quote \" and Ünï.', timestamptz '2025-12-31 23:59:59+00'), ");
        sql.Append("('stub-future', 'Stub Future', 'Not yet.', timestamptz '2026-01-01 00:00:01+00'), ");
        sql.Append("('stub-draft', 'Stub Draft', 'Never.', null);");
        await using (var connection = new NpgsqlConnection(ownerConnection))
        {
            await connection.OpenAsync();
            await using var command = new NpgsqlCommand(sql.ToString(), connection);
            await command.ExecuteNonQueryAsync();
        }

        await CopySyntheticSetAsync(ownerConnection);
    }

    // The copy is made by today's refresh, through a host on the template as the limited role. Nothing may stay connected to the template afterwards: "create database ... template" needs it idle.
    private static async Task CopySyntheticSetAsync(string ownerConnection)
    {
        var template = new NpgsqlConnectionStringBuilder(ownerConnection).Database!;
        var app = GoldenScenario.ConnectionTo(template, TestDatabase.AppConnection);
        await using (var factory = TestApi.Create(app))
        {
            _ = factory.Server;
            var outcome = await TickAsync(factory.Services, SyntheticDirectory, GoldenScenario.Clock);
            if (outcome.Result != RefreshResult.Refreshed)
            {
                throw new InvalidOperationException("The synthetic content set was not copied into the golden template: " + Describe(outcome));
            }
        }

        NpgsqlConnection.ClearAllPools();
    }

    private sealed class At(DateTimeOffset now) : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => now;
    }
}
