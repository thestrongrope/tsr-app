using System.Text.Json;
using System.Text.Json.Nodes;

namespace Tsr.Membership.Api.Domain;

/// <summary>The payload of GET /registration, built from one stored row. Raw column values: not cast, not entity-decoded.</summary>
internal static class RegistrationView
{
    public static JsonObject Payload(ClassRegistration row)
    {
        ArgumentNullException.ThrowIfNull(row);
        return new JsonObject
        {
            ["preferredLocation"] = row.PreferredLocation,
            ["birthYear"] = row.BirthYear,
            ["islamicStudyYears"] = row.IslamicStudyYears,
            ["linkedinUrl"] = row.LinkedinUrl,
            ["residenceLocation"] = row.ResidenceLocation,
            ["workLocation"] = row.WorkLocation,
            ["education"] = row.Education,
            ["fieldOfStudy"] = DecodeList(row.FieldOfStudy),
            ["fieldOfStudyOther"] = row.FieldOfStudyOther,
            ["professionalCourses"] = DecodeList(row.ProfessionalCourses),
            ["professionalCoursesOther"] = row.ProfessionalCoursesOther,
            ["occupationType"] = row.OccupationType,
            ["fieldOfWork"] = row.FieldOfWork,
            ["yearsExperience"] = row.YearsExperience,
            ["roleLevel"] = row.RoleLevel,
            ["otherInterests"] = row.OtherInterests,
            ["status"] = row.Status,
        };
    }

    /// <summary>A multi-select column read back: a list of the stored values, empty when empty, invalid or not a list.</summary>
    public static JsonArray DecodeList(string? stored)
    {
        var list = new JsonArray();
        if (string.IsNullOrEmpty(stored))
        {
            return list;
        }

        JsonNode? decoded;
        try
        {
            decoded = JsonNode.Parse(stored);
        }
        catch (JsonException)
        {
            return list;
        }

        var values = decoded switch
        {
            JsonArray array => array.ToList(),
            JsonObject obj => obj.Select(p => p.Value).ToList(),
            _ => [],
        };
        foreach (var value in values)
        {
            list.Add(value?.DeepClone());
        }

        return list;
    }

    /// <summary>{language: {skill: proficiency}} in row order; the last row of a language and skill wins.</summary>
    public static JsonObject Languages(IEnumerable<LanguageEntry> rows)
    {
        var map = new JsonObject();
        foreach (var row in rows)
        {
            if (map[row.Language] is not JsonObject skills)
            {
                skills = [];
                map[row.Language] = skills;
            }

            skills[row.Skill] = row.Proficiency;
        }

        return map;
    }
}
