using Tsr.Shared.Api;

namespace Tsr.Platform.Api.Domain;

/// <summary>The external boundary of the PDF export: HTML in, PDF bytes out (Gotenberg in production, a fake in tests). A failure is a result, not an exception.</summary>
internal interface IPdfRenderer
{
    Task<Result<byte[]>> RenderAsync(string html, CancellationToken ct);
}
