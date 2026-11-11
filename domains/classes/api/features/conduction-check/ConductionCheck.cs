using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ConductionCheck;

// Slice: GET /classes/{class_id}/conduction/check?date= -> whether the class already has a session on that day, and whether that day's week already holds as many as the class has schedule slots. Contract: spec/api.yaml.
// PHP: routes/conduction.php route_conduction_check (:374), SessionsModel::getSessionByDate. Guards: active class (404), sessions:create (403), date blank or unreadable (422).
// Copied quirks: any session counts, held or not, deleted or not; the week is Monday to Sunday; the slot count includes deleted slots, at least one. The date is read by ConductionRules.ParseDate (see its comment for the forms).

internal static class ConductionCheckSlice
{
    internal sealed record Answer(bool AlreadyConducted, bool SameWeek);

    public static IEndpointRouteBuilder MapConductionCheck(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/classes/{class_id}/conduction/check", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string class_id, HttpContext context, ClassesContext db, Permissions permissions, TimeProvider clock, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var (head, refusal) = await ConductionData.OpenAsync(db, permissions, caller, class_id, "sessions:create", ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var values = context.Request.Query["date"];
        var text = PhpText.Trim(values.Count == 0 ? string.Empty : values[^1] ?? string.Empty);
        var day = text.Length == 0 ? null : ConductionRules.ParseDate(text, ConductionData.Today(clock));
        if (day is null)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, "date is required and must be a valid date");
        }

        var check = await ConductionData.CheckDayAsync(db, head!.Id, day.Value, 0, ct);
        return Results.Json(new Answer(check.AlreadyConducted, check.SameWeek));
    }
}
