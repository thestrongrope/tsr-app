namespace Tsr.Shared.Api;

/// <summary>
/// A per-member sliding-window rate limit, in memory in this process, like PHP's
/// <c>rate_limit_allows(bucket, max, seconds, 'member-N')</c> (PHP keeps one small file per member on its host).
/// Each caller names its own bucket and supplies its own limit and window, so two callers never share a count; the
/// caller owns the refusal wording. Whole seconds, the window slides, a refused call is not recorded, and members idle
/// for a window are forgotten so the table cannot grow without bound. With several API instances each would allow
/// the full limit (a known weakness, phase-3-platform-design.md decision 2).
/// </summary>
public sealed class MemberRateLimit(TimeProvider clock)
{
    private readonly object gate = new();
    private readonly Dictionary<(string Bucket, int Token), Calls> calls = [];
    private long lastSweep;

    /// <summary>Members currently remembered, in all buckets. For tests.</summary>
    public int TrackedMembers
    {
        get
        {
            lock (gate)
            {
                return calls.Count;
            }
        }
    }

    /// <summary>True when the member's call is allowed (and recorded); false when it would exceed <paramref name="maxCalls"/> in the window.</summary>
    public bool Allow(string bucket, int token, int maxCalls, int windowSeconds)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(bucket);
        ArgumentOutOfRangeException.ThrowIfLessThan(maxCalls, 1);
        ArgumentOutOfRangeException.ThrowIfLessThan(windowSeconds, 1);

        var now = clock.GetUtcNow().ToUnixTimeSeconds();
        lock (gate)
        {
            SweepIfDue(now);
            var key = (bucket, token);
            if (!calls.TryGetValue(key, out var recent))
            {
                recent = new Calls(windowSeconds);
                calls[key] = recent;
            }

            recent.Forget(now);
            if (recent.Times.Count >= maxCalls)
            {
                return false;
            }

            recent.Times.Enqueue(now);
            return true;
        }
    }

    // Idle members are dropped at most once a minute, so the sweep cost stays small.
    private void SweepIfDue(long now)
    {
        if (now - lastSweep < SweepEverySeconds)
        {
            return;
        }

        lastSweep = now;
        foreach (var (key, recent) in calls.ToList())
        {
            recent.Forget(now);
            if (recent.Times.Count == 0)
            {
                calls.Remove(key);
            }
        }
    }

    private const int SweepEverySeconds = 60;

    private sealed class Calls(int windowSeconds)
    {
        public Queue<long> Times { get; } = new();

        /// <summary>Drops calls that are no longer inside the window (a call counts while ts &gt; now - window).</summary>
        public void Forget(long now)
        {
            while (Times.Count > 0 && Times.Peek() <= now - windowSeconds)
            {
                Times.Dequeue();
            }
        }
    }
}
