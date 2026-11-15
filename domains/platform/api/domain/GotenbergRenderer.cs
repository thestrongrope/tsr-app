using System.Text;
using Microsoft.Extensions.Options;
using Tsr.Shared.Api;

namespace Tsr.Platform.Api.Domain;

/// <summary>
/// The PDF renderer: Gotenberg's Chromium route, <c>POST /forms/chromium/convert/html</c>, multipart with one file part named <c>files</c> called
/// <c>index.html</c>. A4 landscape as PHP set it: Chromium swaps the paper size when landscape is true, so the portrait size is sent (inches). The address is the setting <c>TSR_GOTENBERG_URL</c>; the client's timeout bounds the call.
/// </summary>
internal sealed class GotenbergRenderer(HttpClient http, IOptions<GotenbergSettings> settings) : IPdfRenderer
{
    private const int MaxPdfBytes = 50_000_000;

    public Task<Result<byte[]>> RenderAsync(string html, CancellationToken ct) => PostAsync(html, landscape: true, ct);

    public Task<Result<byte[]>> RenderPortraitAsync(string html, CancellationToken ct) => PostAsync(html, landscape: false, ct);

    private async Task<Result<byte[]>> PostAsync(string html, bool landscape, CancellationToken ct)
    {
        using var form = new MultipartFormDataContent
        {
            { new StringContent("8.27"), "paperWidth" },
            { new StringContent("11.69"), "paperHeight" },
            { new StringContent(landscape ? "true" : "false"), "landscape" },
            { new StringContent("0.4"), "marginTop" },
            { new StringContent("0.4"), "marginBottom" },
            { new StringContent("0.4"), "marginLeft" },
            { new StringContent("0.4"), "marginRight" },
            { new ByteArrayContent(Encoding.UTF8.GetBytes(html)), "files", "index.html" },
        };

        try
        {
            using var response = await http.PostAsync(new Uri(settings.Value.BaseUri, "forms/chromium/convert/html"), form, ct);
            if (!response.IsSuccessStatusCode)
            {
                return Result.Fail<byte[]>("Gotenberg answered " + (int)response.StatusCode);
            }

            var bytes = await response.Content.ReadAsByteArrayAsync(ct);
            return bytes.Length is > 4 and <= MaxPdfBytes && Encoding.ASCII.GetString(bytes, 0, 4) == "%PDF"
                ? Result.Ok(bytes)
                : Result.Fail<byte[]>("Gotenberg answered something that is not a PDF");
        }
        catch (HttpRequestException exception)
        {
            return Result.Fail<byte[]>("Gotenberg unreachable: " + exception.Message);
        }
        catch (TaskCanceledException) when (!ct.IsCancellationRequested)
        {
            return Result.Fail<byte[]>("Gotenberg did not answer in time");
        }
    }
}
