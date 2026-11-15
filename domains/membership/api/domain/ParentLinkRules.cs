using Tsr.Shared.Api;

namespace Tsr.Membership.Api.Domain;

/// <summary>The decision of <see cref="ParentLinkRules.Decide"/>.</summary>
internal enum LinkGuard
{
    Allowed,
    StudentNotFound,
    Forbidden,
}

/// <summary>
/// The staff parent-link rules that need no database. PHP: routes/children.php <c>api_require_parent_link_create</c> and
/// GuardiansModel::addDirect (the order of its checks).
/// </summary>
internal static class ParentLinkRules
{
    /// <summary>
    /// api_require_parent_link_create, over what the handler has looked up: a token of 0 or less is a missing student first; a student
    /// acting for themselves needs parents:manage; staff in reach pass; otherwise 403 for a caller without parents:add and 404 for one with it.
    /// </summary>
    public static LinkGuard Decide(long childToken, int callerToken, bool holdsManage, bool staffMay, bool holdsAdd)
    {
        if (childToken <= 0)
        {
            return LinkGuard.StudentNotFound;
        }

        if (callerToken == childToken && holdsManage)
        {
            return LinkGuard.Allowed;
        }

        if (staffMay)
        {
            return LinkGuard.Allowed;
        }

        return holdsAdd ? LinkGuard.StudentNotFound : LinkGuard.Forbidden;
    }

    /// <summary>addDirect's checks after both members are found: a self link, staff making themselves the parent, an unknown relationship. The refusal text, or null.</summary>
    public static string? DirectRefusal(int parentToken, int childToken, int callerToken, string relationship)
    {
        if (parentToken == childToken || parentToken == callerToken)
        {
            return GuardianRules.InvalidLink;
        }

        return DirectRelationship(relationship) is null ? GuardianRules.InvalidLink : null;
    }

    /// <summary>strtolower(trim()) of the typed relationship when it is father, mother or guardian; otherwise null.</summary>
    public static string? DirectRelationship(string typed) => GuardianRules.Relationship(typed);
}
