using System.Text.Json;
using System.Text.Json.Serialization.Metadata;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.Json;
using Microsoft.Extensions.DependencyInjection;
using NUnit.Framework;
using Tsr.Search.Api.Features.Search;

namespace Tsr.Search.Api.Domain;

/// <summary>
/// The search answer is written by the source-generated <see cref="SearchJson"/>, with the bytes the reflection writer gave (the host's options).
/// This project turns reflection serialization off (as a native build does), so a type missing from the context throws here, not only in the native binary.
/// </summary>
public sealed class SearchJsonTests
{
    // What Results.Json(value) used before: the host's JSON options (web defaults, relaxed encoder), by reflection.
    private static readonly JsonSerializerOptions Reflection = new(new JsonOptions().SerializerOptions)
    {
        TypeInfoResolver = new DefaultJsonTypeInfoResolver(),
    };

    private static SearchSlice.Body Full() =>
        new(
            [
                new SearchGroup("class", 50, true, [new SearchResult(5, "AB-1", "Level 2")]),
                new SearchGroup("student", 1, false, [new SearchResult(9, "Zoë + \"quoted\" <b> & ال", string.Empty)]),
                new SearchGroup("guide", 0, false, []),
            ],
            ["teacher"]);

    private static SearchSlice.Body Empty() => new([], []);

    [Test]
    public async Task The_search_answer_is_written_as_before()
    {
        foreach (var body in new[] { Full(), Empty() })
        {
            var expected = await ExecuteAsync(Results.Json(body, Reflection));
            var actual = await ExecuteAsync(Results.Json(body, SearchJson.Answers.Body));

            Assert.Multiple(() =>
            {
                Assert.That(actual.Body, Is.EqualTo(expected.Body));
                Assert.That(actual.ContentType, Is.EqualTo(expected.ContentType));
            });
        }
    }

    [Test]
    public void Reflection_is_off_in_this_test_project()
    {
        Assert.That(JsonSerializer.IsReflectionEnabledByDefault, Is.False);
    }

    private static async Task<(byte[] Body, string? ContentType)> ExecuteAsync(IResult result)
    {
        using var services = new ServiceCollection().AddLogging().BuildServiceProvider();
        var context = new DefaultHttpContext { RequestServices = services };
        using var body = new MemoryStream();
        context.Response.Body = body;
        await result.ExecuteAsync(context);
        return (body.ToArray(), context.Response.ContentType);
    }
}
