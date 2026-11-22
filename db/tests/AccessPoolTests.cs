using Microsoft.Extensions.DependencyInjection;
using Npgsql;
using NUnit.Framework;
using Tsr.Shared.Api;

namespace Tsr.Db.Tests;

/// <summary>
/// Issue 99, ACC-Q1: no request of access holds two connections of the data source at once, so no number of requests can starve the pool by waiting on itself.
/// Proved with a pool of one: a request that needed a second connection would wait for the first, which it holds itself, and fail at the 5 s timeout.
/// Entity Framework keeps its own pool (the unconverted parts of access, and the classes port); only the data source is cut to one connection.
/// </summary>
public sealed class AccessPoolTests
{
    public static IEnumerable<string> Scenarios => AccessGoldenScenarios.Routes.Keys.Concat(AccessGoldenScenarios.Writes.Keys);

    [TestCaseSource(nameof(Scenarios))]
    public async Task Every_access_route_answers_with_a_pool_of_one_connection(string scenario)
    {
        await using var run = await GoldenScenario.StartAsync("pool-" + scenario, services => services.AddSingleton<NpgsqlDataSource>(OnePooledConnection));

        await (AccessGoldenScenarios.Routes.TryGetValue(scenario, out var route) ? route(run) : AccessGoldenScenarios.Writes[scenario](run));

        GoldenScenario.Check(scenario, run.Transcript);
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
