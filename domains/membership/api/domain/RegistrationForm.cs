using Tsr.Shared.Api;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace Tsr.Membership.Api.Domain;

/// <summary>What POST /registration reads from the body, after PHP's trimming, whitelisting and casting.</summary>
internal sealed record RegistrationInput(
    string PreferredLocation,
    long BirthYear,
    long IslamicStudyYears,
    string? LinkedinUrl,
    string? ResidenceLocation,
    string? WorkLocation,
    string? Education,
    string? FieldOfStudy,
    string? FieldOfStudyOther,
    string? ProfessionalCourses,
    string? ProfessionalCoursesOther,
    string? OccupationType,
    string? FieldOfWork,
    string? YearsExperience,
    string? RoleLevel,
    string? OtherInterests);

/// <summary>The active labels of the seven lookup types the form checks against.</summary>
internal sealed record RegistrationLabels(
    IReadOnlyList<string> Education,
    IReadOnlyList<string> FieldOfStudy,
    IReadOnlyList<string> ProfessionalCourses,
    IReadOnlyList<string> OccupationType,
    IReadOnlyList<string> FieldOfWork,
    IReadOnlyList<string> YearsExperience,
    IReadOnlyList<string> RoleLevel);

internal static partial class RegistrationForm
{
    public const string RequiredMessage = "preferredLocation, birthYear and islamicStudyYears are required";

    // PHP: /^https?:\/\/(www\.)?linkedin\.com\/(in|pub|company)\/[\w-]+/i without /u: ASCII only. The value is lower-cased
    // (ASCII) before matching so a non-ASCII letter that .NET's ignore-case would fold (the Kelvin sign) cannot match.
    [GeneratedRegex(@"^https?://(www\.)?linkedin\.com/(in|pub|company)/[a-z0-9_-]+", RegexOptions.CultureInvariant)]
    private static partial Regex LinkedIn();

    /// <summary>The 422 message when a required field is empty after trim, or null. "0" study years are accepted.</summary>
    public static string? CheckRequired(JsonBody body)
    {
        var missing = TrimmedText(body, "preferredLocation").Length == 0
            || TrimmedText(body, "birthYear").Length == 0
            || TrimmedText(body, "islamicStudyYears").Length == 0;
        return missing ? RequiredMessage : null;
    }

    public static RegistrationInput Build(JsonBody body, RegistrationLabels labels)
    {
        ArgumentNullException.ThrowIfNull(body);
        ArgumentNullException.ThrowIfNull(labels);
        return new RegistrationInput(
            PreferredLocation: TrimmedText(body, "preferredLocation"),
            BirthYear: PhpValue.IntOfText(TrimmedText(body, "birthYear")),
            IslamicStudyYears: PhpValue.IntOfText(TrimmedText(body, "islamicStudyYears")),
            LinkedinUrl: LinkedinUrl(TrimmedText(body, "linkedinUrl")),
            ResidenceLocation: OptionalText(body, "residenceLocation"),
            WorkLocation: OptionalText(body, "workLocation"),
            Education: OneOf(body, "education", labels.Education),
            FieldOfStudy: ManyOf(body.Get("fieldOfStudy"), labels.FieldOfStudy),
            FieldOfStudyOther: OptionalText(body, "fieldOfStudyOther"),
            ProfessionalCourses: ManyOf(body.Get("professionalCourses"), labels.ProfessionalCourses),
            ProfessionalCoursesOther: OptionalText(body, "professionalCoursesOther"),
            OccupationType: OneOf(body, "occupationType", labels.OccupationType),
            FieldOfWork: OneOf(body, "fieldOfWork", labels.FieldOfWork),
            YearsExperience: OneOf(body, "yearsExperience", labels.YearsExperience),
            RoleLevel: OneOf(body, "roleLevel", labels.RoleLevel),
            OtherInterests: OptionalText(body, "otherInterests"));
    }

    // trim((string) ($body[field] ?? ''))
    private static string TrimmedText(JsonBody body, string field) => PhpText.Trim(PhpValue.Text(body.Get(field)));

    private static string? OptionalText(JsonBody body, string field)
    {
        var text = TrimmedText(body, field);
        return text.Length > 0 ? text : null;
    }

    // A dropdown value must equal a label exactly (PHP's strict in_array); anything else is silently null.
    private static string? OneOf(JsonBody body, string field, IReadOnlyList<string> labels)
    {
        var text = TrimmedText(body, field);
        return labels.Contains(text, StringComparer.Ordinal) ? text : null;
    }

    private static string? LinkedinUrl(string trimmed) =>
        trimmed.Length > 0 && LinkedIn().IsMatch(PhpText.LowerAscii(trimmed)) ? trimmed : null;

    // A multi-select: an array (or object) of values, each trimmed, kept when it is a label; stored as JSON text; null when none are kept.
    private static string? ManyOf(JsonElement value, IReadOnlyList<string> labels)
    {
        if (value.ValueKind is not (JsonValueKind.Array or JsonValueKind.Object))
        {
            return null;
        }

        var kept = new List<string>();
        foreach (var (_, item) in JsonBody.Entries(value))
        {
            // PHP's trim() throws a TypeError on an array: an uncaught error, a 500.
            if (item.ValueKind is JsonValueKind.Array or JsonValueKind.Object)
            {
                throw new InvalidOperationException("A multi-select value is not text.");
            }

            var text = PhpText.Trim(PhpValue.Text(item));
            if (labels.Contains(text, StringComparer.Ordinal))
            {
                kept.Add(text);
            }
        }

        return kept.Count > 0 ? JsonSerializer.Serialize(kept, MembershipJson.Default.ListString) : null;
    }
}
