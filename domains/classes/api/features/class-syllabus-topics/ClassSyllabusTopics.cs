using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ClassSyllabusTopics;

// Slice: GET /classes/{class_id}/syllabus-topics -> the topic catalogue of the class's level, or {}. Contract: spec/api.yaml.
// PHP: routes/classes.php route_class_syllabus_topics (classes.php:376). Guards: gender set (400), class active (404), syllabus:read (403), classes:read on the class (403).
// The catalogue is a data file (data/syllabus_topics.json, embedded), keyed by level name: only MIQDAD has one. A level without one answers {} (an object, as PHP casts).

internal static class ClassSyllabusTopicsSlice
{
    private static readonly Lazy<JsonElement> Catalogue = new(LoadCatalogue);

    public static IEndpointRouteBuilder MapClassSyllabusTopics(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/classes/{class_id}/syllabus-topics", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string class_id, HttpContext context, ClassesContext db, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await ClassGuards.HasNumericGenderAsync(db, caller, ct))
        {
            return Refusals.GenderNotSet();
        }

        var head = await ClassGuards.FindActiveClassAsync(db, ClassGuards.IdOf(class_id), ct);
        if (head is null)
        {
            return Refusals.ClassNotFound();
        }

        if (!await permissions.CanAsync(caller, "syllabus:read", AccessTarget.None, ct)
            || !await permissions.CanAsync(caller, "classes:read", AccessTarget.ForClass(head.Id), ct))
        {
            return Refusals.NotPermitted();
        }

        var key = PhpText.ToUpperAscii(PhpText.Trim(head.LevelName));
        return Catalogue.Value.TryGetProperty(key, out var topics) ? Results.Json(topics) : Results.Json(new Dictionary<string, string>());
    }

    private static JsonElement LoadCatalogue()
    {
        using var stream = typeof(ClassSyllabusTopicsSlice).Assembly.GetManifestResourceStream("syllabus_topics.json")
            ?? throw new InvalidOperationException("The embedded syllabus_topics.json is missing");
        return JsonDocument.Parse(stream).RootElement.Clone();
    }
}
