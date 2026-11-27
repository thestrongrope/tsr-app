namespace Tsr.Assessment.Api.Domain;

/// <summary>
/// After a failed or timed-out read of the settings sheet for a request, no request tries again for <see cref="QuizSettingsRefresh.MaxAge"/> (the saved copy is served meanwhile), so a sheet that is down or slow
/// is not read, and lock 5002 not held for up to 5 seconds, by every public call. In memory, per API instance (a restart or a second instance tries once more); the saved copy's <c>updated_at</c> is not touched.
/// The admin refresh never asks it.
/// </summary>
internal sealed class SheetReadBackoff(TimeProvider clock)
{
    private long failedAtTicks;

    public bool Waiting
    {
        get
        {
            var failed = Volatile.Read(ref failedAtTicks);
            return failed != 0 && clock.GetUtcNow().UtcTicks - failed < QuizSettingsRefresh.MaxAge.Ticks;
        }
    }

    public void Failed() => Volatile.Write(ref failedAtTicks, clock.GetUtcNow().UtcTicks);

    public void Succeeded() => Volatile.Write(ref failedAtTicks, 0);
}
