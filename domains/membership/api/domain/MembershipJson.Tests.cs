using System.Text.Json;
using NUnit.Framework;

namespace Tsr.Membership.Api.Domain;

/// <summary>TC-CMD-R9-01 (membership half): each event's bytes are what the reflection serializer wrote for the private record it replaces.</summary>
public sealed class MembershipJsonTests
{
    // The code before issue 98: Outbox.WriteAsync(DbContext, ...) serialized with these options.
    private static readonly JsonSerializerOptions Before = new(JsonSerializerDefaults.Web);

    [TestCase(1001, true)]
    [TestCase(1001, false)]
    [TestCase(int.MaxValue, true)]
    public void MemberContactChanged_gives_the_same_bytes(int token, bool nameChanged)
    {
        Assert.That(
            JsonSerializer.Serialize(new MemberContactChanged(token, nameChanged), MembershipJson.Default.MemberContactChanged),
            Is.EqualTo(JsonSerializer.Serialize(new OldMemberContactChanged(token, nameChanged), Before)));
    }

    [TestCase(1001)]
    [TestCase(int.MaxValue)]
    public void MemberCreated_gives_the_same_bytes(int token)
    {
        Assert.That(
            JsonSerializer.Serialize(new MemberCreated(token), MembershipJson.Default.MemberCreated),
            Is.EqualTo(JsonSerializer.Serialize(new OldMemberCreated(token), Before)));
    }

    // The records as they were, private to MembershipCommands.
    private sealed record OldMemberContactChanged(int Token, bool NameChanged);

    private sealed record OldMemberCreated(int Token);
}
