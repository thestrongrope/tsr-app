using System.Text.Json;
using NUnit.Framework;

namespace Tsr.Identity.Api.Domain;

/// <summary>TC-CMD-R9-01 (identity half): each event's bytes are what the reflection serializer wrote for the private record it replaces.</summary>
public sealed class IdentityJsonTests
{
    // The code before issue 98: Outbox.WriteAsync(DbContext, ...) serialized with these options.
    private static readonly JsonSerializerOptions Before = new(JsonSerializerDefaults.Web);

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

    // The records as they were, private to IdentityCommands.
    private sealed record OldMemberEmailChanged(int Token);

    private sealed record OldMemberCreated(int Token);
}
