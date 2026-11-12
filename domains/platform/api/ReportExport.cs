using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Tsr.Platform.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Platform.Api;

/// <summary>The file formats of a report download.</summary>
public enum ReportFormat
{
    Xlsx,
    Pdf,
}

/// <summary>One table of a report: a heading, a row of column headers and the rows. A number is written as a number, anything else as text.</summary>
public sealed record ReportSection(string Heading, IReadOnlyList<string> Headers, IReadOnlyList<IReadOnlyList<object?>> Rows);

/// <summary>
/// PHP's <c>ReportExportModel</c> plus <c>api_send_report_download</c>: turns a title and sections into an Excel workbook or a PDF
/// and answers the download. It knows nothing about any report, so a file holds exactly the figures its caller passes.
/// The workbook is written here (ClosedXML); the PDF is HTML rendered by a Gotenberg container (setting <c>TSR_GOTENBERG_URL</c>).
/// A renderer that is down or slow is a 503 <c>{"detail": ...}</c> (PHP has no such answer: Dompdf ran inside the request).
/// </summary>
public sealed partial class ReportExport
{
    private const string XlsxType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
    private const string PdfType = "application/pdf";

    private readonly IPdfRenderer _renderer;
    private readonly ILogger<ReportExport> _logger;

    internal ReportExport(IPdfRenderer renderer, ILogger<ReportExport> logger)
    {
        _renderer = renderer;
        _logger = logger;
    }

    /// <summary>PHP <c>api_report_download_format</c>: only the exact words xlsx and pdf. Call it before the sign-in check, as PHP does.</summary>
    public static bool TryParseFormat(string? text, out ReportFormat format)
    {
        format = ReportFormat.Xlsx;
        switch (text)
        {
            case "xlsx":
                return true;
            case "pdf":
                format = ReportFormat.Pdf;
                return true;
            default:
                return false;
        }
    }

    /// <summary>The format asked for in <c>?format=</c> (the last one given, as PHP reads it).</summary>
    public static bool TryGetFormat(HttpContext context, out ReportFormat format)
    {
        ArgumentNullException.ThrowIfNull(context);
        var asked = context.Request.Query["format"];
        return TryParseFormat(asked.Count == 0 ? null : asked[^1], out format);
    }

    /// <summary>The check to pass as <c>RequireMember(precheck:)</c>: the 422 PHP gives a bad format before it looks at who is calling, or null.</summary>
    public static IResult? FormatRefusal(HttpContext context) =>
        TryGetFormat(context, out _) ? null : Problem.Detail(StatusCodes.Status422UnprocessableEntity, "format must be xlsx or pdf");

    /// <summary>The file as the answer: the content type of the format and <c>attachment; filename="&lt;base&gt;.&lt;ext&gt;"</c>. <paramref name="filenameBase"/> is the route's own text, never caller input.</summary>
    public async Task<IResult> DownloadAsync(ReportFormat format, string title, IReadOnlyList<ReportSection> sections, string filenameBase, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(sections);
        ArgumentException.ThrowIfNullOrWhiteSpace(filenameBase);
        if (format == ReportFormat.Xlsx)
        {
            return new Attachment(ReportXlsx.Build(title, sections), XlsxType, SafeName(filenameBase) + ".xlsx");
        }

        return await PdfAsync(_renderer.RenderAsync(ReportHtml.Build(title, sections), ct), filenameBase);
    }

    /// <summary>
    /// A finished page as an upright A4 PDF download (the printable sheets of other domains; PHP rendered them with Dompdf). <paramref name="html"/> is the caller's own page: it must encode every value it holds and refer to no outside resource.
    /// A renderer that is down or slow is the same 503 as a report's. <paramref name="filenameBase"/> is the route's own text.
    /// </summary>
    public async Task<IResult> DownloadPageAsync(string html, string filenameBase, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(html);
        ArgumentException.ThrowIfNullOrWhiteSpace(filenameBase);
        return await PdfAsync(_renderer.RenderPortraitAsync(html, ct), filenameBase);
    }

    private async Task<IResult> PdfAsync(Task<Result<byte[]>> rendering, string filenameBase)
    {
        var pdf = await rendering;
        if (!pdf.IsSuccess)
        {
            LogPdfFailed(pdf.Error);
            return Problem.Detail(StatusCodes.Status503ServiceUnavailable, "The PDF could not be made right now. Try again later");
        }

        return new Attachment(pdf.Value!, PdfType, SafeName(filenameBase) + ".pdf");
    }

    /// <summary>Only letters, digits, space, dot, underscore and hyphen stay: a quote, a line break or a non-ASCII character (a class code is database text) would break the header.</summary>
    internal static string SafeName(string name) =>
        string.Create(name.Length, name, (span, source) =>
        {
            for (var i = 0; i < source.Length; i++)
            {
                var c = source[i];
                span[i] = c is (>= 'a' and <= 'z') or (>= 'A' and <= 'Z') or (>= '0' and <= '9') or ' ' or '.' or '_' or '-' ? c : '_';
            }
        });

    [LoggerMessage(Level = LogLevel.Warning, Message = "PDF export failed: {Reason}")]
    private partial void LogPdfFailed(string? reason);

    /// <summary>PHP <c>api_send_file</c>: status 200, the type, <c>attachment; filename="..."</c> and the length.</summary>
    private sealed class Attachment(byte[] bytes, string contentType, string filename) : IResult
    {
        public async Task ExecuteAsync(HttpContext httpContext)
        {
            ArgumentNullException.ThrowIfNull(httpContext);
            var response = httpContext.Response;
            response.StatusCode = StatusCodes.Status200OK;
            response.ContentType = contentType;
            response.Headers.ContentDisposition = "attachment; filename=\"" + filename + "\"";
            response.ContentLength = bytes.Length;
            await response.Body.WriteAsync(bytes, httpContext.RequestAborted);
        }
    }
}
