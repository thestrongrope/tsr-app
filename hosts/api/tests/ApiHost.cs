using System.Collections.Concurrent;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;

namespace Tsr.Host.Api.Tests;

/// <summary>
/// The API in-process, for tests that need no database: sign-in is the real verifier (a request without a token
/// is refused before any lookup), and the database setting points nowhere. It records which route pattern each request
/// resolved to, so a test can see which of two overlapping routes won.
/// </summary>
internal sealed class ApiHost : IDisposable
{
    private readonly ConcurrentDictionary<string, string?> resolved = new();
    private readonly WebApplicationFactory<Program> factory;

    public ApiHost()
    {
        var record = resolved;
        factory = new WebApplicationFactory<Program>().WithWebHostBuilder(builder =>
        {
            builder.UseSetting("TSR_DB", "Host=unused");
            builder.UseSetting("TSR_FIREBASE_PROJECT_ID", "demo-tsr-test");
            builder.UseSetting("TSR_AUTH_EMULATOR_HOST", "localhost:9099");
            builder.UseSetting("TSR_GOTENBERG_URL", "http://gotenberg.invalid:3000");
            builder.ConfigureServices(services => services.AddSingleton<IStartupFilter>(new CaptureFilter(record)));
        });
    }

    /// <summary>The host's services, for a test that checks what the container resolves.</summary>
    public IServiceProvider Services => factory.Services;

    /// <summary>Every route endpoint the app mapped.</summary>
    public IReadOnlyList<RouteEndpoint> Endpoints =>
        factory.Services.GetRequiredService<EndpointDataSource>().Endpoints.OfType<RouteEndpoint>().ToList();

    public async Task<(int Status, string Body)> SendAsync(string method, string path)
    {
        using var client = factory.CreateClient();
        using var request = new HttpRequestMessage(new HttpMethod(method), path);
        using var response = await client.SendAsync(request);
        return ((int)response.StatusCode, await response.Content.ReadAsStringAsync());
    }

    /// <summary>The pattern the last <paramref name="method"/> request to <paramref name="path"/> resolved to, or null for none.</summary>
    public string? ResolvedPattern(string method, string path) => resolved.GetValueOrDefault(method + " " + path);

    public void Dispose() => factory.Dispose();

    private sealed class CaptureFilter(ConcurrentDictionary<string, string?> record) : IStartupFilter
    {
        public Action<IApplicationBuilder> Configure(Action<IApplicationBuilder> next) => app =>
        {
            app.Use(async (context, run) =>
            {
                await run(context);
                record[context.Request.Method + " " + context.Request.Path] = (context.GetEndpoint() as RouteEndpoint)?.RoutePattern.RawText;
            });
            next(app);
        };
    }
}
