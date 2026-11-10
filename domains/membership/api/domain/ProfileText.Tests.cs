using NUnit.Framework;
using Tsr.Membership.Api.Domain;

namespace Tsr.Membership.Api.Tests.Domain;

/// <summary>A name or picture from a token is cut to its column's length, counted in characters (code points), as the CHECK counts them.</summary>
public sealed class ProfileTextTests
{
    [Test]
    public void Null_stays_null()
    {
        Assert.That(ProfileText.Cut(null, 5), Is.Null);
    }

    [Test]
    public void Text_within_the_limit_is_unchanged()
    {
        Assert.That(ProfileText.Cut("abcde", 5), Is.EqualTo("abcde"));
    }

    [Test]
    public void Text_over_the_limit_is_cut_to_it()
    {
        Assert.That(ProfileText.Cut("abcdefgh", 5), Is.EqualTo("abcde"));
    }

    [Test]
    public void A_character_outside_the_basic_plane_counts_once_and_is_never_split()
    {
        const string Emoji = "\U0001F600";

        Assert.That(ProfileText.Cut(Emoji + Emoji + Emoji, 2), Is.EqualTo(Emoji + Emoji));
    }
}
