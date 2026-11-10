using Microsoft.EntityFrameworkCore;
using Tsr.Identity.Api;
using Tsr.Membership.Api.Domain;

namespace Tsr.Membership.Api;

/// <summary>
/// Membership's half of the sign-in port (identity's <see cref="IProfileSink"/>): keeps the token's name and picture in the
/// member's profile, in the same request. A new member gets both, an absent one as empty text; a claimed member keeps what is
/// stored for a value the token does not carry, and a claim carrying neither writes nothing. A value longer than its column is
/// cut to fit (PHP's strict database would refuse the sign-in; a name is never worth that). One atomic upsert, so two sign-ins
/// racing on the same member cannot collide.
/// </summary>
internal sealed class ProfileSink(MembershipContext db) : IProfileSink
{
    private const int NameLength = 200;
    private const int PictureLength = 2000;

    public async Task RecordSignInAsync(int userId, string? name, string? picture, bool isNewMember, CancellationToken ct)
    {
        var newName = ProfileText.Cut(name, NameLength);
        var newPicture = ProfileText.Cut(picture, PictureLength);
        if (isNewMember)
        {
            await db.Database.ExecuteSqlAsync(
                $"""
                insert into membership.member_profiles (user_id, name, picture) values ({userId}, {newName ?? string.Empty}, {newPicture ?? string.Empty})
                on conflict (user_id) do update set name = excluded.name, picture = excluded.picture
                """,
                ct);
            return;
        }

        if (newName is null && newPicture is null)
        {
            return;
        }

        await db.Database.ExecuteSqlAsync(
            $"""
            insert into membership.member_profiles (user_id, name, picture) values ({userId}, {newName}, {newPicture})
            on conflict (user_id) do update set
              name = coalesce(excluded.name, member_profiles.name),
              picture = coalesce(excluded.picture, member_profiles.picture)
            """,
            ct);
    }
}
