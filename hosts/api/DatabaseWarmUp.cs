using System.Data.Common;
using Npgsql;

namespace Tsr.Host.Api;

/// <summary>
/// Opens one pooled connection before the API listens, so the first request does not pay for it (measured: about 18 ms of the first
/// request; epic 95 asks for 30 ms or less). A database that cannot be reached is logged and the API starts anyway: requests then fail as they did before.
/// </summary>
internal static partial class DatabaseWarmUp
{
    public static async Task RunAsync(IServiceProvider services, CancellationToken ct)
    {
        var logger = services.GetRequiredService<ILoggerFactory>().CreateLogger("Tsr.Host.Api.DatabaseWarmUp");
        try
        {
            // The data source's own connection timeout (5 s) bounds this.
            await using var connection = await services.GetRequiredService<NpgsqlDataSource>().OpenConnectionAsync(ct);
        }
        catch (Exception e) when (e is DbException or TimeoutException)
        {
            NotReached(logger, e);
        }
    }

    [LoggerMessage(Level = LogLevel.Warning, Message = "The database could not be reached at start; the API starts and the first request opens the connection")]
    private static partial void NotReached(ILogger logger, Exception e);
}
