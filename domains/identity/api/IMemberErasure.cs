using Tsr.Shared.Api;

namespace Tsr.Identity.Api;

/// <summary>
/// The second port identity declares: completing an account deletion anonymises the member's profile and class requests, which are
/// <c>membership</c>'s tables. membership references identity, so identity cannot call it directly; membership supplies the real
/// implementation (<c>MembershipCommands.EraseMemberAsync</c>). Until one is registered <see cref="NoMemberErasure"/> does nothing.
/// </summary>
public interface IMemberErasure
{
    /// <summary>Anonymises the profile data of <paramref name="token"/> on the caller's connection and transaction.</summary>
    Task EraseAsync(DbTx tx, int token, CancellationToken ct);
}

/// <summary>The default: nothing to erase.</summary>
internal sealed class NoMemberErasure : IMemberErasure
{
    public Task EraseAsync(DbTx tx, int token, CancellationToken ct) => Task.CompletedTask;
}
