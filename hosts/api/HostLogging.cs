using Microsoft.Extensions.Configuration.Memory;

namespace Tsr.Host.Api;

/// <summary>
/// The log levels of every run mode when no setting names one: the framework (Microsoft.*, System.*) at Warning, the start and stop lines and
/// the project's own lines at Information. Left at the framework's default, every request writes each of its SQL commands, which cost about a
/// third of the throughput in the load test of 14 Nov 2026 (docs/specs/load-test/results.md). These are defaults of the lowest priority: any
/// setting (Logging__LogLevel__&lt;category&gt;) still decides.
/// </summary>
internal static class HostLogging
{
    private static readonly Dictionary<string, string?> Defaults = new()
    {
        ["Logging:LogLevel:Default"] = "Information",
        ["Logging:LogLevel:Microsoft"] = "Warning",
        ["Logging:LogLevel:System"] = "Warning",
        ["Logging:LogLevel:Microsoft.Hosting.Lifetime"] = "Information",
    };

    public static void AddDefaults(ConfigurationManager configuration) =>
        ((IConfigurationBuilder)configuration).Sources.Insert(0, new MemoryConfigurationSource { InitialData = Defaults });
}
