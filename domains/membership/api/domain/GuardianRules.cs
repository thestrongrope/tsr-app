namespace Tsr.Membership.Api.Domain;

/// <summary>The guardian link rules that need no database (PHP: models/guardians.php, routes/children.php).</summary>
internal static class GuardianRules
{
    public const string InvalidLink = "Invalid relationship or self-link not allowed";
    public const string InviteNotFound = "Invite not found";
    public const string InviteUsed = "This link has expired or has already been used";
    public const string RemovedByChild = "This person was removed by the child; ask an admin for a new link";
    public const string AlreadyLinked = "An active link already exists for this parent and child";
    public const string TooManyLookups = "Too many lookups; try again later";
    public const string ActiveLinkNotFound = "Active link not found";
    public const string ActiveParentLinkNotFound = "Active parent link not found";

    private static readonly string[] Relationships = ["father", "mother", "guardian"];

    /// <summary>PHP: status invited and not past its expiry (<c>strtotime(expires_at) &lt;= time()</c> is expired).</summary>
    public static bool IsUsable(string status, DateTimeOffset? expiresAt, DateTimeOffset now) =>
        string.Equals(status, "invited", StringComparison.OrdinalIgnoreCase) && !(expiresAt is { } expiry && expiry <= now);

    /// <summary>The relationship PHP accepts: trimmed, lower-cased (ASCII) and one of father, mother, guardian; null otherwise.</summary>
    public static string? Relationship(string typed)
    {
        var word = PhpText.LowerAscii(PhpText.Trim(typed));
        return Relationships.Contains(word, StringComparer.Ordinal) ? word : null;
    }

    /// <summary>The state GET /me/children/link/{code} shows: not_found, expired (used, cancelled or past its expiry) or valid.</summary>
    public static string InspectState(string? status, DateTimeOffset? expiresAt, DateTimeOffset now)
    {
        if (status is null)
        {
            return "not_found";
        }

        return IsUsable(status, expiresAt, now) ? "valid" : "expired";
    }
}
