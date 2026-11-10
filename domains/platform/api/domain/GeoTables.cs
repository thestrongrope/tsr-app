using Microsoft.Extensions.Logging;
using Npgsql;

namespace Tsr.Platform.Api.Domain;

/// <summary>
/// PHP's LocationModel answers "nothing" when the geo tables are missing, so a profile can always be saved as plain
/// text. Only that one case is kept (PostgreSQL 42P01, logged); any other database error is a real failure and is thrown.
/// </summary>
internal static partial class GeoTables
{
    public static async Task<T> OrEmptyAsync<T>(Func<Task<T>> query, T empty, ILogger logger)
    {
        try
        {
            return await query();
        }
        catch (PostgresException e) when (e.SqlState == PostgresErrorCodes.UndefinedTable)
        {
            LogUnavailable(logger);
            return empty;
        }
    }

    [LoggerMessage(Level = LogLevel.Error, Message = "geo.unavailable: a geo table is missing, answering with no rows")]
    private static partial void LogUnavailable(ILogger logger);
}
