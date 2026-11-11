using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Shared.Api;

namespace Tsr.Identity.Api;

/// <summary>
/// Runs once per request, before the endpoint. For a member route (<see cref="MemberRoute"/>) it
/// reproduces PHP's api_authenticate() in PHP's order, with PHP's status and detail for every refusal
/// (phase-2-identity-recon.md, section 3): token, email, recently deleted (create routes), member row,
/// guest, live deletion; then it records the sign-in and sets the caller. Other routes pass untouched.
/// </summary>
internal sealed class CallerMiddleware(RequestDelegate next, ICallerVerifier verifier)
{
    // The directory is scoped, so it arrives per request here, never in the (singleton) constructor.
    public async Task InvokeAsync(HttpContext context, MemberDirectory members)
    {
        var route = context.GetEndpoint()?.Metadata.GetMetadata<MemberRoute>();
        if (route is null)
        {
            await next(context);
            return;
        }

        var early = route.Precheck?.Invoke(context);
        if (early is not null)
        {
            await early.ExecuteAsync(context);
            return;
        }

        var (refusal, caller) = await AuthenticateAsync(context, members, route.CreatesMember);
        if (refusal is not null)
        {
            await refusal.ExecuteAsync(context);
            return;
        }

        context.SetCaller(caller!);
        await next(context);
    }

    private async Task<(IResult? Refusal, Caller? Caller)> AuthenticateAsync(HttpContext context, MemberDirectory members, bool create)
    {
        var ct = context.RequestAborted;
        var verification = await verifier.VerifyAsync(context.Request, ct);
        var who = verification.Identity;
        switch (verification.Status)
        {
            case VerifyStatus.NoCredentials:
                return (Problem.Detail(StatusCodes.Status401Unauthorized, "Not authenticated"), null);
            case VerifyStatus.InvalidToken:
                return (Problem.Detail(StatusCodes.Status401Unauthorized, "Invalid auth token"), null);
            case VerifyStatus.NoEmail:
                return (Problem.Detail(StatusCodes.Status401Unauthorized, "Email not present in token"), null);
        }

        if (create && await members.RecentlyDeletedAsync(who!.Email, ct))
        {
            return (Problem.Detail(
                StatusCodes.Status403Forbidden,
                "This account has been deleted. Please sign out and sign in again to start afresh.",
                "completed"), null);
        }

        var user = await members.FindAsync(who!, create, ct);
        if (user is null)
        {
            return (Problem.Detail(StatusCodes.Status404NotFound, "User not found"), null);
        }

        if (user.Token == 0)
        {
            return (Problem.Detail(StatusCodes.Status403Forbidden, "Registration incomplete"), null);
        }

        var deletion = await members.LiveDeletionStatusAsync(user.Token, ct);
        if (deletion is not null && !DeletionGate.Allows(RoutePattern(context), context.Request.Method))
        {
            return (Problem.Detail(StatusCodes.Status403Forbidden, "Account deletion pending", deletion), null);
        }

        await members.RecordSignInAsync(user, LoginTracking.From(context.Request), ct);
        return (null, new Caller(user.Id, user.Token));
    }

    private static string RoutePattern(HttpContext context) =>
        (context.GetEndpoint() as RouteEndpoint)?.RoutePattern.RawText ?? string.Empty;
}
