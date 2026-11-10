using System.Text.Json.Nodes;

namespace Tsr.Membership.Api.Domain;

/// <summary>
/// The body of GET /me and PATCH /me: PHP's <c>api_cast($user, api_user_spec())</c> over the member's facts. The cast types are PHP's:
/// <c>text</c> is entity-decoded, <c>int?</c> reads a numeric string as its int and anything else as null, a non-nullable field turns
/// null or empty into its zero value (so an empty name is the integer 0), a nullable one into null.
/// </summary>
internal static class ProfileView
{
    /// <summary>A member with no profile row shows the column defaults PHP's <c>users</c> row would have.</summary>
    public static JsonObject Build(int userId, int token, string? email, int roleId, MemberProfile? profile)
    {
        var p = profile ?? new MemberProfile { UserId = userId, Language = 0 };
        return new JsonObject
        {
            ["id"] = userId,
            ["token"] = token,
            ["email"] = email ?? string.Empty,
            ["name"] = RequiredText(p.Name),
            ["roleid"] = roleId,
            ["picture"] = Plain(p.Picture),
            ["gender"] = Whole(p.Gender),
            ["age_range"] = Whole(p.AgeRange),
            ["mobile"] = Decoded(p.Mobile),
            ["country"] = Decoded(p.Country),
            ["state"] = Decoded(p.State),
            ["city"] = Decoded(p.City),
            ["language"] = p.Language,
            ["zip"] = Decoded(p.Zip),
            ["sendupdates"] = Plain(p.SendUpdates),
            ["unsubscribe"] = Plain(p.Unsubscribe),
        };
    }

    private static JsonNode? RequiredText(string? value) =>
        string.IsNullOrEmpty(value) ? 0 : PhpText.HtmlDecode(value);

    private static string? Decoded(string? value) => string.IsNullOrEmpty(value) ? null : PhpText.HtmlDecode(value);

    private static string? Plain(string? value) => string.IsNullOrEmpty(value) ? null : value;

    private static long? Whole(string? value) =>
        string.IsNullOrEmpty(value) || !PhpValue.IsNumeric(value) ? null : PhpValue.IntOfText(value);
}
