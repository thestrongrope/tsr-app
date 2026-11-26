using System.Text.Json.Nodes;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Membership.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Membership.Api.Features.RegistrationGet;

// Slice: GET /registration -> the member's saved class request, the interest list, their choices and languages.
// Signed in, no permission (PHP checks none). Contract: spec/api.yaml. PHP: routes/registration.php route_registration_get.

internal static class RegistrationGetEndpoint
{
    public static IEndpointRouteBuilder MapRegistrationGet(this IEndpointRouteBuilder routes)
    {
        routes.MapGet(
            "/registration",
            (HttpContext context, RegistrationGetHandler handler) => handler.HandleAsync(context.GetCaller(), context.RequestAborted))
            .RequireMember(createsMember: true);
        return routes;
    }
}

internal sealed class RegistrationGetHandler(NpgsqlDataSource source)
{
    /// <summary>A safety bound on each list; the form has 19 options and a member has a handful of choices and skills.</summary>
    private const int MaxRows = 500;

    public async Task<IResult> HandleAsync(Caller? caller, CancellationToken ct)
    {
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var token = caller.Token;

        // PHP's fetch() takes the table's first row for the token (no ORDER BY; the table holds duplicates): the lowest id.
        var registration = (await source.ListAsync(
            $"""
            select id, token, for_classid, residence_location, work_location, preferred_location, class_level, class_number, birth_year, profession, islamic_study_years,
                   interests, other_interests, education, field_of_study::text as field_of_study, field_of_study_other, professional_courses::text as professional_courses,
                   professional_courses_other, occupation_type, field_of_work, years_experience, role_level, linkedin_url, status, status_date, status_reason,
                   created_at, modified_at, modified_by
            from membership.class_registrations where token = {token} order by id limit 1
            """,
            ReadRegistration,
            ct)).FirstOrDefault();

        var options = await source.ListAsync(
            $"select id, name from membership.interest_options where is_active order by sort_order, name limit {MaxRows}",
            row => (Id: row.Int("id"), Name: row.Text("name")),
            ct);

        var selected = await source.ListAsync(
            $"""
            select s.interest_id from membership.student_interests s
            join membership.interest_options o on o.id = s.interest_id
            where s.token = {token} order by s.interest_id limit {MaxRows}
            """,
            row => row.Int("interest_id"),
            ct);

        var languages = await source.ListAsync(
            $"select language, skill, proficiency from membership.class_registrations_languages where token = {token} order by id limit {MaxRows}",
            row => new LanguageEntry(row.TextOrNull("language") ?? string.Empty, row.TextOrNull("skill") ?? string.Empty, row.TextOrNull("proficiency") ?? string.Empty),
            ct);

        return Results.Json(
            new JsonObject
            {
                ["registration"] = registration is null ? null : RegistrationView.Payload(registration),
                ["interestOptions"] = new JsonArray(options.Select(o => (JsonNode)new JsonObject { ["id"] = o.Id, ["name"] = o.Name }).ToArray()),
                ["selectedInterestIds"] = new JsonArray(selected.Select(id => (JsonNode)id).ToArray()),
                ["languages"] = RegistrationView.Languages(languages),
            },
            MembershipJson.Answers.JsonObject);
    }

    private static ClassRegistration ReadRegistration(DbRow row) => new()
    {
        Id = row.Int("id"),
        Token = row.IntOrNull("token"),
        ForClassId = row.IntOrNull("for_classid"),
        ResidenceLocation = row.TextOrNull("residence_location"),
        WorkLocation = row.TextOrNull("work_location"),
        PreferredLocation = row.TextOrNull("preferred_location"),
        ClassLevel = row.TextOrNull("class_level"),
        ClassNumber = row.TextOrNull("class_number"),
        BirthYear = row.IntOrNull("birth_year"),
        Profession = row.TextOrNull("profession"),
        IslamicStudyYears = row.IntOrNull("islamic_study_years"),
        Interests = row.TextOrNull("interests"),
        OtherInterests = row.TextOrNull("other_interests"),
        Education = row.TextOrNull("education"),
        FieldOfStudy = row.TextOrNull("field_of_study"),
        FieldOfStudyOther = row.TextOrNull("field_of_study_other"),
        ProfessionalCourses = row.TextOrNull("professional_courses"),
        ProfessionalCoursesOther = row.TextOrNull("professional_courses_other"),
        OccupationType = row.TextOrNull("occupation_type"),
        FieldOfWork = row.TextOrNull("field_of_work"),
        YearsExperience = row.TextOrNull("years_experience"),
        RoleLevel = row.TextOrNull("role_level"),
        LinkedinUrl = row.TextOrNull("linkedin_url"),
        Status = row.Text("status"),
        StatusDate = row.InstantOrNull("status_date"),
        StatusReason = row.TextOrNull("status_reason"),
        CreatedAt = row.Instant("created_at"),
        ModifiedAt = row.InstantOrNull("modified_at"),
        ModifiedBy = row.IntOrNull("modified_by"),
    };
}
