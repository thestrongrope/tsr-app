using System.Text.Json.Nodes;
using Tsr.Access.Api;
using Tsr.Identity.Api;
using Tsr.Shared.Api;

namespace Tsr.Membership.Api.Domain;

/// <summary>The profile answer both GET /me and PATCH /me give: the member's identity facts (identity), the role (access) and the profile (here).</summary>
internal static class ProfileAnswer
{
    public static async Task<JsonObject> BuildAsync(Caller caller, MemberProfile? profile, UserDirectory users, Permissions permissions, CancellationToken ct)
    {
        var found = await users.ByIdsAsync([caller.UserId], ct);
        var email = found.Count == 0 ? null : found[0].Email;
        var roleId = await permissions.RoleIdAsync(caller, ct);
        return ProfileView.Build(caller.UserId, caller.Token, email, roleId, profile);
    }
}
