using System.Text.Json;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.Json;
using Microsoft.Extensions.DependencyInjection;
using System.Text.Json.Serialization.Metadata;
using NUnit.Framework;
using Tsr.Identity.Api.Features.AdminDeletionComplete;
using Tsr.Identity.Api.Features.AdminDeletionHold;
using Tsr.Identity.Api.Features.DeletionRequestCancel;

namespace Tsr.Identity.Api.Domain;

/// <summary>TC-CMD-R9-01 (identity half): each event's bytes are what the reflection serializer wrote for the private record it replaces.</summary>
public sealed class IdentityJsonTests
{
    // The code before issue 98: Outbox.WriteAsync(DbContext, ...) serialized with these options.
    private static readonly JsonSerializerOptions Before = new(JsonSerializerDefaults.Web) { TypeInfoResolver = new DefaultJsonTypeInfoResolver() };

    [TestCase(1001)]
    [TestCase(int.MaxValue)]
    public void MemberEmailChanged_gives_the_same_bytes(int token)
    {
        Assert.That(
            JsonSerializer.Serialize(new MemberEmailChanged(token), IdentityJson.Default.MemberEmailChanged),
            Is.EqualTo(JsonSerializer.Serialize(new OldMemberEmailChanged(token), Before)));
    }

    [TestCase(1001)]
    [TestCase(int.MaxValue)]
    public void MemberCreated_gives_the_same_bytes(int token)
    {
        Assert.That(
            JsonSerializer.Serialize(new MemberCreated(token), IdentityJson.Default.MemberCreated),
            Is.EqualTo(JsonSerializer.Serialize(new OldMemberCreated(token), Before)));
    }

    private const string Awkward = "Zoë + \"quoted\" <b>&amp;</b> ٱلْفَاتِحَة";

    // What Results.Json(value) wrote before issue 102: the host's JSON options (web defaults, relaxed encoder), by reflection.
    private static readonly JsonSerializerOptions ReflectionAnswers = new(new JsonOptions().SerializerOptions)
    {
        TypeInfoResolver = new DefaultJsonTypeInfoResolver(),
    };

    private static DeletionRow Row(string status, DateTimeOffset? confirmed = null, int? token = 900001, string? note = null, string? contact = null) =>
        new(7, status, "app", token, token is null ? null : Awkward, token is null ? null : "member+tag@example.invalid", "12345", "5550100", Awkward, contact,
            new DateTimeOffset(2026, 11, 1, 10, 30, 0, TimeSpan.Zero), Awkward, note, confirmed, null, null, 900002, Awkward);

    private static IEnumerable<(string Name, Dictionary<string, object?> Value)> Answers()
    {
        var stamp = DateTimeOffset.UnixEpoch;
        var member = DeletionViews.MemberView(null);
        var unconfirmed = DeletionViews.AdminView(Row("pending"), []);
        var held = DeletionViews.AdminView(Row("awaiting_prize_delivery", stamp, note: Awkward), []);
        var demo = DeletionViews.AdminView(Row("pending", stamp), [900001]);
        var noToken = DeletionViews.AdminView(Row("pending", stamp, token: null, contact: "who+x@example.invalid"), []);
        yield return ("member none", member);
        yield return ("member pending", DeletionViews.MemberView(Row("pending")));
        yield return ("member held", DeletionViews.MemberView(Row("awaiting_prize_delivery", note: Awkward)));
        yield return ("admin unconfirmed", new Dictionary<string, object?> { ["request"] = unconfirmed });
        yield return ("admin held", new Dictionary<string, object?> { ["request"] = held });
        yield return ("admin demo", new Dictionary<string, object?> { ["request"] = demo });
        yield return ("admin no token", new Dictionary<string, object?> { ["request"] = noToken });
        yield return ("list", new Dictionary<string, object?>
        {
            ["counts"] = new Dictionary<string, int> { ["pending"] = 2, ["awaiting_prize_delivery"] = 1, ["completed"] = 0, ["cancelled"] = 0 },
            ["requests"] = new List<Dictionary<string, object?>> { unconfirmed, held },
        });
        yield return ("raise", new Dictionary<string, object?> { ["request"] = unconfirmed, ["created"] = true });
        yield return ("cancel", new Dictionary<string, object?> { ["status"] = "cancelled" });
        yield return ("debug token", new Dictionary<string, object?> { ["status"] = "success", ["email"] = "a+b@example.invalid", ["uid"] = "uid-1", ["name"] = Awkward, ["provider"] = null });
    }

