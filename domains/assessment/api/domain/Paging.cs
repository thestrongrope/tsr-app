using Microsoft.AspNetCore.Http;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Domain;

/// <summary>PHP's <c>page</c> and <c>pageSize</c> query parameters: <c>max(1, (int) page)</c> and <c>min(100, max(1, (int) pageSize))</c>, the size defaulting to 20. The offset cannot overflow (PHP's would become a float and fail).</summary>
internal sealed record Paging(long Page, int PageSize)
{
    public long Offset => (long)Math.Min((decimal)(Page - 1) * PageSize, long.MaxValue);

    public static Paging From(HttpContext context)
    {
        var page = Math.Max(1, QueryInt(context, "page", 1));
        var size = (int)Math.Min(100, Math.Max(1, QueryInt(context, "pageSize", 20)));
        return new Paging(page, size);
    }

    /// <summary>PHP's <c>(int)($_GET[name] ?? default)</c>: the numeric prefix of the last value, the default when it is absent.</summary>
    private static long QueryInt(HttpContext context, string name, long fallback)
    {
        var values = context.Request.Query[name];
        return values.Count == 0 ? fallback : PhpValue.IntOfText(values[^1] ?? string.Empty);
    }
}
