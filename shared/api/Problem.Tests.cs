using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.Json;
using Microsoft.Extensions.DependencyInjection;
using NUnit.Framework;

namespace Tsr.Shared.Api.Tests;

public sealed class ProblemTests
{
    private static readonly JsonSerializerOptions Web = new(JsonSerializerDefaults.Web);

    private const string Awkward = "Café \"quoted\" <b>&'☃ 😀 back\\slash";

    [Test]
    public void The_source_generated_error_bodies_match_the_reflection_ones()
    {
        var detail = new ProblemBody(Awkward);
        var deletion = new DeletionProblemBody(Awkward, "pending");

        Assert.Multiple(() =>
        {
            Assert.That(JsonSerializer.SerializeToUtf8Bytes(detail, ProblemJson.Default.ProblemBody), Is.EqualTo(JsonSerializer.SerializeToUtf8Bytes(detail, Web)));
            Assert.That(JsonSerializer.SerializeToUtf8Bytes(deletion, ProblemJson.Default.DeletionProblemBody), Is.EqualTo(JsonSerializer.SerializeToUtf8Bytes(deletion, Web)));
        });
    }

    // The names, their order and the escaping are what the store-live app reads: pinned as text, so a rename in both serializers at once still fails.
    [Test]
    public void The_error_bodies_are_exactly_what_the_app_reads()
    {
        Assert.Multiple(() =>
        {
            Assert.That(JsonSerializer.Serialize(new ProblemBody("Not allowed"), ProblemJson.Default.ProblemBody), Is.EqualTo("""{"detail":"Not allowed"}"""));
            Assert.That(JsonSerializer.Serialize(new DeletionProblemBody("Gone", "pending"), ProblemJson.Default.DeletionProblemBody),
                Is.EqualTo("""{"detail":"Gone","deletion_status":"pending"}"""));
            Assert.That(JsonSerializer.Serialize(new ProblemBody("é\"<"), ProblemJson.Default.ProblemBody), Is.EqualTo("{\"detail\":\"\\u00E9\\u0022\\u003C\"}"));
        });
    }

    [Test]
    public async Task The_answers_carry_the_status_and_the_generated_bytes()
    {
        var plain = await ExecuteAsync(Problem.Detail(StatusCodes.Status422UnprocessableEntity, Awkward));
        var deletion = await ExecuteAsync(Problem.Detail(StatusCodes.Status403Forbidden, Awkward, "pending"));

        Assert.Multiple(() =>
        {
            Assert.That(plain.Status, Is.EqualTo(422));
            Assert.That(plain.Body, Is.EqualTo(JsonSerializer.SerializeToUtf8Bytes(new ProblemBody(Awkward), Web)));
            Assert.That(deletion.Status, Is.EqualTo(403));
            Assert.That(deletion.Body, Is.EqualTo(JsonSerializer.SerializeToUtf8Bytes(new DeletionProblemBody(Awkward, "pending"), Web)));
        });
    }

    private static async Task<(int Status, byte[] Body)> ExecuteAsync(IResult result)
    {
        var services = new ServiceCollection().AddLogging().Configure<JsonOptions>(_ => { }).BuildServiceProvider();
        var context = new DefaultHttpContext { RequestServices = services };
        using var body = new MemoryStream();
        context.Response.Body = body;

        await result.ExecuteAsync(context);

        return (context.Response.StatusCode, body.ToArray());
    }
}
