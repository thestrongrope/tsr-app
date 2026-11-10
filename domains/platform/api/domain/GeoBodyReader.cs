using Microsoft.AspNetCore.Http;

namespace Tsr.Platform.Api.Domain;

internal static class GeoBodyReader
{
    /// <summary>A geo body holds two short fields; anything near this size is not a client of ours. (PHP reads any size.)</summary>
    public const int MaxBytes = 16 * 1024;

    /// <summary>The raw body, or null when it is larger than <see cref="MaxBytes"/>.</summary>
    public static async Task<byte[]?> ReadAsync(HttpRequest request, CancellationToken ct)
    {
        using var buffer = new MemoryStream();
        var chunk = new byte[4096];
        int read;
        while ((read = await request.Body.ReadAsync(chunk, ct)) > 0)
        {
            if (buffer.Length + read > MaxBytes)
            {
                return null;
            }

            buffer.Write(chunk, 0, read);
        }

        return buffer.ToArray();
    }
}
