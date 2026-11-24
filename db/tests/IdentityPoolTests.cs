using System.Globalization;
using System.Net;
using Microsoft.Extensions.DependencyInjection;
using Npgsql;
using NUnit.Framework;
using Tsr.Shared.Api;

namespace Tsr.Db.Tests;

/// <summary>
/// Issue 102, IDN-Q1 (TC-IDN-Q1-01): no path of identity holds two connections of the data source at once, so no request of any domain can starve the pool by waiting on itself.
/// Proved with a pool of one: a path that needed a second connection would wait for the first, which it holds itself, and fail at the 5 s timeout.
/// Paths covered: every golden scenario (the nine routes and their refusals, the seven deletion writes including the three completions, the sign-in outcomes and the sign-in writes:
/// lookup, claim, first sign-in, tracking), and the race re-read of a first sign-in whose insert meets a member made meanwhile.
/// </summary>
public sealed class IdentityPoolTests
{
    private const string WaitingForTokenLock =
        "select count(*) from pg_locks where locktype = 'advisory' and objid = 7100001 and not granted and database = (select oid from pg_database where datname = current_database())";

    public static IEnumerable<string> Scenarios => IdentityGoldenScenarios.Routes.Keys
        .Concat(IdentityGoldenScenarios.Writes.Keys)
        .Concat(IdentityGoldenScenarios.SignInOutcomes.Keys)
        .Concat(IdentityGoldenScenarios.SignInWrites.Keys);

    [TestCaseSource(nameof(Scenarios))]
    public async Task Every_identity_route_and_sign_in_works_with_a_pool_of_one_connection(string scenario)
    {
        await using var run = await StartAsync(scenario);

        await Scenario(scenario)(run);

        GoldenScenario.Check(scenario, run.Transcript, IdentityGolden.Set);
    }

    // The one path no golden reaches in one request at a time: the insert of a first sign-in hits the unique uid because another request made the member meanwhile.
    // The test makes the member itself while the request waits at the token lock, so the request rolls back, releases its connection, and re-reads on a fresh one.
    [Test]
    public async Task A_first_sign_in_that_meets_a_member_made_meanwhile_re_reads_with_a_pool_of_one_connection()
    {
        await using var run = await StartAsync("race-reread");
        var headers = IdentityGoldenScenarios.Headers("uid-pool-race", "pool.race@example.invalid", true, IdentitySeed.Odd, "https://img.invalid/pool-race");
        await using var holder = await run.Run.OpenOwnerConnectionAsync();
        await ExecuteAsync(holder, "select pg_advisory_lock(7100001)");

        var send = run.SendAsync("uid-pool-race", headers, HttpMethod.Post, "/auth/link");
        try
        {
            await WaitForOneWaiterAsync(run);
            await run.Run.ExecuteAsync(
                "insert into identity.users (token, email, firebase_uid, provider) select max(token) + 1, 'pool.race@example.invalid', 'uid-pool-race', 'firebase' from identity.users");
        }
        finally
        {
            await ExecuteAsync(holder, "select pg_advisory_unlock(7100001)");
        }

        var reply = await send;

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        Assert.That(await run.Run.QueryAsync("select count(*) from identity.users where firebase_uid = 'uid-pool-race'"), Is.EqualTo(["1"]));
    }

    private static Func<IdentityRun, Task> Scenario(string name) =>
        IdentityGoldenScenarios.Routes.TryGetValue(name, out var route) ? route
        : IdentityGoldenScenarios.Writes.TryGetValue(name, out var write) ? write
        : IdentityGoldenScenarios.SignInOutcomes.TryGetValue(name, out var outcome) ? outcome
        : IdentityGoldenScenarios.SignInWrites[name];

    private static Task<IdentityRun> StartAsync(string scenario) =>
        IdentityRun.StartAsync("pool-" + scenario, services => services.AddSingleton<NpgsqlDataSource>(OnePooledConnection));

    private static async Task WaitForOneWaiterAsync(IdentityRun run)
    {
        for (var tries = 0; tries < 100; tries++)
        {
            if (int.Parse((await run.Run.QueryAsync(WaitingForTokenLock)).Single(), CultureInfo.InvariantCulture) >= 1)
            {
                return;
            }

            await Task.Delay(50);
        }

        Assert.Fail("the request was to wait for the token lock within 5 seconds");
    }

    private static async Task ExecuteAsync(NpgsqlConnection connection, string sql)
    {
        await using var command = new NpgsqlCommand(sql, connection);
        await command.ExecuteNonQueryAsync();
    }

    // Pooling on (the golden databases are reached with it off) and the shared source's 5 s timeouts, with a pool of one.
    private static NpgsqlDataSource OnePooledConnection(IServiceProvider services)
    {
        var connection = new NpgsqlConnectionStringBuilder(services.GetRequiredService<DbSettings>().ConnectionString)
        {
            Pooling = true,
            MaxPoolSize = 1,
            Timeout = 5,
            CommandTimeout = 5,
        };
        return new NpgsqlSlimDataSourceBuilder(connection.ConnectionString).EnableArrays().EnableTransportSecurity().Build();
    }
}
