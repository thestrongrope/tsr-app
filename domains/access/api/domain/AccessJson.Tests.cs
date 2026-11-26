using System.Text.Json;
using System.Text.Json.Serialization.Metadata;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.Json;
using Microsoft.Extensions.DependencyInjection;
using NUnit.Framework;
using static Tsr.Access.Api.Features.AdminPermissionGrant.AdminPermissionGrantSlice;
using static Tsr.Access.Api.Features.AdminPermissionMembers.AdminPermissionMembersSlice;
using static Tsr.Access.Api.Features.AdminPermissionRevoke.AdminPermissionRevokeSlice;
using static Tsr.Access.Api.Features.ClassAccessGrant.ClassAccessGrantSlice;
using static Tsr.Access.Api.Features.ClassAccessMembers.ClassAccessMembersSlice;
using static Tsr.Access.Api.Features.ClassAccessOptions.ClassAccessOptionsSlice;
using static Tsr.Access.Api.Features.ClassAccessPreview.ClassAccessPreviewSlice;
using static Tsr.Access.Api.Features.ClassAccessRevoke.ClassAccessRevokeSlice;
using Tsr.Access.Api.Features.AdminPermissionMembers;
using Tsr.Access.Api.Features.ClassAccessMembers;
using Tsr.Access.Api.Features.ClassAccessOptions;
using Tsr.Access.Api.Features.MePermission;
using Tsr.Access.Api.Features.MePermissions;
using Tsr.Access.Api.Features.UserPermissions;

namespace Tsr.Access.Api.Domain;

/// <summary>
/// Every answer, refusal and event of access is written by the source-generated <see cref="AccessJson"/>, with the bytes the reflection writer gave (web defaults).
/// This project turns reflection serialization off (as a native build does), so a type missing from the context throws here, not only in the native binary.
/// </summary>
public sealed class AccessJsonTests
{
    private const string Awkward = "Zoë + \"quoted\" ü";

    // What Results.Json(value) used before: the host's JSON options (web defaults, relaxed encoder), by reflection.
    private static readonly JsonSerializerOptions Reflection = new(new JsonOptions().SerializerOptions)
    {
        TypeInfoResolver = new DefaultJsonTypeInfoResolver(),
    };

    // What the outbox used before: web defaults, by reflection.
    private static readonly JsonSerializerOptions EventReflection = new(JsonSerializerDefaults.Web)
    {
        TypeInfoResolver = new DefaultJsonTypeInfoResolver(),
    };

    private static readonly object[] Texts = [0, Awkward];

    // --- the same bytes as the reflection writer ---

    [Test]
    public async Task Each_answer_is_written_as_before()
    {
        foreach (var (value, type, reference) in Answers())
        {
            var expected = await ExecuteAsync(reference);
            var actual = await ExecuteAsync(type);
            Assert.That(actual, Is.EqualTo(expected), value.GetType().Name);
        }
    }

    [Test]
    public void Each_event_is_written_as_before()
    {
        const string permission = "a+b<ü";
        Assert.Multiple(() =>
        {
            AssertEvent(new PermissionGranted(1, 900001, permission, 900002), AccessJson.Default.PermissionGranted);
            AssertEvent(new PermissionRevoked(1, 900001, permission, 900002), AccessJson.Default.PermissionRevoked);
            AssertEvent(new RuleCreated(3, 900001, null, 900002), AccessJson.Default.RuleCreated);
            AssertEvent(new RuleCreated(3, 900001, 2, 900002), AccessJson.Default.RuleCreated);
            AssertEvent(new RuleRevoked(3, 900001, 900002), AccessJson.Default.RuleRevoked);
        });
    }

    // The reference is what the outbox wrote before: web defaults with the default encoder, which escapes '+', '<' and non-ASCII letters.
    private static void AssertEvent<T>(T value, JsonTypeInfo<T> type) =>
        Assert.That(JsonSerializer.Serialize(value, type), Is.EqualTo(JsonSerializer.Serialize(value, EventReflection)), typeof(T).Name);

    // --- reflection is off in this project, and nothing needs it ---

    [Test]
    public void Reflection_is_off_in_this_test_project()
    {
        Assert.That(JsonSerializer.IsReflectionEnabledByDefault, Is.False);
    }

    [Test]
    public async Task Each_answer_and_refusal_is_written_with_reflection_off()
    {
        foreach (var (value, type, _) in Answers())
        {
            Assert.That(await ExecuteAsync(type), Is.Not.Empty, value.GetType().Name);
        }

        var reached = new List<ClassFacts> { new(7, 1, "Lahore", "PK", null, [], "C7", Awkward), new(8, 1, null, null, null, [], "C8", "") };
        foreach (var refusal in new[] { Refusal.Coded(409, "changed", "member_changed"), ClassAccessMessages.PreviewChanged(reached, "abc123"), ClassAccessMessages.PreviewChanged([], "none") })
        {
            Assert.That(await ExecuteAsync(refusal.ToResult()), Is.Not.Empty);
        }
    }

