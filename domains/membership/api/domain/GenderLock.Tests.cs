using NUnit.Framework;
using Tsr.Membership.Api.Domain;

namespace Tsr.Membership.Api.Tests.Domain;

/// <summary>The gender lock of PATCH /me, with a fake classes port that counts its questions.</summary>
public sealed class GenderLockTests
{
    private sealed class FakeEnrolments(bool enrolled) : IClassEnrolments
    {
        public int Asked { get; private set; }

        public Task<bool> IsEnrolledAsync(int token, CancellationToken ct)
        {
            Asked++;
            return Task.FromResult(enrolled);
        }
    }

    private static async Task<(bool Refused, int Asked)> RunAsync(bool enrolled, int token, string? stored, long wanted)
    {
        var port = new FakeEnrolments(enrolled);
        var refused = await new GenderLock(port).RefusesAsync(token, stored, wanted, CancellationToken.None);
        return (refused, port.Asked);
    }

    [TestCase("1", 2)]
    [TestCase("2", 1)]
    [TestCase("1", 0)]
    [TestCase(" 2", 1)]
    public async Task An_enrolled_member_changing_a_set_gender_is_refused(string stored, long wanted)
    {
        var (refused, asked) = await RunAsync(true, 900001, stored, wanted);

        Assert.That(refused, Is.True);
        Assert.That(asked, Is.EqualTo(1));
    }

    [Test]
    public async Task A_member_who_is_not_enrolled_may_change_it_and_the_port_was_asked_once()
    {
        var (refused, asked) = await RunAsync(false, 900001, "1", 2);

        Assert.That(refused, Is.False);
        Assert.That(asked, Is.EqualTo(1));
    }

    [Test]
    public async Task Repeating_the_stored_gender_is_allowed_without_asking_classes()
    {
        var (refused, asked) = await RunAsync(true, 900001, "1", 1);

        Assert.That(refused, Is.False);
        Assert.That(asked, Is.EqualTo(0));
    }

    [TestCase("Male")]
    [TestCase("Female")]
    [TestCase("")]
    [TestCase(null)]
    [TestCase("3")]
    public async Task A_stored_gender_that_is_not_1_or_2_is_never_locked_and_classes_is_not_asked(string? stored)
    {
        var (refused, asked) = await RunAsync(true, 900001, stored, 2);

        Assert.That(refused, Is.False);
        Assert.That(asked, Is.EqualTo(0));
    }

    [TestCase(0)]
    [TestCase(-5)]
    public async Task A_guest_is_never_locked(int token)
    {
        var (refused, asked) = await RunAsync(true, token, "1", 2);

        Assert.That(refused, Is.False);
        Assert.That(asked, Is.EqualTo(0));
    }
}
