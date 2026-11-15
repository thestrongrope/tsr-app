using System.Text;

namespace Tsr.Membership.Api.Domain;

/// <summary>Text from a sign-in token, fitted to the profile's columns.</summary>
internal static class ProfileText
{
    /// <summary>The value cut to at most <paramref name="max"/> characters (code points, like the length CHECK), or null when it is null.</summary>
    public static string? Cut(string? value, int max)
    {
        if (value is null || value.Length <= max)
        {
            return value;
        }

        var cut = new StringBuilder(max);
        var count = 0;
        foreach (var rune in value.EnumerateRunes())
        {
            if (count == max)
            {
                break;
            }

            cut.Append(rune);
            count++;
        }

        return cut.ToString();
    }
}
