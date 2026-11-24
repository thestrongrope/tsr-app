using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Identity.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Identity.Api.Features.DeletionRequestCreate;

// Slice: POST /me/deletion-request {reason?} (PHP routes/account_deletion.php route_deletion_request_create): the member asks for their account to be deleted.
// Order: signed in (a create route), account:delete (403), body (422 Invalid JSON body), reason (422 "reason must be text" / "reason must be 500 characters or fewer"; a NUL byte is the
// first, a deviation: PHP stores it), then the insert. 202 with the new request, 200 with the existing live one (PHP's choice over its spec's 409). The name and email are copied onto the
// request, because completion clears them from the member. Event identity.deletion_requested. Contract: spec/api.yaml.

internal static class DeletionRequestCreateSlice
{
    private const int ContactNameLength = 200;
    private const int ContactEmailLength = 200;

    private sealed record Contact(string? Email, string? Name);

    public static IEndpointRouteBuilder MapDeletionRequestCreate(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/me/deletion-request", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, NpgsqlDataSource source, Permissions permissions, TimeProvider clock, CancellationToken ct)
    {
        var caller = context.GetCaller();
        var refusal = await DeletionRequests.RefuseAsync(caller, permissions, "account:delete", ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var (body, bad) = await RequestBodies.ReadAsync(context.Request, ct);
        if (bad is not null)
        {
            return bad;
        }

        var (reason, reasonRefusal) = DeletionRequests.ReadText(body!, "reason");
        if (reasonRefusal is not null)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, reasonRefusal);
        }

        Contact? contact;
        await using (var read = await source.BeginAsync(ct))
        {
            contact = (await read.ListAsync(
                $"""
                select u.email as "Email", m.name as "Name"
                from identity.users u left join membership.v_members m on m.user_id = u.id
                where u.id = {caller!.UserId}
                """,
                ReadContact,
                ct)).FirstOrDefault();
        }

        var (row, created) = await DeletionRequests.RaiseAsync(
            source, clock, caller.Token, "app", reason, Cut(contact?.Name, ContactNameLength), Cut(contact?.Email, ContactEmailLength), ct);
        return Results.Json(DeletionViews.MemberView(row), IdentityJson.Answers.Answer, contentType: null, statusCode: created ? StatusCodes.Status202Accepted : StatusCodes.Status200OK);
    }

    private static Contact ReadContact(DbRow row) => new(row.TextOrNull("Email"), row.TextOrNull("Name"));

    // The request's columns are shorter than users.email; a longer address is cut rather than failing the request.
    private static string? Cut(string? value, int length) => value is null || value.Length <= length ? value : value[..length];
}