    // TC-IDN-R1-02: every answer shape, written by the generated context, has the bytes and the content type the reflection writer gave, with reflection off in this project.
    [Test]
    public async Task Each_answer_is_written_as_before()
    {
        foreach (var (name, value) in Answers())
        {
            var expected = await ExecuteAsync(Results.Json(value, ReflectionAnswers));
            var actual = await ExecuteAsync(Results.Json(value, IdentityJson.Answers.Answer));

            Assert.That(actual.Body, Is.EqualTo(expected.Body), name);
            Assert.That(actual.ContentType, Is.EqualTo(expected.ContentType), name);
        }
    }

    // TC-IDN-R6-02: each event payload, by the generated context (the default encoder, as the outbox always wrote), against a reflection write with web defaults, with a null token where it can be null.
    [Test]
    public void Each_event_is_written_as_before()
    {
        var reflection = new JsonSerializerOptions(JsonSerializerDefaults.Web) { TypeInfoResolver = new DefaultJsonTypeInfoResolver() };

        Assert.Multiple(() =>
        {
            Assert.That(JsonSerializer.Serialize(new DeletionRequests.Requested(7, 900001, "app"), IdentityJson.Default.Requested), Is.EqualTo(JsonSerializer.Serialize(new DeletionRequests.Requested(7, 900001, "app"), reflection)));
            Assert.That(JsonSerializer.Serialize(new DeletionRequestCancelSlice.Cancelled(7, 900001), IdentityJson.Default.Cancelled), Is.EqualTo(JsonSerializer.Serialize(new DeletionRequestCancelSlice.Cancelled(7, 900001), reflection)));
            Assert.That(JsonSerializer.Serialize(new AdminDeletionHoldSlice.Held(7, null, 900002), IdentityJson.Default.Held), Is.EqualTo(JsonSerializer.Serialize(new AdminDeletionHoldSlice.Held(7, null, 900002), reflection)));
            Assert.That(JsonSerializer.Serialize(new AdminDeletionHoldSlice.Held(7, 900001, 900002), IdentityJson.Default.Held), Is.EqualTo(JsonSerializer.Serialize(new AdminDeletionHoldSlice.Held(7, 900001, 900002), reflection)));
            Assert.That(JsonSerializer.Serialize(new AdminDeletionCompleteSlice.MemberErased(900001, 11), IdentityJson.Default.MemberErased), Is.EqualTo(JsonSerializer.Serialize(new AdminDeletionCompleteSlice.MemberErased(900001, 11), reflection)));
            Assert.That(JsonSerializer.Serialize(new AdminDeletionCompleteSlice.DeletionCompleted(7, null, 900002), IdentityJson.Default.DeletionCompleted), Is.EqualTo(JsonSerializer.Serialize(new AdminDeletionCompleteSlice.DeletionCompleted(7, null, 900002), reflection)));
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

    // TC-IDN-R11-01: this project builds with reflection serialization off, as a native build does, so a type missing from the context throws here.
    [Test]
    public void Reflection_is_off_in_this_test_project() =>
        Assert.That(JsonSerializer.IsReflectionEnabledByDefault, Is.False);

    // The records as they were, private to IdentityCommands.
    private sealed record OldMemberEmailChanged(int Token);

    private sealed record OldMemberCreated(int Token);
}
