using Microsoft.AspNetCore.Http;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

/// <summary>PHP <c>api_reports_class_ids_asked</c>: the class ids a share-all asks for (<c>?classIds=1,2,3</c>, each cast as PHP's (int), zero dropped, repeats dropped). Empty means every class the report holds.</summary>
internal static class AskedClassIds
{
    private const int Most = 5000;

    public static IReadOnlyList<long> Of(HttpContext context)
    {
        ArgumentNullException.ThrowIfNull(context);
        var asked = context.Request.Query["classIds"];
        var text = asked.Count == 0 ? string.Empty : asked[^1] ?? string.Empty;
        return [.. text.Split(',').Take(Most).Select(PhpValue.IntOfText).Where(id => id != 0).Distinct()];
    }
}
