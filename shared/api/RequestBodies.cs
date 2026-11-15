using Microsoft.AspNetCore.Http;

namespace Tsr.Shared.Api;

/// <summary>
/// PHP's <c>api_body()</c> for the write slices: the JSON object of the request (an empty body is an empty object; anything else that is not an object is 422 "Invalid JSON body"). A body over a megabyte is
/// refused with 413 (PHP has no limit of its own; the web server's applies).
/// </summary>
public static class RequestBodies
{
    public const int MaxBytes = 1024 * 1024;

    public static async Task<(JsonBody? Body, IResult? Refusal)> ReadAsync(HttpRequest request, CancellationToken ct)
    {
        using var buffer = new MemoryStream();
        var chunk = new byte[8192];
        int read;
        while ((read = await request.Body.ReadAsync(chunk, ct)) > 0)
        {
            if (buffer.Length + read > MaxBytes)
            {
                return (null, Problem.Detail(StatusCodes.Status413PayloadTooLarge, "Request body too large"));
            }

            buffer.Write(chunk, 0, read);
        }

        var parsed = JsonBody.Parse(buffer.ToArray());
        return parsed.IsSuccess
            ? (parsed.Value, null)
            : (null, Problem.Detail(StatusCodes.Status422UnprocessableEntity, parsed.Error!));
    }
}
