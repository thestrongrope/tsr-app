using System.Data.Common;
using System.Globalization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Logging;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.AdminMemberGet;

// Slice: GET /admin/members/{token} -> a member's details by token, contact included, for the super admin. members:enrol-by-token (403 "You do not have permission to do that"), then the admin audit row, then 30 lookups an
// hour per caller (429 "Too many lookups. Please wait a while and try again."; found or not, counted here after the 403; MemberRateLimit, in memory), then the token: plain digits (up to 18) else 0 is never
// found; none 404 "No registered member has this token"; two holders 422 with code ambiguous_token. A database failure is 500 "Something went wrong. Try again." Contract: spec/api.yaml.
// PHP: routes/member_enrol.php route_admin_member_get (:88), EntityAccessModel::memberDetails (the reads are domain/MemberLookup.cs, over identity.v_users, membership.v_members and v_registrations). Quirks: gender is 1/2
// from "1"/"Male" and "2"/"Female", else null; the requested class is the latest request's, hidden when Accepted, gone or without a class; classesNow is the active classes they are in (by code, at most 50), classesLeft the
// latest row of each other class (at most 50, newest first, leftOn the removal's day, null for a row never removed); registeredOn is the first ten characters of the account's creation time.

internal static partial class AdminMemberGetSlice
{
    internal sealed record Requested(int Id, string Code, object Name);

    internal sealed record Current(int Id, string Code, object Name, string? Level);

    internal sealed record Left(int Id, string Code, object Name, string? LeftOn);

    internal sealed record Card(
        int Token,
        object Name,
        int? Gender,
        string? Email,
        string? Mobile,
        string? City,
        string? Country,
        string? RegisteredOn,
        Requested? RequestedClass,
        IReadOnlyList<Current> ClassesNow,
        IReadOnlyList<Left> ClassesLeft);

    [LoggerMessage(Level = LogLevel.Error, Message = "member_lookup.failed")]
    private static partial void LogFailed(ILogger logger, Exception exception);

    public static IEndpointRouteBuilder MapAdminMemberGet(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/admin/members/{token}", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(
        string token,
        HttpContext context,
        NpgsqlDataSource source,
        Permissions permissions,
        MemberRateLimit limit,
        ILogger<ClassesLog> log,
        CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await permissions.CanAsync(caller, "members:enrol-by-token", AccessTarget.None, ct))
        {
            return Refusals.NotPermitted();
        }

        await ClassGuards.LogAdminAccessAsync(context, permissions, caller, ct);
        if (!limit.Allow("member_lookup", caller.Token, 30, 3600))
        {
            return Problem.Detail(StatusCodes.Status429TooManyRequests, MemberLookup.Throttled);
        }

        try
        {
            return await LookUpAsync(source, MemberLookup.TokenOf(token), ct);
        }
        catch (DbException e)
        {
            LogFailed(log, e);
            return Problem.Detail(StatusCodes.Status500InternalServerError, "Something went wrong. Try again.");
        }
    }

    private static async Task<IResult> LookUpAsync(NpgsqlDataSource source, int token, CancellationToken ct)
    {
        await using var tx = await source.BeginAsync(ct);
        var holders = await MemberLookup.HoldersAsync(tx, token, ct);
        if (holders == 0)
        {
            return MemberLookup.NotFoundAnswer();
        }

        if (holders > 1)
        {
            return MemberLookup.AmbiguousAnswer();
        }

        var row = (await MemberLookup.RowAsync(tx, token, ct))!;
        var requested = await MemberLookup.RequestedClassAsync(tx, token, ct);
        var now = await MemberLookup.ClassesNowAsync(tx, token, ct);
        var left = await MemberLookup.ClassesLeftAsync(tx, token, ct);
        return Results.Json(new Card(
            token,
            PhpCast.Text(row.Name),
            EnrolmentRules.GenderOf(row.Gender),
            PhpCast.StrOrNull(row.Email),
            PhpCast.StrOrNull(row.Mobile),
            PhpCast.TextOrNull(row.City),
            PhpCast.TextOrNull(row.Country),
            row.CreatedOn?.UtcDateTime.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture),
            requested is null ? null : new Requested(requested.ForClassId!.Value, requested.Code!, PhpCast.Text(requested.Name)),
            now.Select(c => new Current(c.Id, c.Code, PhpCast.Text(c.Name), PhpCast.TextOrNull(c.Level))).ToList(),
            left.Select(c => new Left(c.Id, c.Code, PhpCast.Text(c.Name), c.RemovedAt?.UtcDateTime.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture))).ToList()), ClassesJson.Answers.MemberCard);
    }
}
