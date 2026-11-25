using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Assessment.Api.Domain;
using Tsr.Platform.Api;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Features.ManageSheet;

// Slice: GET /mcq/manage/{quiz_id}/sheet -> the printable question sheet as a PDF (A4 portrait), no answer marked. Contract: spec/api.yaml.
// PHP: routes/mcq_admin.php route_mcq_manage_sheet (:494), models/mcqsheet.php (Dompdf, remote loading off), McqModel fillMissingOptionOrders (:774). Order: caller (401), quiz found (404), its class active (404), mcqs:manage on the class (403),
// then the order of every question's options is fixed and STORED (domain/OptionOrder.cs; option1 is the right answer, so an unfixed order would print the answer first; a question with an order keeps it, so the sheet and the quiz students see agree),
// then 404 "This MCQ has no questions", then the PDF. The page is domain/QuizSheet.cs (every value encoded, no outside resource); it is rendered by platform's ReportExport.DownloadPageAsync (Gotenberg; a renderer that is down is a 503, PHP had none).
// File name MCQ_<code with other characters made _>.pdf. A GET that writes (the stored order), as PHP's. Questions in id order, at most 5000.
// Note: the brief expected an Arabic text direction; PHP's sheet sets none (is_arabic is not read), so none is set here. Option 5 is never printed once an order is stored (the order is made from options 1 to 4, PHP's).

internal static class ManageSheetSlice
{
    private const int MaxQuestions = 5000;

    private sealed record Row(string? Question, string? Option1, string? Option2, string? Option3, string? Option4, string? Option5, string? Order);

    public static IEndpointRouteBuilder MapManageSheet(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/mcq/manage/{quiz_id}/sheet", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string quiz_id, HttpContext context, NpgsqlDataSource source, Permissions permissions, ReportExport export, IQuizRandom random, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var (quiz, refusal) = await ManageAccess.ResolveQuizAsync(source, PhpValue.IntOfText(quiz_id), ct);
        if (refusal is not null)
        {
            return refusal;
        }

        if (!await ManageAccess.CanAsync(permissions, caller, "mcqs:manage", quiz!.ClassId, ct))
        {
            return ManageAccess.NotPermitted();
        }

        await OptionOrder.FillMissingAsync(source, quiz.Id, random, ct);
        var rows = await source.ListAsync(
            $"""
                select question::text as "Question", option1::text as "Option1", option2::text as "Option2", option3::text as "Option3",
                       option4::text as "Option4", option5::text as "Option5", option_display_order::text as "Order"
                from assessment.spot_quiz_questions where spot_quiz_id = {quiz.Id} order by id limit {MaxQuestions}
                """,
            row => new Row(
                row.TextOrNull("Question"), row.TextOrNull("Option1"), row.TextOrNull("Option2"), row.TextOrNull("Option3"), row.TextOrNull("Option4"), row.TextOrNull("Option5"),
                row.TextOrNull("Order")),
            ct);
        if (rows.Count == 0)
        {
            return Problem.Detail(StatusCodes.Status404NotFound, "This MCQ has no questions");
        }

        var questions = rows
            .Select(r => new QuizSheet.Question(r.Question ?? string.Empty, OptionOrder.Ordered(r.Order, [r.Option1, r.Option2, r.Option3, r.Option4, r.Option5]).Select(o => o.Text).ToList()))
            .ToList();
        var html = QuizSheet.Html(quiz.Name ?? string.Empty, quiz.Topic, quiz.ClassCode ?? string.Empty, quiz.ClassName ?? string.Empty, questions);
        return await export.DownloadPageAsync(html, QuizSheet.FileNameBase(quiz.Code), ct);
    }
}
