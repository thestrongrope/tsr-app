using Tsr.Shared.Api;

namespace Tsr.Access.Api.Domain;

/// <summary>A catalog permission: its name (<c>resource:action:scope</c>) and description.</summary>
internal sealed record PermissionInfo(string Name, string? Description);

/// <summary>
/// What may be granted to a member and why a grant or revoke is refused (PHP PermissionGrantsModel), with no database.
/// Only catalog permissions of scope <c>all</c> are grantable: <c>own</c>, <c>assigned</c> and <c>gender</c> are computed from teaching,
/// class access rules or the role, so a stored grant of them would do nothing. Three permissions are never grantable.
/// </summary>
internal static class GrantRules
{
    public const int MaxReason = 300;

    /// <summary>Access to the grant screen, to class access and to enrolling by token cannot be handed out from the screen.</summary>
    private static readonly HashSet<string> NotGrantable =
        new(["permissions:manage:all", "class-access:manage:all", "members:enrol-by-token:all"], StringComparer.Ordinal);

    private static readonly Dictionary<string, string> Reaches = new(StringComparer.Ordinal)
    {
        ["all"] = "In every class and for every member",
        ["gender"] = "In classes of their own gender",
        ["assigned"] = "In the classes they are assigned",
        ["own"] = "In classes they teach or are MCQ admin of",
        ["taught"] = "In classes they teach",
        ["enrolled"] = "In classes they attend",
        ["self"] = "Their own data only",
    };

    /// <summary>The scope at the end of a permission name.</summary>
    public static string ScopeOf(string name) => name[(name.LastIndexOf(':') + 1)..];

    /// <summary>The plain-language reach of a permission, by its scope; an unknown scope has none.</summary>
    public static string ReachOf(string name) => Reaches.GetValueOrDefault(ScopeOf(name), string.Empty);

    /// <summary>The permissions that may still be granted: scope all, not held in any way (role, grant, or every member's own set) and not on the exclusion list.</summary>
    public static IReadOnlyList<PermissionInfo> Grantable(IEnumerable<PermissionInfo> catalog, IReadOnlyCollection<string> held) =>
        catalog
            .Where(p => ScopeOf(p.Name) == "all" && !held.Contains(p.Name, StringComparer.Ordinal) && !NotGrantable.Contains(p.Name))
            .ToList();

    /// <summary>
    /// Why a grant of <paramref name="permission"/> is refused, or null when it may go ahead. A name the catalog does not
    /// list is "cannot be granted" (422); a held permission is 409. The client's text is only compared, never looked up as an action.
    /// </summary>
    public static Refusal? RefuseGrant(string permission, IReadOnlyList<PermissionInfo> grantable, IReadOnlyCollection<string> held)
    {
        if (grantable.Any(p => string.Equals(p.Name, permission, StringComparison.Ordinal)))
        {
            return null;
        }

        return held.Contains(permission, StringComparer.Ordinal)
            ? new Refusal(409, "The member already holds that permission")
            : new Refusal(422, "That permission cannot be granted");
    }

    /// <summary>The reason, trimmed: required, at most 300 characters, no NUL byte (PostgreSQL cannot store one; PHP stored it, a deviation).</summary>
    public static Outcome<string> CheckedReason(string reason)
    {
        var trimmed = PhpText.Trim(reason);
        if (trimmed.Length == 0)
        {
            return Outcome<string>.Fail(422, "A reason is required");
        }

        if (PhpText.CodePointCount(trimmed) > MaxReason)
        {
            return Outcome<string>.Fail(422, "The reason must be 300 characters or fewer");
        }

        return trimmed.Contains('\0', StringComparison.Ordinal)
            ? Outcome<string>.Fail(422, "The reason must be text")
            : Outcome<string>.Ok(trimmed);
    }
}
