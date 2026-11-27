using System.Globalization;
using NUnit.Framework;

namespace Tsr.Assessment.Api.Domain;

[TestFixture]
internal sealed class SheetReadBackoffTests
{
    private sealed class Clock : TimeProvider
    {
        public DateTimeOffset Now { get; set; } = DateTimeOffset.Parse("2026-12-02T06:30:00+00:00", CultureInfo.InvariantCulture);

        public override DateTimeOffset GetUtcNow() => Now;
    }

    [Test]
    public void A_backoff_that_saw_no_failure_does_not_wait()
    {
        var backoff = new SheetReadBackoff(new Clock());

        Assert.That(backoff.Waiting, Is.False);
    }

    [Test]
    public void A_failed_read_is_not_tried_again_at_59_seconds_and_is_at_60()
    {
        var clock = new Clock();
        var backoff = new SheetReadBackoff(clock);
        backoff.Failed();

        Assert.That(backoff.Waiting, Is.True, "at once");
        clock.Now += TimeSpan.FromSeconds(59);
        Assert.That(backoff.Waiting, Is.True, "+59 s");
        clock.Now += TimeSpan.FromSeconds(1);
        Assert.That(backoff.Waiting, Is.False, "+60 s");
    }

    [Test]
    public void A_success_clears_it()
    {
        var backoff = new SheetReadBackoff(new Clock());
        backoff.Failed();

        backoff.Succeeded();

        Assert.That(backoff.Waiting, Is.False);
    }
}
