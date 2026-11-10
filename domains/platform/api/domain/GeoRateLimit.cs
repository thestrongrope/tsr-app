namespace Tsr.Platform.Api.Domain;

/// <summary>
/// 60 geo calls in any 60 seconds per member, in memory in this process (PHP keeps one small file per member on its
/// host). Like PHP's rate_limit_allows: whole seconds, the window slides, a refused call is not recorded, and members
/// idle for a window are forgotten so the table cannot grow without bound. With several API instances each would
/// allow 60 (a known weakness, phase-3-platform-design.md decision 2).
/// </summary>
internal sealed class GeoRateLimit(TimeProvider clock)
{
    public const int MaxCalls = 60;

    public const int WindowSeconds = 60;

    private readonly object gate = new();
    private readonly Dictionary<int, Queue<long>> calls = [];
    private long lastSweep;

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

    /// <summary>True when the member's call is allowed (and recorded); false when it is the 61st in the window.</summary>
    public bool Allow(int token)
    {
        var now = clock.GetUtcNow().ToUnixTimeSeconds();
        lock (gate)
        {
            SweepIfDue(now);
            if (!calls.TryGetValue(token, out var recent))
            {
                recent = new Queue<long>();
                calls[token] = recent;
            }

            Forget(recent, now);
            if (recent.Count >= MaxCalls)
            {
                return false;
            }

            recent.Enqueue(now);
            return true;
        }
    }

    private void SweepIfDue(long now)
    {
        if (now - lastSweep < WindowSeconds)
        {
            return;
        }

        lastSweep = now;
        foreach (var (token, recent) in calls.ToList())
        {
            Forget(recent, now);
            if (recent.Count == 0)
            {
                calls.Remove(token);
            }
        }
    }

    /// <summary>Drops calls that are no longer inside the window (a call counts while ts &gt; now - 60).</summary>
    private static void Forget(Queue<long> recent, long now)
    {
        while (recent.Count > 0 && recent.Peek() <= now - WindowSeconds)
        {
            recent.Dequeue();
        }
    }
}
