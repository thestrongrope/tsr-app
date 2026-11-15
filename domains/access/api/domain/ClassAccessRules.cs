using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using Tsr.Shared.Api;

namespace Tsr.Access.Api.Domain;

/// <summary>One condition as the client sent it, before it is checked: a text value or a whole number.</summary>
internal sealed record RawCondition(string Field, bool Negate, string? Text, long? Number);

/// <summary>
/// The rules of a class access grant that need no database (PHP ClassAccessModel): which conditions are valid, the order and
/// identity of a rule, its note, the version a write echoes, the preview hash, and which cities, countries and tags an operator may use.
/// Which classes a rule reaches is <see cref="RuleMatcher"/>, the same code the engine decides with.
/// </summary>
internal static partial class ClassAccessRules
{
    public const int MaxClasses = 200;
    public const int MaxValue = 300;
    public const int MaxValuesPerField = 50;
    public const int MaxOffered = 500;
    public const int MaxNote = 255;
    public const int RoleMember = 0;
    public const int RoleSuperAdmin = 1;
    public const int RoleGentsAdmin = 3;
    public const int RoleLadiesAdmin = 4;
    public const int RoleClassAdmin = 5;
    public const int RoleFinance = 7;

    public static readonly IReadOnlyList<int> Genders = [1, 2];

    private static readonly string[] Fields = ["city", "country", "level", "tag"];
    private static readonly string[] NoteOrder = ["level", "city", "country", "tag"];

    [GeneratedRegex(@"\s+", RegexOptions.CultureInvariant, matchTimeoutMilliseconds: 200)]
    private static partial Regex Whitespace();

    public static string GenderLabel(int gender) => gender == 1 ? "Gents" : "Ladies";

    /// <summary>The gender of a rule: 1 or 2, or left out (null) for either.</summary>
    public static Refusal? CheckedGender(int? gender) =>
        gender is null || Genders.Contains(gender.Value)
            ? null
            : new Refusal(422, "The gender must be 1 or 2, or left out for either");

    /// <summary>
    /// The conditions of a new grant: at least one, IN only (NOT IN stays a migration), each valid, without repeats, in a fixed order, at most 50 values per field.
    /// A level must exist: <see cref="ClassAccessStore"/> checks that against the levels.
    /// </summary>
    public static Outcome<IReadOnlyList<RuleCondition>> CheckedConditions(IReadOnlyList<RawCondition> raw)
    {
        if (raw.Count == 0)
        {
            return Outcome<IReadOnlyList<RuleCondition>>.Fail(422, "Choose at least one condition");
        }

        var checkedList = new List<RuleCondition>();
        foreach (var condition in raw)
        {
            var one = CheckedOne(condition);
            if (one.Failed)
            {
                return Outcome<IReadOnlyList<RuleCondition>>.Fail(one.Refusal!);
            }

            checkedList.Add(one.Value!);
        }

        var ordered = Ordered(checkedList);
        return ordered.GroupBy(c => c.Field).Any(g => g.Count() > MaxValuesPerField)
            ? Outcome<IReadOnlyList<RuleCondition>>.Fail(422, "Too many values for one condition (at most 50)")
            : Outcome<IReadOnlyList<RuleCondition>>.Ok(ordered);
    }

    private static Outcome<RuleCondition> CheckedOne(RawCondition condition)
    {
        if (!Fields.Contains(condition.Field, StringComparer.Ordinal))
        {
            return Outcome<RuleCondition>.Fail(422, "Unknown condition field");
        }

        if (condition.Negate)
        {
            return Outcome<RuleCondition>.Fail(422, "Only conditions that include classes can be added");
        }

        if (condition.Field == "level")
        {
            if (condition.Number is not long level || level < 1)
            {
                return Outcome<RuleCondition>.Fail(422, "A level is a level id");
            }

            return level > int.MaxValue
                ? Outcome<RuleCondition>.Fail(422, "Unknown level")
                : Outcome<RuleCondition>.Ok(new RuleCondition("level", false, null, (int)level));
        }

        var text = condition.Text is null ? string.Empty : PhpText.Trim(Whitespace().Replace(condition.Text, " "));
        if (text.Length == 0)
        {
            return Outcome<RuleCondition>.Fail(422, "A condition needs a value");
        }

        return PhpText.CodePointCount(text) > MaxValue
            ? Outcome<RuleCondition>.Fail(422, "A condition value must be 300 characters or fewer")
            : Outcome<RuleCondition>.Ok(new RuleCondition(condition.Field, false, text, null));
    }

