using Tsr.Shared.Api;

namespace Tsr.Platform.Api.Domain;

/// <summary>
/// One short text field of a geo request: PHP's api_geo_text(). It must be a string, not blank after
/// trim, and at most <c>max</c> code points counted BEFORE the trim. Returns the trimmed value.
/// </summary>
internal static class GeoField
{
    public static Result<string> Read(GeoBody body, string field, int max)
    {
        var value = body.Text(field);
        if (value is null || PhpText.Trim(value).Length == 0 || PhpText.CodePointCount(value) > max)
        {
            return Result.Fail<string>(field + " is required and must be at most " + max + " characters");
        }

        return Result.Ok(PhpText.Trim(value));
    }
}
