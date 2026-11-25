using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Assessment.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Features.QuizQuestions;

// Slice: GET /mcq/quizzes/{quiz_id}/questions?page&pageSize -> a page of the quiz's questions, the options shuffled. Contract: spec/api.yaml.
// PHP: routes/mcq.php route_quiz_questions (:235), api_shuffle_options, McqModel getQuestionsPage. Order: quizzes:take (403), gender (400), the caller's score above zero (409 "Quiz already attempted. Cannot retake."),
// visible quiz (404 "Quiz not found"), deactivated (409 "This quiz is not currently available"), then the page.
// Copied quirk (PHP's own comment, :244): only a score above zero blocks here, while submit blocks on any response, so a member who scored 0 is let in and then refused on submit.
// Exposes: id, text, isArabic, options (never which one is correct; the answer column is not selected). Options: option1 to 5 that are not blank, plus "I don't know", shuffled with the shared random source;
// a question with no usable option shows ["No options available", "I don't know"] in that order. total counts every question of the quiz.

internal static class QuizQuestionsSlice
{
    private const string IDontKnow = "I don't know";

    internal sealed record Item(int Id, string Text, bool? IsArabic, IReadOnlyList<string> Options);

    internal sealed record Body(int Total, long Page, int PageSize, IReadOnlyList<Item> Items);

    private sealed record Row(int Id, string? Question, string? Option1, string? Option2, string? Option3, string? Option4, string? Option5, bool? IsArabic);

    public static IEndpointRouteBuilder MapQuizQuestions(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/mcq/quizzes/{quiz_id}/questions", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string quiz_id, HttpContext context, NpgsqlDataSource source, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await permissions.CanAsync(caller, "quizzes:take", AccessTarget.None, ct))
        {
            return Refusals.NotPermitted();
        }

        if (!await QuizAccess.HasNumericGenderAsync(source, caller, ct))
        {
            return Refusals.GenderNotSet();
        }

        var quizId = PhpValue.IntOfText(quiz_id);
        var attempt = await QuizAccess.AttemptAsync(source, quizId, caller.Token, ct);
        if (attempt.Score is > 0)
        {
            return Problem.Detail(StatusCodes.Status409Conflict, "Quiz already attempted. Cannot retake.");
        }

        var quiz = await QuizAccess.VisibleAsync(source, quizId, caller.Token, ct);
        if (quiz is null)
        {
            return Refusals.QuizNotFound();
        }

        if (quiz.DeactivatedAt is not null)
        {
            return Problem.Detail(StatusCodes.Status409Conflict, "This quiz is not currently available");
        }

        var paging = Paging.From(context);
        var rows = await source.ListAsync(
            $"""
            select id as "Id", question::text as "Question", option1::text as "Option1", option2::text as "Option2", option3::text as "Option3",
                   option4::text as "Option4", option5::text as "Option5", is_arabic as "IsArabic"
            from assessment.spot_quiz_questions where spot_quiz_id = {quizId} order by id
            limit {paging.PageSize} offset {paging.Offset}
            """,
            row => new Row(
                row.Int("Id"), row.TextOrNull("Question"), row.TextOrNull("Option1"), row.TextOrNull("Option2"), row.TextOrNull("Option3"), row.TextOrNull("Option4"),
                row.TextOrNull("Option5"), row.BoolOrNull("IsArabic")),
            ct);
        var total = await QuizAccess.CountQuestionsAsync(source, quizId, ct);
        return Results.Json(new Body(total, paging.Page, paging.PageSize, rows.Select(r => new Item(r.Id, r.Question ?? string.Empty, r.IsArabic, Options(r))).ToList()), AssessmentJson.Answers.QuizQuestions);
    }

    /// <summary>PHP api_shuffle_options: the non-blank options as stored, "I don't know" added, shuffled; no usable option gives a fixed pair.</summary>
    private static string[] Options(Row row)
    {
        var options = new[] { row.Option1, row.Option2, row.Option3, row.Option4, row.Option5 }
            .Where(o => o is not null && PhpText.Trim(o).Length > 0)
            .Select(o => o!)
            .ToList();
        if (options.Count == 0)
        {
            return ["No options available", IDontKnow];
        }

        options.Add(IDontKnow);
        var shuffled = options.ToArray();
        Random.Shared.Shuffle(shuffled);
        return shuffled;
    }
}
