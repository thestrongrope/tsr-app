namespace Tsr.Content.Contract.Tests;

/// <summary>
/// Where the contract tests point: the local dev stack's gateway unless TSR_BASE_URL says
/// otherwise. Content's routes are public, so there is no member client.
/// </summary>
internal static class Target
{
    public static Uri BaseUrl => new(Environment.GetEnvironmentVariable("TSR_BASE_URL") ?? "http://localhost:8088");

    public static HttpClient Anonymous() => new() { BaseAddress = BaseUrl, Timeout = TimeSpan.FromSeconds(10) };
}
