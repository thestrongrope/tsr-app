using System.Text.RegularExpressions;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

/// <summary>
/// PHP <c>ClassStudentsModel::parseBulkLine</c>, <c>nameKey</c>, <c>maskedName</c> and the planning loop of <c>bulkEnrol</c>, apart from any database: what each pasted line is, which lines need
/// the caller's answer, and what to write. Mobile matches are looked up by the caller (one query) and handed in by <see cref="MobileKey"/>; the stored side of the comparison is in the SQL.
/// </summary>
internal static partial class BulkLines
{
    public const int MaxLines = 200;
    public const int MaxLineLength = 300;
    private const int MaxNameLength = 100;

    internal sealed record Parsed(string Name, string Mobile, string? Error);

    /// <summary>An existing member a mobile number matched (already limited to the class's gender or unknown).</summary>
    internal sealed record Member(int Token, string Name);

    /// <summary>One answered line. Status: ready, rejected, duplicate_name, mobile_match (later added or enrolled by the writer). MemberName is the masked name.</summary>
    internal sealed record Line(int Number, string Name, string Status, string? Reason, string? MemberName);

    /// <summary>One write: enrol an existing member (EnrolToken) or create a member from Name and Mobile.</summary>
    internal sealed record Step(int Line, int? EnrolToken, string Name, string Mobile);

    /// <summary>Status: confirm (a line needs an answer, nothing is written), none (nothing to write), added (write the plan).</summary>
    internal sealed record Result(string Status, IReadOnlyList<Line> Lines, IReadOnlyList<Step> Plan);

    [GeneratedRegex(@"\s+")]
    private static partial Regex WhiteSpace();

    [GeneratedRegex(@"^\+?[0-9 \-]+$")]
    private static partial Regex MobileShape();

    public static Parsed Parse(string line)
    {
        var comma = line.IndexOf(',', StringComparison.Ordinal);
        var name = PhpText.Trim(comma < 0 ? line : line[..comma]);
        var mobile = comma < 0 ? string.Empty : PhpText.Trim(line[(comma + 1)..]);
        if (name.Length == 0)
        {
            return new Parsed(name, string.Empty, "The name is missing.");
        }

        if (PhpText.CodePointCount(name) > MaxNameLength)
        {
            return new Parsed(name, string.Empty, "The name is longer than 100 characters.");
        }

        if (mobile.Length == 0)
        {
            return new Parsed(name, string.Empty, null);
        }

        var digits = mobile.Count(c => c is >= '0' and <= '9');
        if (!MobileShape().IsMatch(mobile) || digits < 7 || digits > 15)
        {
            return new Parsed(name, string.Empty, "The mobile number is not valid.");
        }

        return new Parsed(name, mobile.Replace(" ", string.Empty, StringComparison.Ordinal).Replace("-", string.Empty, StringComparison.Ordinal), null);
    }

    public static string NameKey(string name) => WhiteSpace().Replace(PhpText.Trim(name), " ").ToLowerInvariant();

    /// <summary>First name and last initial: enough to recognise someone, not to identify them.</summary>
    public static string MaskedName(string name)
    {
        var words = WhiteSpace().Split(PhpText.Trim(name)).Where(w => w.Length > 0).ToArray();
        if (words.Length < 2)
        {
            return words.Length == 0 ? string.Empty : words[0];
        }

        return words[0] + " " + words[^1].EnumerateRunes().First().ToString() + ".";
    }

    /// <summary>PHP <c>substr(preg_replace('/\D/', '', $mobile), -10)</c>: the last ten digits (all of them when fewer).</summary>
    public static string MobileKey(string mobile)
    {
        var digits = new string(mobile.Where(c => c is >= '0' and <= '9').ToArray());
        return digits.Length <= 10 ? digits : digits[^10..];
    }

    /// <param name="matches">The member for each <see cref="MobileKey"/> that matches one.</param>
    /// <param name="enrolledTokens">Active students of the class; the set is updated as lines enrol members.</param>
    /// <param name="enrolledNames">Name keys of the active students; the set is updated as lines add members.</param>
    public static Result Classify(
        IReadOnlyList<string> lines,
        IReadOnlyDictionary<int, string> resolutions,
        IReadOnlyDictionary<string, Member> matches,
        HashSet<int> enrolledTokens,
        HashSet<string> enrolledNames)
    {
        var answered = new List<Line>();
        var plan = new List<Step>();
        var pending = false;
        for (var i = 0; i < lines.Count; i++)
        {
            var number = i + 1;
            if (PhpText.Trim(lines[i]).Length == 0)
            {
                continue;
            }

            var parsed = Parse(lines[i]);
            if (parsed.Error is not null)
            {
                answered.Add(new Line(number, parsed.Name, "rejected", parsed.Error, null));
                continue;
            }

            Member? member = null;
            if (parsed.Mobile.Length > 0 && matches.TryGetValue(MobileKey(parsed.Mobile), out var found))
            {
                member = found;
            }

            if (member is not null && enrolledTokens.Contains(member.Token))
            {
                answered.Add(new Line(number, parsed.Name, "rejected", "That member is already in this class.", null));
                continue;
            }

            resolutions.TryGetValue(number, out var choice);
            var key = NameKey(parsed.Name);
            var flag = member is not null ? "mobile_match" : enrolledNames.Contains(key) ? "duplicate_name" : null;
            var accepted = flag == "mobile_match" ? new[] { "enrol", "add", "skip" } : new[] { "add", "skip" };
            if (flag is not null && !accepted.Contains(choice))
            {
                answered.Add(new Line(number, parsed.Name, flag, null, member is null ? null : MaskedName(member.Name)));
                pending = true;
                continue;
            }

            answered.Add(Resolve(number, parsed, member, flag is null ? "add" : choice!, key, plan, enrolledTokens, enrolledNames));
        }

        var status = pending ? "confirm" : plan.Count == 0 ? "none" : "added";
        return new Result(status, answered, pending ? [] : plan);
    }

    private static Line Resolve(int number, Parsed parsed, Member? member, string action, string key, List<Step> plan, HashSet<int> enrolledTokens, HashSet<string> enrolledNames)
    {
        if (action == "skip")
        {
            return new Line(number, parsed.Name, "rejected", "Skipped.", null);
        }

        if (action == "enrol")
        {
            enrolledTokens.Add(member!.Token);
            plan.Add(new Step(number, member.Token, string.Empty, string.Empty));
            return new Line(number, parsed.Name, "ready", null, MaskedName(member.Name));
        }

        enrolledNames.Add(key);
        plan.Add(new Step(number, null, parsed.Name, parsed.Mobile));
        return new Line(number, parsed.Name, "ready", null, null);
    }
}
