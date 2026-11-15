using Tsr.Shared.Api;
using System.Text.Json;

namespace Tsr.Membership.Api.Domain;

/// <summary>One language skill the form saves.</summary>
internal sealed record LanguageEntry(string Language, string Skill, string Proficiency);

/// <summary>The nested <c>languages</c> map and the <c>interestIds</c> list of POST /registration.</summary>
internal static class RegistrationParts
{
    private const string DontKnow = "Don't Know";

    private static readonly string[] ValidLanguages = ["Arabic", "English", "Gujarati", "Hindi", "Persian", "Urdu"];
    private static readonly string[] ValidSkills = ["Read", "Speak", "Understand", "Write"];
    private static readonly string[] ValidProficiencies = ["Beginner", DontKnow, "Fluent", "Learning"];

    /// <summary>
    /// PHP replaces the saved languages only when the value is a non-empty array (or object), and then keeps the entries whose
    /// language, skill and proficiency are in the lists (case-sensitive). Returns null when nothing is to be replaced.
    /// </summary>
    public static IReadOnlyList<LanguageEntry>? Languages(JsonElement value)
    {
        var languages = JsonBody.Entries(value);
        if (languages.Count == 0)
        {
            return null;
        }

        var kept = new List<LanguageEntry>();
        foreach (var (language, skills) in languages)
        {
            if (!ValidLanguages.Contains(language, StringComparer.Ordinal))
            {
                continue;
            }

            foreach (var (skill, proficiency) in JsonBody.Entries(skills))
            {
                if (IsSaved(skill, proficiency))
                {
                    kept.Add(new LanguageEntry(language, skill, proficiency.GetString()!));
                }
            }
        }

        return kept;
    }

    /// <summary>The interest ids PHP keeps: null when the value is not an array (the saved choices stay), else the (int) of each element that is an active option, duplicates and order kept.</summary>
    public static IReadOnlyList<int>? InterestIds(JsonElement value, IReadOnlySet<int> activeIds)
    {
        ArgumentNullException.ThrowIfNull(activeIds);
        if (value.ValueKind is not (JsonValueKind.Array or JsonValueKind.Object))
        {
            return null;
        }

        var kept = new List<int>();
        foreach (var (_, item) in JsonBody.Entries(value))
        {
            var id = PhpValue.ToInteger(item);
            if (id is >= int.MinValue and <= int.MaxValue && activeIds.Contains((int)id))
            {
                kept.Add((int)id);
            }
        }

        return kept;
    }

    private static bool IsSaved(string skill, JsonElement proficiency) =>
        ValidSkills.Contains(skill, StringComparer.Ordinal)
        && proficiency.ValueKind == JsonValueKind.String
        && ValidProficiencies.Contains(proficiency.GetString(), StringComparer.Ordinal)
        && proficiency.GetString() != DontKnow;
}
