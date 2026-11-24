using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Microsoft.Extensions.Logging;
using Tsr.Access.Api;
using Tsr.Identity.Api;
using Tsr.Membership.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Membership.Api.Features.ProfileUpdate;

// Slice: PATCH /me -> update the member's own profile (name, gender, age_range, mobile, country, state, city, language, zip) and answer with it.
// Permission profile:update; blocked while an account deletion is pending (identity's gate). Contract: spec/api.yaml.
// PHP: routes/users.php route_me_patch, api_validate_profile_field, SubscribersModel::updateProfile and genderChangeAllowed, LocationModel::check.
// Deferred: the search touch (an outbound_messages row PHP queues when name or gender changes; the table does not exist here, no search yet).

internal static class ProfileUpdateEndpoint
{
    public const string Permission = "profile:update";

    public static IEndpointRouteBuilder MapProfileUpdate(this IEndpointRouteBuilder routes)
    {
        routes.MapPatch(
            "/me",
            (HttpContext context, ProfileUpdateHandler handler) =>
                handler.HandleAsync(context.GetCaller(), context.Request, context.RequestAborted))
            .RequireMember(createsMember: true);
        return routes;
    }
}

internal sealed partial class ProfileUpdateHandler(
    NpgsqlDataSource source,
    Permissions permissions,
    UserDirectory users,
    PlaceCheck place,
    GenderLock genderLock,
    ILogger<ProfileUpdateHandler> logger)
{
    private const string GenderLocked = "Gender cannot be changed while you are enrolled in a class";

    public async Task<IResult> HandleAsync(Caller? caller, HttpRequest request, CancellationToken ct)
    {
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await permissions.CanAsync(caller, ProfileUpdateEndpoint.Permission, AccessTarget.None, ct))
        {
            return Refusals.NotPermitted();
        }

        var raw = await BodyReader.ReadAsync(request, ct);
        if (raw is null)
        {
            return Problem.Detail(StatusCodes.Status413PayloadTooLarge, "Request body too large");
        }

        var parsed = JsonBody.Parse(raw);
        return parsed.IsSuccess
            ? await UpdateAsync(caller, ProfileChanges.From(parsed.Value!), ct)
            : Unprocessable(parsed.Error!);
    }

    private async Task<IResult> UpdateAsync(Caller caller, ProfileChanges changes, CancellationToken ct)
    {
        var stored = (await source.ListAsync(ProfileRows.ByUserId(caller.UserId), ProfileRows.Read, ct)).FirstOrDefault();

        // PHP answers a body with no updatable key before it validates anything.
        if (changes.IsEmpty)
        {
            return await AnswerAsync(caller, stored, ct);
        }

        if (changes.FirstError() is { } invalid)
        {
            return Unprocessable(invalid);
        }

        var before = new PlaceFacts(stored?.Country ?? string.Empty, stored?.State ?? string.Empty, stored?.City ?? string.Empty, stored?.Zip ?? string.Empty);
        var after = new PlaceFacts(
            changes.TextOr("country", before.Country),
            changes.TextOr("state", before.State),
            changes.TextOr("city", before.City),
            changes.TextOr("zip", before.Zip));
        if (await place.ProblemAsync(before, after, ct) is { } problem)
        {
            return Unprocessable(problem);
        }

        var (state, city) = await place.FromPostalCodeAsync(before, after, changes.IsSet("zip"), changes.IsSet("country"), ct);
        if (await GenderRefusedAsync(caller, changes, stored, ct))
        {
            return Unprocessable(GenderLocked);
        }

        return await AnswerAsync(caller, await SaveAsync(caller, changes, state, city, ct), ct);
    }

    // PHP: genderChangeAllowed(), only when the body names gender. The rule is GenderLock (unit tested with a fake classes port).
    private async Task<bool> GenderRefusedAsync(Caller caller, ProfileChanges changes, MemberProfile? stored, CancellationToken ct)
    {
        if (!changes.Has("gender") || !await genderLock.RefusesAsync(caller.Token, stored?.Gender, PhpValue.ToInteger(changes.Value("gender")), ct))
        {
            return false;
        }

        LogGenderChangeRefused(logger);
        return true;
    }

    // The member's row is created on the first write; two first writes at once cannot collide.
    private async Task<MemberProfile> SaveAsync(Caller caller, ProfileChanges changes, string? state, string? city, CancellationToken ct)
    {
        await source.ExecuteAsync(
            $"insert into membership.member_profiles (user_id) values ({caller.UserId}) on conflict (user_id) do nothing",
            ct);

        // The row is locked while it is read and written, so two changes of one member apply one after the other.
        await using var tx = await source.BeginAsync(ct);
        var profile = (await tx.ListAsync(
            $"""
            select user_id, name, first_name, last_name, picture, gender, age_range, mobile, country, state, city, zip, language, sendupdates, unsubscribe
            from membership.member_profiles where user_id = {caller.UserId} for update
            """,
            ProfileRows.Read,
            ct)).Single();
        foreach (var field in ProfileFields.Updatable.Where(changes.Has))
        {
            Apply(profile, field, changes.Value(field));
        }

        // The postal code's own state and city win over what was sent.
        profile.State = state ?? profile.State;
        profile.City = city ?? profile.City;
        await tx.ExecuteAsync(
            $"""
            update membership.member_profiles
            set name = {profile.Name}, gender = {profile.Gender}, age_range = {profile.AgeRange}, mobile = {profile.Mobile}, country = {profile.Country},
                state = {profile.State}, city = {profile.City}, language = {profile.Language}, zip = {profile.Zip}
            where user_id = {caller.UserId}
            """,
            ct);
        await tx.CommitAsync(ct);
        return profile;
    }

    // One setter per updatable field: what PDO binds for the value (ProfileColumns) goes to that column.
    private static readonly Dictionary<string, Action<MemberProfile, System.Text.Json.JsonElement>> Setters = new(StringComparer.Ordinal)
    {
        ["name"] = (p, v) => p.Name = ProfileColumns.Text(v),
        ["gender"] = (p, v) => p.Gender = ProfileColumns.Text(v),
        ["age_range"] = (p, v) => p.AgeRange = ProfileColumns.Text(v),

        // PHP's column is NOT NULL: a null passes validation and the database refuses it (a 500).
        ["mobile"] = (p, v) => p.Mobile = ProfileColumns.Text(v) ?? throw new InvalidOperationException("mobile cannot be null: the column is NOT NULL (PHP answers a 500)."),
        ["country"] = (p, v) => p.Country = ProfileColumns.Text(v),
        ["state"] = (p, v) => p.State = ProfileColumns.Text(v),
        ["city"] = (p, v) => p.City = ProfileColumns.Text(v),
        ["language"] = (p, v) => p.Language = v.ValueKind == System.Text.Json.JsonValueKind.Null ? null : ProfileColumns.Language(v),
        ["zip"] = (p, v) => p.Zip = ProfileColumns.Text(v),
    };

    private static void Apply(MemberProfile profile, string field, System.Text.Json.JsonElement value) => Setters[field](profile, value);

    private async Task<IResult> AnswerAsync(Caller caller, MemberProfile? profile, CancellationToken ct) =>
        Results.Json(await ProfileAnswer.BuildAsync(caller, profile, users, permissions, ct), MembershipJson.Answers.JsonObject);

    private static IResult Unprocessable(string detail) => Problem.Detail(StatusCodes.Status422UnprocessableEntity, detail);

    // PHP: log_event('profile.gender_change_refused'). No member token in the log line.
    [LoggerMessage(Level = LogLevel.Information, Message = "profile.gender_change_refused")]
    private static partial void LogGenderChangeRefused(ILogger logger);
}
