using Microsoft.AspNetCore.Http;

namespace Tsr.Membership.Api.Domain;

/// <summary>Reads a request body without letting a client make the API hold an unbounded amount of memory (PHP reads any size).</summary>
internal static class BodyReader
{
    /// <summary>The form with its lists is a few kilobytes; a megabyte is far beyond any client of ours.</summary>
    public const int MaxBytes = 1024 * 1024;

    /// <summary>The raw body, or null when it is larger than <see cref="MaxBytes"/>.</summary>
    public static async Task<byte[]?> ReadAsync(HttpRequest request, CancellationToken ct)
    {
        using var buffer = new MemoryStream();
        var chunk = new byte[8192];
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
