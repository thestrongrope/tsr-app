using System.Text.Json.Nodes;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Membership.Api.Domain;
using Tsr.Platform.Api;
using Tsr.Shared.Api;

namespace Tsr.Membership.Api.Features.RegistrationSave;

// Slice: POST /registration -> create or update the member's class request, replace their languages and interest choices.
// Signed in, no permission (PHP checks none). Contract: spec/api.yaml. PHP: routes/registration.php route_registration_save,
// SubscribersModel::AddRegistration, UpdateRegistration, saveLanguageProficiencies, saveStudentInterests.
// Quirks copied on purpose (capabilities/class-request.md): the three writes are separate and unguarded, an update changes every row of
// the token and wipes for_classid, profession and interests, a non-empty languages map of invalid entries still erases the saved ones.

internal static class RegistrationSaveEndpoint
{
    public static IEndpointRouteBuilder MapRegistrationSave(this IEndpointRouteBuilder routes)
    {
        routes.MapPost(
            "/registration",
            (HttpContext context, RegistrationSaveHandler handler) =>
                handler.HandleAsync(context.GetCaller(), context.Request, context.RequestAborted))
            .RequireMember(createsMember: true);
        return routes;
    }
}

internal sealed class RegistrationSaveHandler(NpgsqlDataSource source, Lookups lookups, TimeProvider clock)
{
    public async Task<IResult> HandleAsync(Caller? caller, HttpRequest request, CancellationToken ct)
    {
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var raw = await BodyReader.ReadAsync(request, ct);
        if (raw is null)
        {
            return Problem.Detail(StatusCodes.Status413PayloadTooLarge, "Request body too large");
        }

        var parsed = JsonBody.Parse(raw);
        if (!parsed.IsSuccess)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, parsed.Error!);
        }

        var body = parsed.Value!;
        if (RegistrationForm.CheckRequired(body) is { } missing)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, missing);
        }

        var input = RegistrationForm.Build(body, await LabelsAsync(ct));
        await SaveFormAsync(caller.Token, input, ct);
        await SaveLanguagesAsync(caller.Token, body, ct);
        await SaveInterestsAsync(caller.Token, body, ct);
        return Results.Json(new JsonObject { ["success"] = true, ["message"] = "Class request submitted successfully" }, MembershipJson.Answers.JsonObject);
    }

    // PHP reads all seven lists whether or not the body names them; an unseeded type throws (a 500).
    private async Task<RegistrationLabels> LabelsAsync(CancellationToken ct) => new(
        await lookups.LabelsAsync("education", ct),
        await lookups.LabelsAsync("field_of_study", ct),
        await lookups.LabelsAsync("professional_courses", ct),
        await lookups.LabelsAsync("occupation_type", ct),
        await lookups.LabelsAsync("field_of_work", ct),
        await lookups.LabelsAsync("years_experience", ct),
        await lookups.LabelsAsync("role_level", ct));

    private async Task SaveFormAsync(int token, RegistrationInput input, CancellationToken ct)
    {
        var birthYear = checked((int)input.BirthYear);
        var studyYears = checked((int)input.IslamicStudyYears);
        var existing = await source.ListAsync($"select 1 as \"Value\" from membership.class_registrations where token = {token} limit 1", row => row.Int("Value"), ct);
        if (existing.Count > 0)
        {
            await UpdateAllRowsAsync(token, input, birthYear, studyYears, ct);
            return;
        }

        await source.ExecuteAsync(
            $"""
            insert into membership.class_registrations (
                token, preferred_location, residence_location, work_location, birth_year, islamic_study_years, other_interests, education, field_of_study, field_of_study_other,
                professional_courses, professional_courses_other, occupation_type, field_of_work, years_experience, role_level, linkedin_url)
            values (
                {token}, {input.PreferredLocation}, {input.ResidenceLocation}, {input.WorkLocation}, {birthYear}, {studyYears}, {input.OtherInterests}, {input.Education}, {input.FieldOfStudy}::jsonb, {input.FieldOfStudyOther},
                {input.ProfessionalCourses}::jsonb, {input.ProfessionalCoursesOther}, {input.OccupationType}, {input.FieldOfWork}, {input.YearsExperience}, {input.RoleLevel}, {input.LinkedinUrl})
            """,
            ct);
    }

    // PHP: UPDATE ... WHERE token = :token, every row of the token, and for_classid, profession and the legacy interests set are set to NULL.
    private async Task UpdateAllRowsAsync(int token, RegistrationInput input, int birthYear, int studyYears, CancellationToken ct)
    {
        var now = clock.GetUtcNow();
        await source.ExecuteAsync(
            $"""
            update membership.class_registrations set
                preferred_location = {input.PreferredLocation}, residence_location = {input.ResidenceLocation}, work_location = {input.WorkLocation}, for_classid = null,
                birth_year = {birthYear}, profession = null, islamic_study_years = {studyYears}, interests = null, other_interests = {input.OtherInterests},
                education = {input.Education}, field_of_study = {input.FieldOfStudy}::jsonb, field_of_study_other = {input.FieldOfStudyOther},
                professional_courses = {input.ProfessionalCourses}::jsonb, professional_courses_other = {input.ProfessionalCoursesOther},
                occupation_type = {input.OccupationType}, field_of_work = {input.FieldOfWork}, years_experience = {input.YearsExperience}, role_level = {input.RoleLevel},
                linkedin_url = {input.LinkedinUrl}, modified_at = {now}
            where token = {token}
            """,
            ct);
    }

    private async Task SaveLanguagesAsync(int token, JsonBody body, CancellationToken ct)
    {
        var entries = RegistrationParts.Languages(body.Get("languages"));
        if (entries is null)
        {
            return;
        }

        await source.ExecuteAsync($"delete from membership.class_registrations_languages where token = {token}", ct);

        // The new rows go in together, as one save did.
        await using var tx = await source.BeginAsync(ct);
        foreach (var entry in entries)
        {
            await tx.ExecuteAsync(
                $"insert into membership.class_registrations_languages (token, language, skill, proficiency) values ({token}, {entry.Language}, {entry.Skill}, {entry.Proficiency})",
                ct);
        }

        await tx.CommitAsync(ct);
    }

    private async Task SaveInterestsAsync(int token, JsonBody body, CancellationToken ct)
    {
        var activeIds = (await source.ListAsync($"select id from membership.interest_options where is_active", row => row.Int("id"), ct)).ToHashSet();
        var ids = RegistrationParts.InterestIds(body.Get("interestIds"), activeIds);
        if (ids is null)
        {
            return;
        }

        await source.ExecuteAsync($"delete from membership.student_interests where token = {token}", ct);

        // One insert each, as PHP does: a repeated id breaks the unique key and the request fails with the earlier copies kept.
        foreach (var id in ids)
        {
            await source.ExecuteAsync($"insert into membership.student_interests (token, interest_id) values ({token}, {id})", ct);
        }
    }
}