    /// <summary>The id of one condition: field, direction and lower-case value. The same key means the same condition.</summary>
    public static string ConditionKey(RuleCondition condition) =>
        condition.Field.ToLowerInvariant() + "|" + (condition.Negate ? "not" : "in") + "|"
        + (condition.Value ?? condition.LevelId?.ToString(CultureInfo.InvariantCulture) ?? string.Empty).ToLowerInvariant();

    /// <summary>Without repeats (a later one replaces an earlier one with the same key), in the order the keys sort to (natural order, as strnatcmp).</summary>
    public static IReadOnlyList<RuleCondition> Ordered(IEnumerable<RuleCondition> conditions)
    {
        var byKey = new Dictionary<string, RuleCondition>(StringComparer.Ordinal);
        foreach (var condition in conditions)
        {
            byKey[ConditionKey(condition)] = condition;
        }

        return byKey.OrderBy(pair => pair.Key, Comparer<string>.Create(NaturalCompare)).Select(pair => pair.Value).ToList();
    }

    /// <summary>The same gender and the same set of conditions give the same key; a subset does not.</summary>
    public static string AccessKey(int? gender, IEnumerable<RuleCondition> conditions)
    {
        var keys = conditions.Select(ConditionKey).Distinct(StringComparer.Ordinal).Order(Comparer<string>.Create(NaturalCompare));
        return (gender?.ToString(CultureInfo.InvariantCulture) ?? "any") + "/" + string.Join(';', keys);
    }

    /// <summary>"Gents, levels 3-5, Pune": the label of a rule (the view shows it as the rule's note).</summary>
    public static string NoteFor(int? gender, IReadOnlyList<RuleCondition> conditions)
    {
        var parts = new List<string> { gender is int g ? GenderLabel(g) : "Any gender" };
        foreach (var field in NoteOrder)
        {
            var ofField = conditions.Where(c => c.Field == field).ToList();
            if (ofField.Count == 0)
            {
                continue;
            }

            parts.Add(field == "level"
                ? (ofField.Count > 1 ? "levels " : "level ") + Ranges(ofField.Select(c => c.LevelId ?? 0))
                : string.Join(", ", ofField.Select(c => c.Value)));
        }

        var note = string.Join(", ", parts);
        return PhpText.CodePointCount(note) <= MaxNote ? note : string.Concat(note.EnumerateRunes().Take(MaxNote).Select(r => r.ToString()));
    }

    /// <summary>[2, 4, 5] gives "2, 4-5".</summary>
    public static string Ranges(IEnumerable<int> ids)
    {
        var runs = new List<(int First, int Last)>();
        foreach (var id in ids.Order())
        {
            if (runs.Count > 0 && runs[^1].Last == id - 1)
            {
                runs[^1] = (runs[^1].First, id);
                continue;
            }

            runs.Add((id, id));
        }

        return string.Join(", ", runs.Select(r => r.First == r.Last ? r.First.ToString(CultureInfo.InvariantCulture) : r.First.ToString(CultureInfo.InvariantCulture) + "-" + r.Last.ToString(CultureInfo.InvariantCulture)));
    }

    /// <summary>The version a write echoes back: the member's role id and a fingerprint of their live rule ids, so a change by anyone else is seen. Nothing is stored.</summary>
    public static string VersionOf(int roleId, IEnumerable<int> liveRuleIds) =>
        roleId.ToString(CultureInfo.InvariantCulture) + ":" + Fingerprint(liveRuleIds);

    /// <summary>Names the whole set of classes a preview reaches, however many are listed: the first 16 hex characters of the sha256 of the sorted ids, comma-joined.</summary>
    public static string PreviewHash(IEnumerable<int> classIds) => Fingerprint(classIds);

    private static string Fingerprint(IEnumerable<int> ids)
    {
        var text = string.Join(',', ids.Order().Select(i => i.ToString(CultureInfo.InvariantCulture)));
        return Convert.ToHexStringLower(SHA256.HashData(Encoding.UTF8.GetBytes(text)))[..16];
    }

    /// <summary>hash_equals: the same text, compared in constant time.</summary>
    public static bool SameHash(string expected, string actual) =>
        CryptographicOperations.FixedTimeEquals(Encoding.UTF8.GetBytes(expected), Encoding.UTF8.GetBytes(actual));

