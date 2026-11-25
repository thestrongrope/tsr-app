using Microsoft.AspNetCore.Http;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

/// <summary>
/// PHP <c>api_require_waiting_registrant</c> (routes/registrations.php:20), shared by the two registration routes. A caller who may read the registrations of neither gender is refused (403) before the id is
/// looked up; then the registrant: the registration whose id is the HIGHEST of its member (PHP groups by token and takes MAX), whose status is not Rejected (MAX over the member's rows), who holds no live enrolment
/// in an active class, and whose email does not end @thestrongrope.com (a placeholder member); none is 409; then registrations:read for the registrant's gender (PHP casts the stored text with (int)). Reads
/// other domains through membership.v_registrations, membership.v_members and identity.v_users only.
/// </summary>
internal static class WaitingRegistrant
{
    internal sealed record Registrant(int Token, int Gender);

    private sealed record Row(int Token, string? Gender);

    public static async Task<(Registrant? Registrant, IResult? Refusal)> RequireAsync(
        NpgsqlDataSource source,
        Permissions permissions,
        Caller caller,
        string registrationId,
        CancellationToken ct)
    {
        if (!await permissions.CanAsync(caller, "registrations:read", AccessTarget.ForGender(1), ct)
            && !await permissions.CanAsync(caller, "registrations:read", AccessTarget.ForGender(2), ct))
        {
            return (null, Refusals.NotPermitted());
        }

        var id = PhpValue.IntOfText(registrationId);
        var rows = await source.ListAsync(
            $"""
                select r.token as "Token", m.gender as "Gender"
                from (select max(id) as id, max(token) as token, max(status) as status, max(created_at) as created_at from membership.v_registrations group by token) r
                join membership.v_members m on m.token = r.token
                join identity.v_users u on u.token = r.token
                where r.status <> 'Rejected'
                  and not exists (select 1 from classes.class_students cs join classes.classes c on c.id = cs.class_id
                                  where cs.token_no = r.token and c.status = 'A' and cs.removed_at is null)
                  and u.email not like '%@thestrongrope.com'
                  and r.id = {id}
                order by r.created_at desc
                limit 1
                """,
            row => new Row(row.Int("Token"), row.TextOrNull("Gender")),
            ct);
        if (rows.Count == 0)
        {
            return (null, Problem.Detail(StatusCodes.Status409Conflict, "This registrant is no longer waiting: they have been placed or rejected."));
        }

        var gender = (int)Math.Clamp(PhpValue.IntOfText(rows[0].Gender ?? string.Empty), int.MinValue, int.MaxValue);
        if (!await permissions.CanAsync(caller, "registrations:read", AccessTarget.ForGender(gender), ct))
        {
            return (null, Refusals.NotPermitted());
        }

        return (new Registrant(rows[0].Token, gender), null);
    }
}
