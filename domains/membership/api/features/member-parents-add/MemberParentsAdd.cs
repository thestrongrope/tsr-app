using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Identity.Api;
using Tsr.Membership.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Membership.Api.Features.MemberParentsAdd;

// Slice: POST /members/{child_token}/parents {parent_token, relationship} -> 201 {id, parent_token, child_token, relationship, status: "active"}: staff add an active parent link by token.
// Order (PHP, route_member_parents_add_direct; there is no early token <= 0 check here, unlike the invite routes): staff in reach of the child (domain/GuardianChecks.StaffMayAddForAsync,
// direct) else 403 for a caller without parents:add-direct or 404 "Student not found"; the body (422 Invalid JSON; parent_token is an (int) cast, relationship a string cast); then
// GuardiansModel::addDirect: the parent (a guest or unknown is 404 "Member or student not found", a shared token 422 code ambiguous_token), the child (same), a self link or the caller
// as the parent (422 "Invalid relationship or self-link not allowed"), the relationship (father, mother or guardian after trim and lower-case, else the same 422), then under the child's
// guardian lock: an active link for the pair is 409 "An active link already exists for this parent and child"; a pair the child ended is 403 "Child previously revoked this parent; admin
// approval required" unless the caller holds parents:manage for the child's gender; else the row (source token_entry, active now). Contract: spec/api.yaml.
// Event membership.parent_link_added (linkId, parentToken, childToken, relationship, createdBy).

internal static class MemberParentsAddSlice
{
    internal sealed record ParentLinkAdded(int LinkId, int ParentToken, int ChildToken, string Relationship, int CreatedBy);

    public static IEndpointRouteBuilder MapMemberParentsAdd(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/members/{child_token}/parents", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(
        string child_token,
        HttpContext context,
        NpgsqlDataSource source,
        Permissions permissions,
        UserDirectory users,
        TimeProvider clock,
        CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var childToken = PhpValue.IntOfText(child_token);
        if (!await GuardianChecks.StaffMayAddForAsync(source, permissions, caller, childToken, direct: true, ct))
        {
            return await permissions.CanAsync(caller, "parents:add-direct", AccessTarget.None, ct)
                ? Problem.Detail(StatusCodes.Status404NotFound, GuardianChecks.StudentNotFound)
                : Refusals.NotPermitted();
        }

        var raw = await BodyReader.ReadAsync(context.Request, ct);
        if (raw is null)
        {
            return Problem.Detail(StatusCodes.Status413PayloadTooLarge, "Request body too large");
        }

        var parsed = JsonBody.Parse(raw);
        if (!parsed.IsSuccess)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, parsed.Error!);
        }

        var parentToken = PhpValue.ToInteger(parsed.Value!.Get("parent_token"));
        var relationship = PhpValue.Text(parsed.Value.Get("relationship"));
        return await AddAsync(source, permissions, users, clock, caller, parentToken, childToken, relationship, ct);
    }

    private static async Task<IResult> AddAsync(
        NpgsqlDataSource source, Permissions permissions, UserDirectory users, TimeProvider clock, Caller caller, long parentToken, long childToken, string typed, CancellationToken ct)
    {
        var parent = await GuardianChecks.ValidateMemberAsync(source, users, parentToken, ct);
        if (parent.Status != MemberCheck.Ok)
        {
            return Unknown(parent.Status);
        }

        var child = await GuardianChecks.ValidateMemberAsync(source, users, childToken, ct);
        if (child.Status != MemberCheck.Ok)
        {
            return Unknown(child.Status);
        }

        var parentValue = (int)parentToken;
        var childValue = (int)childToken;
        var callerToken = await GuardianChecks.TokenOfUserAsync(users, caller.UserId, ct);
        if (ParentLinkRules.DirectRefusal(parentValue, childValue, callerToken, typed) is { } invalid)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, invalid);
        }

        var relationship = ParentLinkRules.DirectRelationship(typed)!;
        var mayManage = await GuardianChecks.MayManageParentsAsync(permissions, caller, child.Gender, ct);
        await using var tx = await source.BeginAsync(ct);
        await GuardianLock.TakeAsync(tx, child.UserId, ct);
        var active = await tx.ListAsync(
            $"select 1 as \"Value\" from membership.user_guardians where parent_token = {parentValue} and child_token = {childValue} and status = 'active' limit 1",
            row => row.Int("Value"),
            ct);
        if (active.Count > 0)
        {
            return Problem.Detail(StatusCodes.Status409Conflict, GuardianRules.AlreadyLinked);
        }

        if (await GuardianChecks.RemovedByChildBlocksAsync(tx, parentValue, childValue, mayManage, ct))
        {
            return Problem.Detail(StatusCodes.Status403Forbidden, "Child previously revoked this parent; admin approval required");
        }

        var now = clock.GetUtcNow();
        var linkId = await tx.ScalarAsync<int>(
            $"""
            insert into membership.user_guardians (parent_token, child_token, relationship, status, source, created_by, created_at, activated_at)
            values ({parentValue}, {childValue}, {relationship}, 'active', 'token_entry', {caller.UserId}, {now}, {now})
            returning id as "Value"
            """,
            ct);
        var id = linkId!.Value;
        await Outbox.WriteAsync(tx, "membership.parent_link_added", new ParentLinkAdded(id, parentValue, childValue, relationship, caller.UserId), MembershipJson.Default.ParentLinkAdded, clock, ct);
        await tx.CommitAsync(ct);
        return Results.Json(
            new Dictionary<string, object?>
            {
                ["id"] = id, ["parent_token"] = parentValue, ["child_token"] = childValue, ["relationship"] = relationship, ["status"] = "active",
            },
            MembershipJson.Answers.Answer,
            statusCode: StatusCodes.Status201Created);
    }

    private static IResult Unknown(MemberCheck status) =>
        status == MemberCheck.Ambiguous
            ? Refusals.AmbiguousToken()
            : Problem.Detail(StatusCodes.Status404NotFound, "Member or student not found");
}
