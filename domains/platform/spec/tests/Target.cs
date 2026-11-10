namespace Tsr.Platform.Contract.Tests;

/// <summary>
/// Where the contract tests point. Defaults are the local dev stack (docker-compose.dev.yml) and
/// a synthetic member from db/synthetic/seed.sql. Against another implementation, set:
///   TSR_BASE_URL     e.g. http://localhost:8088 (the gateway)
///   TSR_AUTH_HEADER  e.g. X-Dev-Token, or Authorization
///   TSR_AUTH_VALUE   e.g. 900001, or "Bearer &lt;token&gt;"
/// </summary>
internal static class Target
{
    public static Uri BaseUrl => new(Environment.GetEnvironmentVariable("TSR_BASE_URL") ?? "http://localhost:8088");

    public static string AuthHeader => Environment.GetEnvironmentVariable("TSR_AUTH_HEADER") ?? "X-Dev-Token";

    public static string AuthValue => Environment.GetEnvironmentVariable("TSR_AUTH_VALUE") ?? "900001";

    public static HttpClient Anonymous() => new() { BaseAddress = BaseUrl, Timeout = TimeSpan.FromSeconds(10) };

    public static HttpClient Member()
    {
        var client = Anonymous();
        client.DefaultRequestHeaders.Add(AuthHeader, AuthValue);
        return client;
    }
}
