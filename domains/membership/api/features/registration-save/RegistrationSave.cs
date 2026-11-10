using System.Text.Json.Nodes;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
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

internal sealed class RegistrationSaveHandler(MembershipContext db, Lookups lookups, TimeProvider clock)
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
        return Results.Json(new JsonObject { ["success"] = true, ["message"] = "Class request submitted successfully" });
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
        if (await db.ClassRegistrations.AnyAsync(r => r.Token == token, ct))
        {
            await UpdateAllRowsAsync(token, input, birthYear, studyYears, ct);
            return;
        }

        db.ClassRegistrations.Add(new ClassRegistration
        {
            Token = token,
            PreferredLocation = input.PreferredLocation,
            ResidenceLocation = input.ResidenceLocation,
            WorkLocation = input.WorkLocation,
            BirthYear = birthYear,
            IslamicStudyYears = studyYears,
            OtherInterests = input.OtherInterests,
            Education = input.Education,
            FieldOfStudy = input.FieldOfStudy,
            FieldOfStudyOther = input.FieldOfStudyOther,
            ProfessionalCourses = input.ProfessionalCourses,
            ProfessionalCoursesOther = input.ProfessionalCoursesOther,
            OccupationType = input.OccupationType,
            FieldOfWork = input.FieldOfWork,
            YearsExperience = input.YearsExperience,
            RoleLevel = input.RoleLevel,
            LinkedinUrl = input.LinkedinUrl,
        });
        await db.SaveChangesAsync(ct);
    }

    // PHP: UPDATE ... WHERE token = :token, every row of the token, and for_classid, profession and the legacy interests set are set to NULL.
    private async Task UpdateAllRowsAsync(int token, RegistrationInput input, int birthYear, int studyYears, CancellationToken ct)
    {
        var now = clock.GetUtcNow();
        await db.ClassRegistrations
            .Where(r => r.Token == token)
            .ExecuteUpdateAsync(
                set => set
                    .SetProperty(r => r.PreferredLocation, input.PreferredLocation)
                    .SetProperty(r => r.ResidenceLocation, input.ResidenceLocation)
                    .SetProperty(r => r.WorkLocation, input.WorkLocation)
                    .SetProperty(r => r.ForClassId, (int?)null)
                    .SetProperty(r => r.BirthYear, birthYear)
                    .SetProperty(r => r.Profession, (string?)null)
                    .SetProperty(r => r.IslamicStudyYears, studyYears)
                    .SetProperty(r => r.Interests, (string?)null)
                    .SetProperty(r => r.OtherInterests, input.OtherInterests)
                    .SetProperty(r => r.Education, input.Education)
                    .SetProperty(r => r.FieldOfStudy, input.FieldOfStudy)
                    .SetProperty(r => r.FieldOfStudyOther, input.FieldOfStudyOther)
                    .SetProperty(r => r.ProfessionalCourses, input.ProfessionalCourses)
                    .SetProperty(r => r.ProfessionalCoursesOther, input.ProfessionalCoursesOther)
                    .SetProperty(r => r.OccupationType, input.OccupationType)
                    .SetProperty(r => r.FieldOfWork, input.FieldOfWork)
                    .SetProperty(r => r.YearsExperience, input.YearsExperience)
                    .SetProperty(r => r.RoleLevel, input.RoleLevel)
                    .SetProperty(r => r.LinkedinUrl, input.LinkedinUrl)
                    .SetProperty(r => r.ModifiedAt, now),
                ct);
    }

    private async Task SaveLanguagesAsync(int token, JsonBody body, CancellationToken ct)
    {
        var entries = RegistrationParts.Languages(body.Get("languages"));
        if (entries is null)
        {
            return;
        }

        await db.RegistrationLanguages.Where(l => l.Token == token).ExecuteDeleteAsync(ct);
        db.RegistrationLanguages.AddRange(entries.Select(e => new RegistrationLanguage { Token = token, Language = e.Language, Skill = e.Skill, Proficiency = e.Proficiency }));
        await db.SaveChangesAsync(ct);
    }

    private async Task SaveInterestsAsync(int token, JsonBody body, CancellationToken ct)
    {
        var activeIds = (await db.InterestOptions.AsNoTracking().Where(o => o.IsActive).Select(o => o.Id).ToListAsync(ct)).ToHashSet();
        var ids = RegistrationParts.InterestIds(body.Get("interestIds"), activeIds);
        if (ids is null)
        {
            return;
        }

        await db.StudentInterests.Where(s => s.Token == token).ExecuteDeleteAsync(ct);

        // One insert each, as PHP does: a repeated id breaks the unique key and the request fails with the earlier copies kept.
        foreach (var id in ids)
        {
            await db.Database.ExecuteSqlAsync($"insert into membership.student_interests (token, interest_id) values ({token}, {id})", ct);
        }
    }
}
