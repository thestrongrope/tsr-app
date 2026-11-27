using NUnit.Framework;

namespace Tsr.Shared.Api.Tests;

/// <summary>rate_limit_allows(bucket, max, seconds, 'member-N'): a sliding window of whole seconds, per bucket and member, in memory.</summary>
public sealed class MemberRateLimitTests
{
    private const string Geo = "geo";
    private const int Max = 60;
    private const int Window = 60;

    private sealed class ManualClock(DateTimeOffset start) : TimeProvider
    {
        private DateTimeOffset now = start;

        public override DateTimeOffset GetUtcNow() => now;

        public void Advance(TimeSpan by) => now += by;
    }

    private static readonly DateTimeOffset Start = new(2030, 1, 1, 12, 0, 0, TimeSpan.Zero);

    private readonly ManualClock clock = new(Start);

    private MemberRateLimit Limit() => new(clock);

    [Test]
    public void The_retry_time_is_the_seconds_until_the_oldest_call_leaves_the_window_and_is_never_below_one()
    {
        var limit = Limit();
        Assert.That(limit.RetryAfterSeconds(Geo, 900002, Window), Is.EqualTo(1), "nothing recorded");
        Assert.That(limit.Allow(Geo, 900002, Max, Window), Is.True);
        clock.Advance(TimeSpan.FromSeconds(10));
        Assert.That(limit.Allow(Geo, 900002, Max, Window), Is.True);

        Assert.That(limit.RetryAfterSeconds(Geo, 900002, Window), Is.EqualTo(50));

        clock.Advance(TimeSpan.FromSeconds(49));
        Assert.That(limit.RetryAfterSeconds(Geo, 900002, Window), Is.EqualTo(1));
        Assert.That(limit.RetryAfterSeconds("other", 900002, Window), Is.EqualTo(1), "another bucket");
    }

    [Test]
    public void Sixty_calls_in_a_minute_are_allowed_and_the_61st_is_refused()
    {
        var limit = Limit();

        for (var i = 1; i <= 60; i++)
        {
            Assert.That(limit.Allow(Geo, 900001, Max, Window), Is.True, "call " + i);
        }

        Assert.That(limit.Allow(Geo, 900001, Max, Window), Is.False);
    }

    [Test]
    public void A_call_is_allowed_again_exactly_one_window_after_the_first_but_not_a_second_earlier()
    {
        var limit = Limit();
        for (var i = 0; i < 60; i++)
        {
            limit.Allow(Geo, 900001, Max, Window);
        }

        clock.Advance(TimeSpan.FromSeconds(59));
        Assert.That(limit.Allow(Geo, 900001, Max, Window), Is.False);

        clock.Advance(TimeSpan.FromSeconds(1));
        Assert.That(limit.Allow(Geo, 900001, Max, Window), Is.True);
    }

    [Test]
    public void The_window_slides_so_only_calls_older_than_a_window_are_forgotten()
    {
        var limit = Limit();
        for (var i = 0; i < 30; i++)
        {
            limit.Allow(Geo, 900001, Max, Window);
        }

        clock.Advance(TimeSpan.FromSeconds(30));
        for (var i = 0; i < 30; i++)
        {
            Assert.That(limit.Allow(Geo, 900001, Max, Window), Is.True);
        }

        Assert.That(limit.Allow(Geo, 900001, Max, Window), Is.False);

        clock.Advance(TimeSpan.FromSeconds(30));
        for (var i = 0; i < 30; i++)
        {
            Assert.That(limit.Allow(Geo, 900001, Max, Window), Is.True, "the first 30 have expired");
        }

        Assert.That(limit.Allow(Geo, 900001, Max, Window), Is.False);
    }

    [Test]
    public void A_refused_call_is_not_counted_so_it_does_not_extend_the_wait()
    {
        var limit = Limit();
        for (var i = 0; i < 60; i++)
        {
            limit.Allow(Geo, 900001, Max, Window);
        }

        clock.Advance(TimeSpan.FromSeconds(30));
        Assert.That(limit.Allow(Geo, 900001, Max, Window), Is.False);
        clock.Advance(TimeSpan.FromSeconds(30));

        Assert.That(limit.Allow(Geo, 900001, Max, Window), Is.True);
    }

    [Test]
    public void Each_member_has_their_own_count()
    {
        var limit = Limit();
        for (var i = 0; i < 60; i++)
        {
            limit.Allow(Geo, 900001, Max, Window);
        }

        Assert.That(limit.Allow(Geo, 900001, Max, Window), Is.False);
        Assert.That(limit.Allow(Geo, 900002, Max, Window), Is.True);
    }

    [Test]
    public void Each_bucket_counts_on_its_own_so_two_callers_never_eat_each_others_calls()
    {
        var limit = Limit();
        for (var i = 0; i < 60; i++)
        {
            limit.Allow(Geo, 900001, Max, Window);
        }

        Assert.That(limit.Allow(Geo, 900001, Max, Window), Is.False);
        Assert.That(limit.Allow("guardian-link", 900001, Max, Window), Is.True);
    }

    [Test]
    public void Each_caller_supplies_its_own_limit_and_window()
    {
        var limit = Limit();

        Assert.That(limit.Allow("small", 900001, 2, 10), Is.True);
        Assert.That(limit.Allow("small", 900001, 2, 10), Is.True);
        Assert.That(limit.Allow("small", 900001, 2, 10), Is.False);

        clock.Advance(TimeSpan.FromSeconds(10));
        Assert.That(limit.Allow("small", 900001, 2, 10), Is.True);
    }

    [Test]
    public void Members_who_stopped_calling_are_forgotten_so_memory_stays_bounded()
    {
        var limit = Limit();
        for (var token = 1; token <= 500; token++)
        {
            limit.Allow(Geo, token, Max, Window);
        }

        Assert.That(limit.TrackedMembers, Is.EqualTo(500));

        clock.Advance(TimeSpan.FromSeconds(121));
        limit.Allow(Geo, 1, Max, Window);

        Assert.That(limit.TrackedMembers, Is.EqualTo(1));
    }

    [TestCase(0, 60)]
    [TestCase(-1, 60)]
    [TestCase(60, 0)]
    [TestCase(60, -5)]
    public void A_limit_or_window_below_one_is_a_bug_in_the_caller(int max, int window)
    {
        var limit = Limit();

        Assert.Throws<ArgumentOutOfRangeException>(() => limit.Allow(Geo, 900001, max, window));
    }

    [Test]
    public void A_blank_bucket_is_a_bug_in_the_caller()
    {
        Assert.Throws<ArgumentException>(() => Limit().Allow(" ", 900001, Max, Window));
    }
}
