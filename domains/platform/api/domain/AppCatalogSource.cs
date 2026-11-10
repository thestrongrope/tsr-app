using System.Text.Json;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace Tsr.Platform.Api.Domain;

/// <summary>
/// Reads the app-version catalog file (setting <c>TSR_APP_VERSIONS_FILE</c>) on every request, like
/// PHP: no cache, so an edit shows at once. A missing, unreadable (including a bad path or a pipe), oversized or malformed file is
/// logged and gives null, which the endpoints turn into the permissive fallback (fail open on purpose).
/// </summary>
internal sealed partial class AppCatalogSource(IConfiguration configuration, ILogger<AppCatalogSource> logger)
{
    public const string SettingName = "TSR_APP_VERSIONS_FILE";

    /// <summary>A catalog is a few kilobytes; a file this large is a mistake, not a catalog.</summary>
    public const int MaxBytes = 1024 * 1024;

    public async Task<JsonDocument?> LoadAsync(CancellationToken ct)
    {
        var path = configuration[SettingName];
        if (string.IsNullOrWhiteSpace(path))
        {
            LogNotConfigured(logger, SettingName);
            return null;
        }

        byte[] bytes;
        try
        {
            bytes = await ReadBoundedAsync(path, ct);
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException or NotSupportedException or ArgumentException)
        {
            LogNotReadable(logger, path, e.GetType().Name);
            return null;
        }

        return AppCatalog.Decode(bytes, logger);
    }

    private static async Task<byte[]> ReadBoundedAsync(string path, CancellationToken ct)
    {
        // Length is not used: a pipe or device cannot report one. Read at most one byte past the limit.
        await using var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read, 4096, useAsync: true);
        using var buffer = new MemoryStream();
        var chunk = new byte[4096];
        int read;
        while ((read = await stream.ReadAsync(chunk, ct)) > 0)
        {
            if (buffer.Length + read > MaxBytes)
            {
                throw new IOException("catalog file is larger than " + MaxBytes + " bytes");
            }

            buffer.Write(chunk, 0, read);
        }

        return buffer.ToArray();
    }

    [LoggerMessage(Level = LogLevel.Warning, Message = "app-version catalog path is not set ({Setting}), serving the permissive fallback")]
    private static partial void LogNotConfigured(ILogger logger, string setting);

    [LoggerMessage(Level = LogLevel.Warning, Message = "app-version catalog is not readable ({Reason}), serving the permissive fallback: {Path}")]
    private static partial void LogNotReadable(ILogger logger, string path, string reason);
}