    /// <summary>The active classes a rule of this gender (null = either) and these conditions reaches, in the order given: the matcher the engine uses.</summary>
    public static IReadOnlyList<ClassFacts> Reach(int? gender, IReadOnlyList<RuleCondition> conditions, IEnumerable<ClassFacts> classes)
    {
        var rule = new AccessRule(gender, conditions);
        return classes.Where(c => RuleMatcher.Matches(rule, c)).ToList();
    }

    /// <summary>The cities of the classes of these genders: sorted, one spelling per city (the first in ordinal order), at most 500.</summary>
    public static IReadOnlyList<string> Cities(IEnumerable<ClassFacts> classes, IReadOnlyCollection<int> genders) =>
        OfferedTexts(classes.Where(c => genders.Contains(c.Gender)).Select(c => c.City));

    public static IReadOnlyList<string> Countries(IEnumerable<ClassFacts> classes, IReadOnlyCollection<int> genders) =>
        OfferedTexts(classes.Where(c => genders.Contains(c.Gender)).Select(c => c.Country));

    public static IReadOnlyList<string> Tags(IEnumerable<ClassFacts> classes, IReadOnlyCollection<int> genders) =>
        OfferedTexts(classes.Where(c => genders.Contains(c.Gender)).SelectMany(c => c.Tags));

    private static List<string> OfferedTexts(IEnumerable<string?> values)
    {
        var distinct = values.Where(v => !string.IsNullOrEmpty(v)).Select(v => v!).Distinct(StringComparer.Ordinal)
            .Order(StringComparer.Ordinal).Take(MaxOffered);
        var byLower = new Dictionary<string, string>(StringComparer.Ordinal);
        foreach (var value in distinct)
        {
            byLower.TryAdd(value.ToLowerInvariant(), value);
        }

        return byLower.Values.OrderBy(v => PhpText.LowerAscii(v), StringComparer.Ordinal).ToList();
    }

    /// <summary>
    /// The conditions with every city, country and tag given the spelling offered to this operator; one that is not offered is a 422.
    /// Levels pass through. Repeats the order and de-duplication, because a spelling can make two conditions the same.
    /// </summary>
    public static Outcome<IReadOnlyList<RuleCondition>> OfferedValues(
        IReadOnlyList<RuleCondition> conditions,
        IReadOnlyList<string> cities,
        IReadOnlyList<string> countries,
        IReadOnlyList<string> tags)
    {
        var mapped = new List<RuleCondition>();
        foreach (var condition in conditions)
        {
            if (condition.Field == "level")
            {
                mapped.Add(condition);
                continue;
            }

            var offered = condition.Field switch { "city" => cities, "country" => countries, _ => tags };
            var spelling = offered.FirstOrDefault(o => string.Equals(o, condition.Value, StringComparison.OrdinalIgnoreCase));
            if (spelling is null)
            {
                return Outcome<IReadOnlyList<RuleCondition>>.Fail(422, "Choose a " + condition.Field + " from the list");
            }

            mapped.Add(condition with { Value = spelling });
        }

        return Outcome<IReadOnlyList<RuleCondition>>.Ok(Ordered(mapped));
    }

    /// <summary>PHP strnatcmp in the cases that occur here: runs of digits compare as numbers, anything else by character.</summary>
    public static int NaturalCompare(string left, string right)
    {
        int i = 0, j = 0;
        while (i < left.Length && j < right.Length)
        {
            if (char.IsAsciiDigit(left[i]) && char.IsAsciiDigit(right[j]))
            {
                var (a, nextI) = DigitRun(left, i);
                var (b, nextJ) = DigitRun(right, j);
                i = nextI;
                j = nextJ;
                var byLength = a.Length.CompareTo(b.Length);
                var difference = byLength != 0 ? byLength : string.CompareOrdinal(a, b);
                if (difference != 0)
                {
                    return difference;
                }

                continue;
            }

            if (left[i] != right[j])
            {
                return left[i].CompareTo(right[j]);
            }

            i++;
            j++;
        }

        return (left.Length - i).CompareTo(right.Length - j);
    }

    private static (string Digits, int Next) DigitRun(string text, int start)
    {
        var end = start;
        while (end < text.Length && char.IsAsciiDigit(text[end]))
        {
            end++;
        }

        return (text[start..end].TrimStart('0'), end);
    }
}
