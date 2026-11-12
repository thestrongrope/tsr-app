using Microsoft.EntityFrameworkCore;
using Tsr.Identity.Api;

namespace Tsr.Membership.Api;

/// <summary>Membership's half of the erasure port (identity's <see cref="IMemberErasure"/>): anonymises the profile and the class requests with <see cref="MembershipCommands.EraseMemberAsync"/>.</summary>
internal sealed class MemberErasure : IMemberErasure
{
    public Task EraseAsync(DbContext db, int token, CancellationToken ct) => MembershipCommands.EraseMemberAsync(db, token, ct);
}
