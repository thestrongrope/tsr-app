using Microsoft.AspNetCore.Http;
using Tsr.Shared.Api;

namespace Tsr.Access.Api.Domain;

/// <summary>
/// A request refused with PHP's status and words (PermissionGrantRefused, ClassAccessRefused): <c>{"detail": ..., plus extra fields}</c>.
/// The extra fields (a code, the classes a preview now reaches) are what the app acts on.
/// </summary>
internal sealed record Refusal(int Status, string Detail, IReadOnlyList<KeyValuePair<string, object?>>? Extra = null)
{
    public static Refusal Coded(int status, string detail, string code) =>
        new(status, detail, [new KeyValuePair<string, object?>("code", code)]);

    public IResult ToResult()
    {
        if (Extra is null)
        {
            return Problem.Detail(Status, Detail);
        }

        var body = new Dictionary<string, object?> { ["detail"] = Detail };
        foreach (var (key, value) in Extra)
        {
            body[key] = value;
        }

        return Results.Json(body, statusCode: Status);
    }
}

/// <summary>A value or a <see cref="Refusal"/>: the one mechanism the grant and class access rules use for expected failures.</summary>
internal readonly record struct Outcome<T>(T? Value, Refusal? Refusal)
{
    public bool Failed => Refusal is not null;

    public static Outcome<T> Ok(T value) => new(value, null);

    public static Outcome<T> Fail(int status, string detail) => new(default, new Refusal(status, detail));

    public static Outcome<T> Fail(Refusal refusal) => new(default, refusal);
}

/// <summary>PHP's api_cast for the fields these screens send.</summary>
internal static class Cast
{
    /// <summary>A <c>text</c> field: HTML entities decoded. PHP quirk kept: an empty non-nullable <c>text</c> becomes the number 0 (only <c>str</c> becomes "").</summary>
    public static object Text(string? value) =>
        string.IsNullOrEmpty(value) ? 0 : PhpText.HtmlDecode(value);

    /// <summary>A nullable <c>text?</c> field: null or empty is null.</summary>
    public static string? TextOrNull(string? value) =>
        string.IsNullOrEmpty(value) ? null : PhpText.HtmlDecode(value);

    /// <summary>A <c>datetime</c> as PHP sends it: <c>Y-m-dTH:i:s</c>, here in UTC.</summary>
    public static string DateTime(DateTimeOffset value) =>
        value.UtcDateTime.ToString("yyyy-MM-dd'T'HH:mm:ss", System.Globalization.CultureInfo.InvariantCulture);
}
