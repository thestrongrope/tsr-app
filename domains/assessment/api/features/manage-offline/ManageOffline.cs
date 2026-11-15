using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Assessment.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Features.ManageOffline;

// Slice: GET /mcq/manage/{quiz_id}/offline -> what a teacher needs to record answers students gave on paper: the questions WITH the correct option marked, and the class's students; {quiz, questions, students}. Contract: spec/api.yaml.
// PHP: routes/mcq_admin.php route_mcq_manage_offline (:429), McqModel orderedOptions (:1284), offlineStudents (:1312), isOfflineStudent (:1332). Order: caller (401), quiz found (404), its class active (404), mcqs:manage on the class (403), then the read.
// THE ANSWER KEY IS ON THIS WIRE (options[].isCorrect): reached only after the permission check (class teacher, current class admin student, super admin).
// Options: in the stored display order (domain/OptionOrder.cs), else option1 to option5 as stored, blank ones left out; the stored order is NOT filled here (PHP does not). Students: the class's current students by name (domain/ClassStudents.cs);
// isOffline when the email ends in @thestrongrope.com (case ignored: a member with no phone, whose teacher made an internal address); submitted when the member has a row in spot_quiz_submissions for the quiz.
// FLAGGED, COPIED FROM PHP: only the offline entry writes spot_quiz_submissions, so a student who answered ON THEIR PHONE shows submitted: false here (what stops a second set is the unique index on the responses, see the save route).
// Questions are in id order, at most 5000; students at most 5000 (PHP: all).

internal static class ManageOfflineSlice
{
    private const int MaxQuestions = 5000;

    internal sealed record QuizWire(int Id, string Name, string? Topic, string ClassCode, string ClassName);

    internal sealed record OptionWire(string Text, bool IsCorrect);

    internal sealed record QuestionWire(int Id, string Question, IReadOnlyList<OptionWire> Options);

    internal sealed record StudentWire(int Token, string Name, bool IsOffline, bool Submitted);

    internal sealed record Body(QuizWire Quiz, IReadOnlyList<QuestionWire> Questions, IReadOnlyList<StudentWire> Students);

    private sealed record Row(int Id, string? Question, string? Option1, string? Option2, string? Option3, string? Option4, string? Option5, string? Order);

    public static IEndpointRouteBuilder MapManageOffline(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/mcq/manage/{quiz_id}/offline", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string quiz_id, HttpContext context, AssessmentContext db, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var (quiz, refusal) = await ManageAccess.ResolveQuizAsync(db, PhpValue.IntOfText(quiz_id), ct);
        if (refusal is not null)
        {
            return refusal;
        }

        if (!await ManageAccess.CanAsync(permissions, caller, "mcqs:manage", quiz!.ClassId, ct))
        {
            return ManageAccess.NotPermitted();
        }

        var rows = await db.Database
            .SqlQuery<Row>($"""
                select id as "Id", question::text as "Question", option1::text as "Option1", option2::text as "Option2", option3::text as "Option3",
                       option4::text as "Option4", option5::text as "Option5", option_display_order::text as "Order"
                from assessment.spot_quiz_questions where spot_quiz_id = {quiz.Id} order by id limit {MaxQuestions}
                """)
            .ToListAsync(ct);
        var questions = rows
            .Select(r => new QuestionWire(
                r.Id, r.Question ?? string.Empty, OptionOrder.Ordered(r.Order, [r.Option1, r.Option2, r.Option3, r.Option4, r.Option5]).Select(o => new OptionWire(o.Text, o.IsCorrect)).ToList()))
            .ToList();

        var submitted = (await db.Database
            .SqlQuery<int>($"""select distinct token as "Value" from assessment.spot_quiz_submissions where spot_quiz_id = {quiz.Id} and token is not null limit 5000""")
            .ToListAsync(ct)).ToHashSet();
        var students = (await ClassStudents.ListAsync(db, quiz.ClassId, ct))
            .Select(s => new StudentWire(s.Token, s.Name, ClassStudents.IsOffline(s.Email), submitted.Contains(s.Token)))
            .ToList();

        return Results.Json(new Body(
            new QuizWire(quiz.Id, quiz.Name ?? string.Empty, quiz.Topic, quiz.ClassCode ?? string.Empty, quiz.ClassName ?? string.Empty), questions, students));
    }
}
