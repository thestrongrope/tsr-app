using System.Text.Json;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Tsr.Shared.Api;

namespace Tsr.Access.Api.Domain;

internal sealed record PermissionBody(string Name, object Description, string Reach);

internal sealed record GrantedBody(int Id, string Name, object Description, string Reach, string? Reason, string? GrantedBy, string GrantedAt);

internal sealed record GrantMemberBody(int Token, object Name);

internal sealed record GrantMemberView(
    GrantMemberBody Member,
    IReadOnlyList<PermissionBody> FromRole,
    IReadOnlyList<GrantedBody> Granted,
    IReadOnlyList<PermissionBody> Grantable);

/// <summary>
/// What the grant screen shows of a member (PHP PermissionGrantsModel::forMember), shared by the member route and the two writes:
/// the permissions by origin and what may still be granted. Also the guard every route here shares and the request reading.
/// </summary>
internal static class PermissionGrants
{
    public const string ManageAction = "permissions:manage";

    private sealed record GrantRow(int Id, string Name, string? Description, string? Reason, string? GrantedBy, DateTimeOffset GrantedAt);

    /// <summary>The route guard: signed in (401), then <c>permissions:manage</c> (403, in PHP's words). Null when allowed.</summary>
    public static async Task<IResult?> GuardAsync(HttpContext context, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        return await permissions.CanAsync(caller, ManageAction, AccessTarget.None, ct)
            ? null
            : Problem.Detail(StatusCodes.Status403Forbidden, "Only super admins can manage permissions");
    }

    /// <summary>A text field of the body: missing or null is empty, any other type is a 422 "<paramref name="field"/> must be text".</summary>
    public static Outcome<string> TextField(JsonBody body, string field)
    {
        var value = body.Get(field);
        return value.ValueKind switch
        {
            JsonValueKind.Undefined or JsonValueKind.Null => Outcome<string>.Ok(string.Empty),
            JsonValueKind.String => Outcome<string>.Ok(value.GetString() ?? string.Empty),
            _ => Outcome<string>.Fail(StatusCodes.Status422UnprocessableEntity, field + " must be text"),
        };
    }

    /// <summary>The member's view, or null for an unknown member (the route answers 404). Reads live rows: the request's cached answers for this member are dropped first.</summary>
    public static async Task<GrantMemberView?> ViewAsync(AccessContext db, Permissions permissions, int token, CancellationToken ct)
    {
        var member = await AdminMembers.FindAsync(db, token, ct);
        if (member is null)
        {
            return null;
        }

        permissions.Forget(member.UserId);
        var caller = new Caller(member.UserId, member.Token);
        var held = (await permissions.ForUserAsync(caller, ct)).Permissions;
        var roleId = await permissions.RoleIdAsync(caller, ct);

        var catalog = await CatalogAsync(db, ct);
        var fromRole = await FromRoleAsync(db, roleId, catalog, ct);
        var granted = await GrantedAsync(db, member.UserId, ct);

        return new GrantMemberView(
            new GrantMemberBody(member.Token, Cast.Text(member.Name)),
            fromRole,
            granted,
            GrantRules.Grantable(catalog, held).Select(Described).ToList());
    }

    /// <summary>The live grants and the member's held names, for the 409 and 422 decision of a grant.</summary>
    public static async Task<(IReadOnlyList<PermissionInfo> Grantable, IReadOnlyList<string> Held)> GrantableAsync(
        AccessContext db, Permissions permissions, MemberRow member, CancellationToken ct)
    {
        permissions.Forget(member.UserId);
        var held = (await permissions.ForUserAsync(new Caller(member.UserId, member.Token), ct)).Permissions;
        var catalog = await CatalogAsync(db, ct);
        return (GrantRules.Grantable(catalog, held), held);
    }

    private static async Task<IReadOnlyList<PermissionInfo>> CatalogAsync(AccessContext db, CancellationToken ct) =>
        (await db.Permissions.AsNoTracking().ToListAsync(ct))
            .OrderBy(p => p.Name, StringComparer.Ordinal)
            .Select(p => new PermissionInfo(p.Name, p.Description))
            .ToList();

    private static PermissionBody Described(PermissionInfo p) =>
        new(p.Name, Cast.Text(p.Description), GrantRules.ReachOf(p.Name));

    private static async Task<IReadOnlyList<PermissionBody>> FromRoleAsync(AccessContext db, int roleId, IReadOnlyList<PermissionInfo> catalog, CancellationToken ct)
    {
        var names = await db.RolePermissions.AsNoTracking().Where(g => g.RoleId == roleId).Select(g => g.Permission).ToListAsync(ct);
        var wanted = names.ToHashSet(StringComparer.Ordinal);
        return catalog.Where(p => wanted.Contains(p.Name)).Select(Described).ToList();
    }

    private static async Task<IReadOnlyList<GrantedBody>> GrantedAsync(AccessContext db, int userId, CancellationToken ct)
    {
        var rows = await db.Database
            .SqlQuery<GrantRow>($"""
                select g.id as "Id", p.name as "Name", p.description as "Description", g.reason as "Reason", b.name as "GrantedBy", g.granted_at as "GrantedAt"
                from access.user_permissions g
                join access.permissions p on p.name = g.permission
                left join membership.v_members b on b.user_id = g.granted_by
                where g.user_id = {userId} and g.revoked_at is null
                order by g.granted_at, g.id
                """)
            .ToListAsync(ct);
        return rows
            .Select(r => new GrantedBody(r.Id, r.Name, Cast.Text(r.Description), GrantRules.ReachOf(r.Name), Cast.TextOrNull(r.Reason), Cast.TextOrNull(r.GrantedBy), Cast.DateTime(r.GrantedAt)))
            .ToList();
    }
}
