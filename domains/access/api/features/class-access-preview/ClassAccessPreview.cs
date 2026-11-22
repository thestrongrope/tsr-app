using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Access.Api.Features.ClassAccessPreview;

// Slice: POST /admin/class-access/preview {gender, conditions} -> {classes, classCount, previewHash}: the active classes a rule would reach. Writes nothing. The classes listed are at most 200; classCount and
// previewHash cover all of them (the hash is what a grant must echo back).
// Order as PHP (routes/class_access.php route_class_access_preview :253, ClassAccessModel::preview): sign-in (401), class-access:manage (403), the body (422 Invalid JSON), gender a whole number or left out (422),
// conditions a list of {field, negate?, value} (422), then the model: gender 1 or 2 (422), conditions valid and at least one, IN only, a level that exists (422), the operator manages the rule's gender (403:
// a rule of either gender needs both), each city, country and tag one the operator is offered (422 "Choose a city from the list"). The matching is RuleMatcher, the engine's. Contract: spec/api.yaml.

internal static class ClassAccessPreviewSlice
{
    internal sealed record PreviewAnswer(IReadOnlyList<PreviewClass> Classes, int ClassCount, string PreviewHash);

    public static IEndpointRouteBuilder MapClassAccessPreview(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/admin/class-access/preview", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, NpgsqlDataSource source, Permissions permissions, IClassScopes classes, CancellationToken ct)
    {
        var (op, refusal) = await ClassAccessOperator.RequireAsync(context, permissions, ct);
        if (op is null)
        {
            return refusal!;
        }

        var (body, bodyRefusal) = await RequestBodies.ReadAsync(context.Request, ct);
        if (bodyRefusal is not null)
        {
            return bodyRefusal;
        }

        var gender = ClassAccessInput.Gender(body!);
        var raw = gender.Failed ? Outcome<IReadOnlyList<RawCondition>>.Fail(gender.Refusal!) : ClassAccessInput.Conditions(body!);
        if (raw.Failed)
        {
            return raw.Refusal!.ToResult();
        }

        var range = ClassAccessRules.CheckedGender(gender.Value);
        if (range is not null)
        {
            return range.ToResult();
        }

        var checkedConditions = await ClassAccessStore.CheckedConditionsAsync(source, raw.Value!, ct);
        if (checkedConditions.Failed)
        {
            return checkedConditions.Refusal!.ToResult();
        }

        if (!await op.MayManageRuleAsync(gender.Value, ct))
        {
            return new Refusal(StatusCodes.Status403Forbidden, ClassAccessOperator.OtherGender).ToResult();
        }

        var offered = await ClassAccessStore.OfferedConditionsAsync(classes, op, checkedConditions.Value!, ct);
        if (offered.Failed)
        {
            return offered.Refusal!.ToResult();
        }

        var reached = ClassAccessRules.Reach(gender.Value, offered.Value!, await classes.ActiveClassesAsync(ct));
        return Results.Json(new PreviewAnswer(
            ClassAccessStore.Listed(reached),
            reached.Count,
            ClassAccessRules.PreviewHash(reached.Select(c => c.Id))), AccessJson.Answers.PreviewAnswer);
    }
}
