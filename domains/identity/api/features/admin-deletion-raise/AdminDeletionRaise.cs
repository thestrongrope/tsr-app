using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Identity.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Identity.Api.Features.AdminDeletionRaise;

// Slice: POST /admin/deletion-requests {email} (PHP route_admin_deletion_request_raise): an administrator raises a request from an emailed address. Signed in (a create route),
// deletion-requests:manage (403), body (422), email a trimmed string (422 "Enter the email address the request came from"). The member is the first user (lowest token) with that address,
// compared without case. Token 0 is the shared guest, not a member: an address only a guest holds matches nobody, 404 "No account matches <email>" (as does an address with a NUL byte,
// which PHP's database would just not match). 201 {request, created: true}, or 200 {request, created: false} with the member's live request. Source "web". Event identity.deletion_requested.

internal static class AdminDeletionRaiseSlice
{
    private const string Reason = "Raised by an administrator from an emailed request.";
    private const int ContactLength = 200;

    private sealed record Member(int Token, string? Email, string? Name);

    public static IEndpointRouteBuilder MapAdminDeletionRaise(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/admin/deletion-requests", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, NpgsqlDataSource source, Permissions permissions, TimeProvider clock, CancellationToken ct)
    {
        var refusal = await DeletionRequests.RefuseAsync(context.GetCaller(), permissions, "deletion-requests:manage", ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var (body, bad) = await RequestBodies.ReadAsync(context.Request, ct);
        if (bad is not null)
        {
            return bad;
        }

        var field = body!.Get("email");
        var email = field.ValueKind == JsonValueKind.String ? PhpText.Trim(field.GetString() ?? string.Empty) : string.Empty;
        if (email.Length == 0)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, "Enter the email address the request came from");
        }

        Member? member = null;
        if (!email.Contains('\0', StringComparison.Ordinal))
        {
            await using var read = await source.BeginAsync(ct);
            member = await FindMemberAsync(read, email, ct);
        }

        if (member is null)
        {
            return Problem.Detail(StatusCodes.Status404NotFound, "No account matches " + email);
        }

        var (row, created) = await DeletionRequests.RaiseAsync(source, clock, member.Token, "web", Reason, Cut(member.Name), Cut(member.Email), ct);
        List<int> demo;
        await using (var read = await source.BeginAsync(ct))
        {
            demo = await DeletionRequests.DemoTokensAsync(read, ct);
        }

        return Results.Json(
            new Dictionary<string, object?> { ["request"] = DeletionViews.AdminView(row, demo), ["created"] = created },
            IdentityJson.Answers.Answer,
            contentType: null,
            statusCode: created ? StatusCodes.Status201Created : StatusCodes.Status200OK);
    }

    // PHP tokenForEmail (lower(email) = lower(:email), order by token, limit 1) then member(token) (the first row of that token).
    private static async Task<Member?> FindMemberAsync(DbTx tx, string email, CancellationToken ct)
    {
        var tokens = await tx.ListAsync(
            $"""select token as "Value" from identity.users where lower(email) = lower({email}) order by token limit 1""",
            row => row.Int("Value"),
            ct);
        if (tokens.Count == 0 || tokens[0] <= 0)
        {
            return null;
        }

        return (await tx.ListAsync(
            $"""
            select u.token as "Token", u.email as "Email", m.name as "Name"
            from identity.users u left join membership.v_members m on m.user_id = u.id
            where u.token = {tokens[0]}
            order by u.id
            limit 1
            """,
            ReadMember,
            ct)).FirstOrDefault();
    }

    private static Member ReadMember(DbRow row) => new(row.Int("Token"), row.TextOrNull("Email"), row.TextOrNull("Name"));

    private static string? Cut(string? value) => value is null || value.Length <= ContactLength ? value : value[..ContactLength];
}
