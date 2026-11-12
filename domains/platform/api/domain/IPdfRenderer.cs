using Tsr.Shared.Api;

namespace Tsr.Platform.Api.Domain;

/// <summary>The external boundary of the PDF export: HTML in, PDF bytes out (Gotenberg in production, a fake in tests). A failure is a result, not an exception.</summary>
internal interface IPdfRenderer
{
    Task<Result<byte[]>> RenderAsync(string html, CancellationToken ct);

    /// <summary>The same on an A4 page held upright (the reports are landscape). A renderer that has no page orientation answers as <see cref="RenderAsync"/> does.</summary>
    Task<Result<byte[]>> RenderPortraitAsync(string html, CancellationToken ct) => RenderAsync(html, ct);
}
