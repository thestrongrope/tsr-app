using System.Text.Json;
using System.Text.Json.Serialization.Metadata;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.Json;
using Microsoft.Extensions.DependencyInjection;
using NUnit.Framework;
using Tsr.Content.Api.Features.HolyQuran;
using Tsr.Content.Api.Features.ListPublishedArticles;

namespace Tsr.Content.Api.Domain;

/// <summary>
/// The two value answers of content are written by the source-generated <see cref="ContentJson"/>, with the bytes the reflection writer gave (the host's options).
/// This project turns reflection serialization off (as a native build does), so a type missing from the context throws here, not only in the native binary.
/// </summary>
public sealed class ContentJsonTests
{
    private const string Awkward = "Zoë + \"quoted\" ü";

    // What Results.Json(value) and Results.Ok(value) used before: the host's JSON options (web defaults, relaxed encoder), by reflection.
    private static readonly JsonSerializerOptions Reflection = new(new JsonOptions().SerializerOptions)
    {
        TypeInfoResolver = new DefaultJsonTypeInfoResolver(),
    };

    private static List<HolyQuranSlice.SurahItem> Surahs() =>
    [
        new(1, "Al-Fatihah", string.Empty, 7),
        new(2, Awkward, "ٱلْفَاتِحَة", 286),
    ];

    private static ListPublishedArticlesResponse Stubs() =>
        new([
            new ArticleResponse("a-first-look", Awkward, "Body + <b>\"text\"</b> ü", new DateTimeOffset(2026, 1, 1, 0, 0, 0, TimeSpan.Zero)),
            new ArticleResponse("second", "Plain", string.Empty, new DateTimeOffset(2025, 12, 31, 23, 59, 59, TimeSpan.FromHours(5))),
        ]);

    [Test]
    public async Task Each_value_answer_is_written_as_before()
    {
        var surahs = Surahs();
        var stubs = Stubs();

        var expectedSurahs = await ExecuteAsync(Results.Json(surahs, Reflection));
        var actualSurahs = await ExecuteAsync(Results.Json(surahs, ContentJson.Answers.SurahList));
        var expectedStubs = await ExecuteAsync(Results.Json(stubs, Reflection));
        var actualStubs = await ExecuteAsync(Results.Json(stubs, ContentJson.Answers.ListPublishedArticlesResponse));

        Assert.Multiple(() =>
        {
            Assert.That(actualSurahs.Body, Is.EqualTo(expectedSurahs.Body));
            Assert.That(actualSurahs.ContentType, Is.EqualTo(expectedSurahs.ContentType));
            Assert.That(actualStubs.Body, Is.EqualTo(expectedStubs.Body));
            Assert.That(actualStubs.ContentType, Is.EqualTo(expectedStubs.ContentType));
        });
    }

    [Test]
    public void Reflection_is_off_in_this_test_project()
    {
        Assert.That(JsonSerializer.IsReflectionEnabledByDefault, Is.False);
    }

    [Test]
    public async Task Each_value_answer_is_written_with_reflection_off()
    {
        var surahs = await ExecuteAsync(Results.Json(Surahs(), ContentJson.Answers.SurahList));
        var stubs = await ExecuteAsync(Results.Json(Stubs(), ContentJson.Answers.ListPublishedArticlesResponse));

        Assert.Multiple(() =>
        {
            Assert.That(surahs.Body, Is.Not.Empty);
            Assert.That(stubs.Body, Is.Not.Empty);
        });
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
