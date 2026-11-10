using System.Text.Json.Nodes;

namespace Tsr.Membership.Api.Domain;

/// <summary>One stored guardian link, with the member names the list shows.</summary>
internal sealed record LinkRow(
    int Id,
    int? ParentToken,
    int ChildToken,
    string? Relationship,
    string Status,
    string Source,
    DateTimeOffset CreatedAt,
    DateTimeOffset? ActivatedAt,
    DateTimeOffset? RevokedAt);

/// <summary>The row of GET /me/children/links and GET /me/parents: PHP's raw row, dates as <c>Y-m-d H:i:s</c> strings.</summary>
internal static class LinkRowView
{
    public const string ChildName = "child_name";
    public const string ParentName = "parent_name";
    public const string InviteLinkCreator = "Invite link";
    public const string UnknownCreator = "Unknown";

    /// <param name="row">The stored link.</param>
    /// <param name="nameKey">The key of the other member's name: <see cref="ChildName"/> or <see cref="ParentName"/>.</param>
    /// <param name="memberName">The other member's name (null when the member or their name is missing).</param>
    /// <param name="creatorName">The creator's name (null when missing); an accepted invite shows "Invite link" instead.</param>
    public static JsonObject Build(LinkRow row, string nameKey, string? memberName, string? creatorName)
    {
        ArgumentNullException.ThrowIfNull(row);
        var created = string.Equals(row.Source, "link", StringComparison.OrdinalIgnoreCase) ? InviteLinkCreator : creatorName ?? UnknownCreator;
        return new JsonObject
        {
            ["id"] = row.Id,
            ["parent_token"] = row.ParentToken,
            ["child_token"] = row.ChildToken,
            [nameKey] = memberName,
            ["relationship"] = row.Relationship,
            ["status"] = row.Status,
            ["source"] = row.Source,
            ["created_at"] = Stamp(row.CreatedAt),
            ["created_by_name"] = created,
            ["activated_at"] = row.ActivatedAt is { } activated ? Stamp(activated) : null,
            ["revoked_at"] = row.RevokedAt is { } revoked ? Stamp(revoked) : null,
        };
    }

    /// <summary>PHP's <c>Y-m-d H:i:s</c> (the database's clock is UTC).</summary>
    public static string Stamp(DateTimeOffset value) =>
        value.UtcDateTime.ToString("yyyy-MM-dd HH:mm:ss", System.Globalization.CultureInfo.InvariantCulture);
}
