using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Access.Api.Features.UserPermissions;

// One vertical slice: GET /user/permissions, PHP's older page list by role id. The app's router still reads it.
// Contract: domains/access/spec/api.yaml. PHP: route_user_permissions (pages.json).

internal sealed record ApplicableRoleBody(
    [property: JsonPropertyName("role_id")] object RoleId,
    [property: JsonPropertyName("role_name")] string RoleName,
    [property: JsonPropertyName("source")] string Source,
    [property: JsonPropertyName("priority")] int Priority);

internal sealed record UserPermissionsResponse(
    [property: JsonPropertyName("version")] int Version,
    [property: JsonPropertyName("permissions")] IReadOnlyList<string> Permissions,
    [property: JsonPropertyName("role_id")] int RoleId,
    [property: JsonPropertyName("role_name")] string RoleName,
    [property: JsonPropertyName("applicable_roles")] IReadOnlyList<ApplicableRoleBody> ApplicableRoles,
    [property: JsonPropertyName("enrolled")] bool Enrolled,
    [property: JsonPropertyName("class_count")] int ClassCount,
    [property: JsonPropertyName("teacher_count")] int TeacherCount,
    [property: JsonPropertyName("mcq_admin")] bool McqAdmin,
    [property: JsonPropertyName("is_teacher")] bool IsTeacher,
    [property: JsonPropertyName("issued_at")] string IssuedAt);

internal static class UserPermissionsEndpoint
{
    public static IEndpointRouteBuilder MapUserPermissions(this IEndpointRouteBuilder routes)
    {
        routes.MapGet(
            "/user/permissions",
            (HttpContext context, UserPermissionsHandler handler) => handler.HandleAsync(context.GetCaller(), context.RequestAborted))
            .RequireMember(createsMember: true);
        return routes;
    }
}

/// <summary>
/// Sign-in is the only gate. The class facts come from the classes port. PHP counts enrolments over every class
/// row, removed and inactive ones too (its own code says so); the port gives active, current ones, so the counts
/// can differ once classes exist. With no classes yet both are zero.
/// </summary>
internal sealed class UserPermissionsHandler(Permissions permissions, IClassScopes classes, TimeProvider clock)
{
    public async Task<IResult> HandleAsync(Caller? caller, CancellationToken ct)
    {
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var roleId = await permissions.RoleIdAsync(caller, ct);
        var memberships = await classes.MembershipsAsync(caller.Token, ct);
        var answer = LegacyPermissions.Build(roleId, memberships.Enrolled.Count, memberships.McqFlagged.Count > 0, memberships.Taught.Count);
        return Results.Json(new UserPermissionsResponse(
            answer.Version,
            answer.Permissions,
            answer.RoleId,
            answer.RoleName,
            answer.ApplicableRoles.Select(r => new ApplicableRoleBody(r.RoleId, r.RoleName, r.Source, r.Priority)).ToList(),
            answer.Enrolled,
            answer.ClassCount,
            answer.TeacherCount,
            answer.McqAdmin,
            answer.IsTeacher,
            LegacyPermissions.IssuedAt(clock.GetUtcNow())));
    }
}