    [Test]
    public async Task A_refusal_carries_its_extra_fields_as_before()
    {
        var reached = new List<ClassFacts> { new(7, 1, null, null, null, [], "C7", Awkward), new(8, 1, null, null, null, [], "C8", "") };
        var refusal = ClassAccessMessages.PreviewChanged(reached, "abc123");
        var body = new Dictionary<string, object?> { ["detail"] = refusal.Detail };
        foreach (var (key, value) in refusal.Extra!)
        {
            body[key] = value;
        }

        var expected = await ExecuteAsync(Results.Json(body, Reflection, statusCode: 409));

        Assert.That(await ExecuteAsync(refusal.ToResult()), Is.EqualTo(expected));
    }

    // One sample per answer type, each object field once as 0 and once as non-ASCII text with + and quotes. The reference writes the same value by reflection.
    private static IEnumerable<(object Value, IResult Typed, IResult Reference)> Answers()
    {
        foreach (var text in Texts)
        {
            var member = new ClassAccessMemberBody(900001, text, 2);
            var condition = new ConditionBody("city", true, text);
            var rule = new RuleBody(5, null, text, "2026-11-22T10:00:00", [condition, new ConditionBody("tag", false, null)], 1, [new ClassBody(7, "C7", text, 5, text)]);
            var classAccess = new ClassAccessView(member, "v1", null, [rule]);
            yield return Pair(classAccess, AccessJson.Answers.ClassAccessView);
            yield return Pair(new SavedBody(true, member, "v1", "gents", [rule]), AccessJson.Answers.SavedBody);
            yield return Pair(new SavedBody(true, null, null, null, []), AccessJson.Answers.SavedBody);

            var grant = new GrantMemberView(
                new GrantMemberBody(900001, text),
                [new PermissionBody("classes:view", text, "all")],
                [new GrantedBody(1, "classes:edit", text, "gender", null, "Admin", "2026-11-22T10:00:00")],
                [new PermissionBody("classes:add", text, "own")]);
            yield return Pair(grant, AccessJson.Answers.GrantMemberView);

            yield return Pair(new GrantMembersAnswer([new AdminPermissionMembersSlice.Found(900001, text)]), AccessJson.Answers.GrantMembersAnswer);
            yield return Pair(new ClassAccessMembersAnswer([new ClassAccessMembersSlice.Found(900001, text, 1)]), AccessJson.Answers.ClassAccessMembersAnswer);
            yield return Pair(
                new ClassAccessOptionsAnswer([new ClassAccessOptionsSlice.GenderOption(1, "Gents")], [new LevelBody(1, "L1", text)], ["Lahore"], ["PK"], ["tag"]),
                AccessJson.Answers.ClassAccessOptionsAnswer);
            yield return Pair(new PreviewAnswer([new PreviewClass(7, "C7", text)], 1, "abc123"), AccessJson.Answers.PreviewAnswer);

            var roles = new[] { new ApplicableRoleBody(text, "Member", "role", 1), new ApplicableRoleBody(3, "Gents admin", "role", 2) };
            yield return Pair(
                new UserPermissionsResponse(1, ["a:b"], 3, "Gents admin", roles, true, 2, 1, false, true, "2026-11-22T10:00:00"),
                AccessJson.Answers.UserPermissionsResponse);
        }

        yield return Pair(new MePermissionResponse("classes:view", ["all", "own"]), AccessJson.Answers.MePermissionResponse);
        yield return Pair(
            new MePermissionsResponse(5, "2026-11-22T10:00:00", ["a:b"], new ScopesBody(null, [1], [2], [3], [4], [5]), new Navigation(true, false), "0123456789abcdef"),
            AccessJson.Answers.MePermissionsResponse);
        yield return Pair(
            new MePermissionsResponse(5, "2026-11-22T10:00:00", [], new ScopesBody(1, [], [], [], [], []), new Navigation(false, true), "0123456789abcdef"),
            AccessJson.Answers.MePermissionsResponse);
    }

    private static (object Value, IResult Typed, IResult Reference) Pair<T>(T value, JsonTypeInfo<T> type) =>
        (value!, Results.Json(value, type), Results.Json(value, Reflection));

    private static async Task<byte[]> ExecuteAsync(IResult result)
    {
        using var services = new ServiceCollection().AddLogging().BuildServiceProvider();
        var context = new DefaultHttpContext { RequestServices = services };
        using var body = new MemoryStream();
        context.Response.Body = body;
        await result.ExecuteAsync(context);
        return body.ToArray();
    }
}
