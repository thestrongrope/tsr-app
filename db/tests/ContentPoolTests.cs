using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Npgsql;
using NUnit.Framework;
using Tsr.Content.Api;
using Tsr.Content.Api.Workers;
using Tsr.Shared.Api;

namespace Tsr.Db.Tests;

/// <summary>
/// Issue 100, CON-Q1: no path of content holds two connections of the data source at once, so no number of requests or copies can starve the pool by waiting on itself.
/// Proved with a pool of one: a path that needed a second connection would wait for the first, which it holds itself, and fail at the 5 s timeout.
/// Paths covered: every route (the six Library reads, the surah list, the stub list), the copy's store path (state read, then the transaction),
/// its keep and unchanged paths, and <see cref="ContentModule.LoadContentAsync"/>.
/// </summary>
public sealed class ContentPoolTests
{
    public static IEnumerable<string> Routes => ContentGoldenScenarios.Library.Keys.Concat(ContentGoldenScenarios.Others.Keys);

    [TestCaseSource(nameof(Routes))]
    public async Task Every_content_route_answers_with_a_pool_of_one_connection(string scenario)
    {
        await using var run = await StartAsync(scenario);

        await (ContentGoldenScenarios.Library.TryGetValue(scenario, out var route) ? route(run) : ContentGoldenScenarios.Others[scenario](run));

        run.AssertNoServerError();
    }

    [Test]
    public async Task A_copy_stores_its_set_with_a_pool_of_one_connection()
    {
        await using var run = await StartAsync(ContentGolden.CopyStoresRows);

        await ContentGolden.StoreAndRecordAsync(run);
    }

    [Test]
    public async Task The_keep_and_unchanged_paths_finish_with_a_pool_of_one_connection()
    {
        await using var run = await StartAsync(ContentGolden.CopyKeepPaths);

        await ContentGolden.KeepAndRecordAsync(run);
    }

    [Test]
    public async Task The_deploy_load_finishes_with_a_pool_of_one_connection()
    {
        await using var run = await StartAsync("load");
        await run.ExecuteAsync("truncate content.published_articles, content.categories, content.publications, content.refresh_state");
        await using var services = LoadServices(run.Services);

        var first = await ContentModule.LoadContentAsync(services, CancellationToken.None);
        var second = await ContentModule.LoadContentAsync(services, CancellationToken.None);

        Assert.Multiple(async () =>
        {
            Assert.That(first, Is.True, "the first load stores the synthetic files");
            Assert.That(second, Is.True, "the second finds the database already holding them");
            Assert.That(await run.QueryAsync("select count(*)::text from content.published_articles"), Is.Not.EqualTo(new List<string> { "0" }));
            Assert.That(await run.QueryAsync("select count(*)::text from content.refresh_state"), Is.EqualTo(new List<string> { "1" }));
        });
    }

    private static Task<GoldenScenario> StartAsync(string scenario) =>
        GoldenScenario.StartAsync("pool-" + scenario, services => services.AddSingleton<NpgsqlDataSource>(OnePooledConnection), ContentGolden.Set);

    // The load resolves only the data source, the configuration, the clock and a logger factory, so it runs on a container of just those.
    private static ServiceProvider LoadServices(IServiceProvider host)
    {
        var services = new ServiceCollection();
        services.AddLogging();
        services.AddSingleton(TimeProvider.System);
        services.AddSingleton<NpgsqlDataSource>(_ => OnePooledConnection(host));
        services.AddSingleton<IConfiguration>(new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?> { [ContentRefreshWorker.DirectorySetting] = ContentGolden.SyntheticDirectory })
            .Build());
        return services.BuildServiceProvider();
    }

    // Pooling on (the scenario databases are reached with it off) and the shared source's 5 s timeouts, with a pool of one.
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
