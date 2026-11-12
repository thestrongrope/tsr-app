using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Tsr.Notifications.Api;

namespace Tsr.Host.Api;

/// <summary>
/// The run mode <c>--workers</c>: this process runs the background workers named in the setting <c>TSR_WORKERS</c> (comma separated) and serves no API routes (only <c>GET /health</c>). Without the switch no worker is registered,
/// whatever the setting says: the API containers never drain a queue. An unknown name refuses to start. With the switch and no name the process starts and does nothing (one log line).
/// Adding a domain's workers: one line in <see cref="Domains"/>. Wiring a worker container into a compose file or Dokploy is a separate decision (not done here).
/// </summary>
public static partial class WorkerMode
{
    public const string Setting = "TSR_WORKERS";

    // One entry per domain that owns workers: the names it accepts, and the call that registers those that are enabled.
    private static readonly (IReadOnlyList<string> Names, Action<IServiceCollection, IReadOnlySet<string>> Add)[] Domains =
    [
        (NotificationsModule.WorkerNames, (services, enabled) => services.AddNotificationsWorkers(enabled)),
    ];

    /// <summary>The names the host accepts in <c>TSR_WORKERS</c>.</summary>
    public static IReadOnlyList<string> KnownNames => [.. Domains.SelectMany(d => d.Names).Order(StringComparer.Ordinal)];

    /// <summary>
    /// Registers the named workers when <paramref name="workersMode"/> is on; returns the names enabled (lower case, trimmed, without repeats). Throws <see cref="InvalidOperationException"/> naming an unknown worker.
    /// Does nothing, and checks nothing, when the mode is off.
    /// </summary>
    public static IReadOnlyList<string> Register(IServiceCollection services, bool workersMode, string? setting)
    {
        ArgumentNullException.ThrowIfNull(services);
        if (!workersMode)
        {
            return [];
        }

        var enabled = (setting ?? string.Empty)
            .Split(',', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries)
            .Select(name => name.ToLowerInvariant())
            .Distinct(StringComparer.Ordinal)
            .ToList();
        var unknown = enabled.Where(name => !KnownNames.Contains(name)).ToList();
        if (unknown.Count > 0)
        {
            throw new InvalidOperationException(
                $"{Setting} names an unknown worker: {string.Join(", ", unknown)}. Known workers: {string.Join(", ", KnownNames)}.");
        }

        var set = enabled.ToHashSet(StringComparer.Ordinal);
        foreach (var domain in Domains)
        {
            domain.Add(services, set);
        }

        return enabled;
    }

    /// <summary>The one line that says what this process does.</summary>
    public static void Announce(ILogger logger, IReadOnlyList<string> enabled)
    {
        ArgumentNullException.ThrowIfNull(logger);
        if (enabled.Count == 0)
        {
            LogNothing(logger, Setting);
            return;
        }

        var names = string.Join(", ", enabled);
        LogRunning(logger, names);
    }

    [LoggerMessage(Level = LogLevel.Warning, Message = "Worker mode: {Setting} names no worker, so this process does nothing")]
    private static partial void LogNothing(ILogger logger, string setting);

    [LoggerMessage(Level = LogLevel.Information, Message = "Worker mode: running {Workers}; no API routes are served")]
    private static partial void LogRunning(ILogger logger, string workers);
}
