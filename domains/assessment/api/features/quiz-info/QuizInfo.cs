using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Assessment.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Features.QuizInfo;

// Slice: GET /quiz/info -> the Grand/Mega quiz status the app's home banner reads, as the whole body. Public: callable signed out (the banner shows before sign-in); a valid Firebase bearer makes the caller the member, who then also gets the
// participation forms, is_superuser (quiz:admin) and can_take_part; an invalid or expired bearer, or one that names no member, is 401 "Authentication failed" (identity's optional sign-in, MemberRoute.Optional: it never creates a member).
// Contract: spec/api.yaml. PHP: api/quiz_info.php (not in PHP's mobile router; the app called the file directly). Order: 60 calls a minute per client address (429, before any sign-in check, as PHP); sign-in; the settings (domain/QuizSettingsRefresh.cs:
// a saved copy under 60 seconds old, else one read from the sheet; a busy lock, a failing or slow sheet serves the saved copy and no request tries the sheet again for 60 seconds: domain/SheetReadBackoff.cs); the body (domain/QuizInfoBody.cs). Always Cache-Control: no-store.
// Deviations: PHP's ?token= parameter is not read (a signed-in member is PHP's firebase+token); the 5-minute caches are gone; the 429 body is {"detail"} (PHP: {success, error}); the errors are {"detail"} too and the success body has no {success, data} wrapper;
// PHP's fallback banner (a file under the web images folder) is not ported: banner is the banner_url setting or null; a quiz admin does not bypass the 60 seconds and PHP's force_quiz_mode is not ported; the bearer is not recorded as a sign-in
// and a pending account deletion does not refuse it; dates or episodes that cannot be read answer offline (PHP: 500).

internal static class QuizInfoSlice
{
    private const int CallsPerMinute = 60;

    public static IEndpointRouteBuilder MapQuizInfo(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/quiz/info", HandleAsync).RequireMember(precheck: Limit, optional: true);
        return routes;
    }

    private static IResult? Limit(HttpContext context) =>
        context.RequestServices.GetRequiredService<MemberRateLimit>().Allow("quiz_info", ClientAddress.RateKey(context), CallsPerMinute, 60)
            ? null
            : Problem.Detail(StatusCodes.Status429TooManyRequests, "Too many requests. Please try again later.");

    private static async Task<IResult> HandleAsync(
        HttpContext context, NpgsqlDataSource source, Permissions permissions, ISheets sheets, IOptions<GoogleSheetsSettings> options, TimeProvider clock, SheetReadBackoff backoff, ILoggerFactory loggers, CancellationToken ct)
    {
        var log = loggers.CreateLogger("Tsr.Assessment.Api.QuizInfo");
        var settings = await QuizSettingsRefresh.CurrentAsync(source, sheets, options.Value.QuizSettingsSheetId, clock, log, backoff, ct);
        var caller = await CallerAsync(context, source, permissions, settings, ct);
        context.Response.Headers.CacheControl = "no-store";
        return Results.Json(QuizInfoBody.Build(settings, clock, caller), AssessmentJson.Answers.JsonObject);
    }

    private static async Task<InfoCaller?> CallerAsync(HttpContext context, NpgsqlDataSource source, Permissions permissions, QuizSettings settings, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return null;
        }

        var isSuperuser = await permissions.CanAsync(caller, "quiz:admin", AccessTarget.None, ct);
        var countries = await source.ListAsync($"""select country as "Value" from membership.v_members where token = {caller.Token}""", row => row.TextOrNull("Value"), ct);
        return new InfoCaller(caller.Token, isSuperuser, QuizEligibility.CanTakePart(settings, caller.Token, countries.Count == 0 ? null : countries[0]));
    }
}
