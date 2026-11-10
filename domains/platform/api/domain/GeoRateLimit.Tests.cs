using NUnit.Framework;
using Tsr.Platform.Api.Domain;

namespace Tsr.Platform.Api.Tests.Domain;

/// <summary>rate_limit_allows('geo', 60, 60, 'member-N'): a sliding window of whole seconds, per member, in memory.</summary>
public sealed class GeoRateLimitTests
{
    private sealed class ManualClock(DateTimeOffset start) : TimeProvider
    {
        private DateTimeOffset now = start;

        public override DateTimeOffset GetUtcNow() => now;

        public void Advance(TimeSpan by) => now += by;
    }

    private static readonly DateTimeOffset Start = new(2030, 1, 1, 12, 0, 0, TimeSpan.Zero);

    private readonly ManualClock clock = new(Start);

    private GeoRateLimit Limit() => new(clock);

    [Test]
    public void Sixty_calls_in_a_minute_are_allowed_and_the_61st_is_refused()
    {
        var limit = Limit();

        for (var i = 1; i <= 60; i++)
        {
            Assert.That(limit.Allow(900001), Is.True, "call " + i);
        }

        Assert.That(limit.Allow(900001), Is.False);
    }

    [Test]
    public void A_call_is_allowed_again_exactly_60_seconds_after_the_first_but_not_at_59()
    {
        var limit = Limit();
        for (var i = 0; i < 60; i++)
        {
            limit.Allow(900001);
        }

        clock.Advance(TimeSpan.FromSeconds(59));
        Assert.That(limit.Allow(900001), Is.False);

        clock.Advance(TimeSpan.FromSeconds(1));
        Assert.That(limit.Allow(900001), Is.True);
    }

    [Test]
    public void The_window_slides_so_only_calls_older_than_a_minute_are_forgotten()
    {
        var limit = Limit();
        for (var i = 0; i < 30; i++)
        {
            limit.Allow(900001);
        }

        clock.Advance(TimeSpan.FromSeconds(30));
        for (var i = 0; i < 30; i++)
        {
            Assert.That(limit.Allow(900001), Is.True);
        }

        Assert.That(limit.Allow(900001), Is.False);

        clock.Advance(TimeSpan.FromSeconds(30));
        for (var i = 0; i < 30; i++)
        {
            Assert.That(limit.Allow(900001), Is.True, "the first 30 have expired");
        }

        Assert.That(limit.Allow(900001), Is.False);
    }

    [Test]
    public void A_refused_call_is_not_counted_so_it_does_not_extend_the_wait()
    {
        var limit = Limit();
        for (var i = 0; i < 60; i++)
        {
            limit.Allow(900001);
        }

        clock.Advance(TimeSpan.FromSeconds(30));
        Assert.That(limit.Allow(900001), Is.False);
        clock.Advance(TimeSpan.FromSeconds(30));

        Assert.That(limit.Allow(900001), Is.True);
    }

    [Test]
    public void Each_member_has_their_own_count()
    {
        var limit = Limit();
        for (var i = 0; i < 60; i++)
        {
            limit.Allow(900001);
        }

        Assert.That(limit.Allow(900001), Is.False);
        Assert.That(limit.Allow(900002), Is.True);
    }

    [Test]
    public void Members_who_stopped_calling_are_forgotten_so_memory_stays_bounded()
    {
        var limit = Limit();
        for (var token = 1; token <= 500; token++)
        {
            limit.Allow(token);
        }

        Assert.That(limit.TrackedMembers, Is.EqualTo(500));

        clock.Advance(TimeSpan.FromSeconds(121));
        limit.Allow(1);

        Assert.That(limit.TrackedMembers, Is.EqualTo(1));
    }
}
