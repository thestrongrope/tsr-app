using System.Data.Common;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.Extensions.Logging;
using Tsr.Access.Api;
using Tsr.Assessment.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Features.StandardMcqUpdate;

// Slice: POST /standard-mcqs/update {languages: [id], levels: [id]} -> {results: [...]}, one per language and level: "updated" with its quiz count, or "failed" with a reason. Contract: spec/api.yaml.
// PHP: routes/standard_mcqs.php route_standard_mcqs_update (:51), McqModel updateStandardMcqsFromSheet / runStandardMcqUpdate / saveStandardMcqs / replaceStandardMcqs (models/mcq.php:~260-500).
// Order: standard-mcqs:update (403); body (422 "Invalid JSON body"); languages then levels, each a non-empty list of whole numbers from 1 (422 "Choose at least one in <field>" / "<field> must be a list of ids");
// the lock (409 "An update is already running. Try again in a minute."); read EVERY range of the one source sheet (tab "<Language>-<Level>", A2:M) before anything is written; then per pair, in a savepoint,
// delete and insert the standard MCQs of that language and level (the saved level is the chosen id + 1, as PHP's page always did: Abuzar 2, Miqdad 3, Ammar 4).
// A pair is "failed" when its id is unknown, when any range could not be read ("Not updated: another sheet could not be read" for the others), when the sheet has no MCQs, or when its save failed (that pair alone is rolled back).
// Events: one assessment.standard_mcqs_updated {languageId, levelId, quizzes} per updated pair, in the same transaction. Lock: AssessmentLocks.StandardMcqUpdate.
// Deviations: at most 20 ids per list (PHP has no limit; 422 "Too many ids in <field>"), because every unknown pair costs a result row; a missing cell for a NOT NULL column is saved as an empty string.

internal static partial class StandardMcqUpdateSlice
{
    private const int MaxIds = 20;
    private const string Unreadable = "The sheet could not be read";
    private const string UnknownPair = "Unknown language or level";

    internal sealed record Result(
        [property: JsonPropertyName("language_id")] long LanguageId,
        [property: JsonPropertyName("level_id")] long LevelId,
        [property: JsonPropertyName("language")] string Language,
        [property: JsonPropertyName("level")] string Level,
        [property: JsonPropertyName("status")] string Status,
        [property: JsonPropertyName("quizzes"), JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] int? Quizzes,
        [property: JsonPropertyName("reason"), JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] string? Reason);

    internal sealed record Body(IReadOnlyList<Result> Results);

    internal sealed record Updated(long LanguageId, long LevelId, int Quizzes);

    /// <summary>One chosen pair after the read phase: its quizzes, or why it cannot be saved.</summary>
    private sealed record Draft(long LanguageId, long LevelId, string Language, string Level, IReadOnlyList<StandardMcqRows.Quiz>? Quizzes, string? Reason);

    public static IEndpointRouteBuilder MapStandardMcqUpdate(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/standard-mcqs/update", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(
        HttpContext context, AssessmentContext db, Permissions permissions, ISheets sheets, TimeProvider clock, ILoggerFactory loggers, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await permissions.CanAsync(caller, "standard-mcqs:update", AccessTarget.None, ct))
        {
            return Refusals.NotPermitted();
        }

        var (body, refusal) = await RequestBodies.ReadAsync(context.Request, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var (languages, languagesRefusal) = Ids(body!, "languages");
        if (languagesRefusal is not null)
        {
            return languagesRefusal;
        }

        var (levels, levelsRefusal) = Ids(body!, "levels");
        if (levelsRefusal is not null)
        {
            return levelsRefusal;
        }

        var log = loggers.CreateLogger("Tsr.Assessment.Api.StandardMcqUpdate");
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        if (!await AssessmentLocks.TryTakeAsync(db, AssessmentLocks.StandardMcqUpdate, ct))
        {
            return Problem.Detail(StatusCodes.Status409Conflict, "An update is already running. Try again in a minute.");
        }

        var drafts = await ReadAllAsync(sheets, log, languages, levels, ct);
        var anyUnreadable = drafts.Any(d => d.Reason is not null);
        var results = new List<Result>();
        foreach (var draft in drafts)
        {
            results.Add(await ResultOfAsync(db, transaction, clock, log, draft, anyUnreadable, ct));
        }

        await transaction.CommitAsync(ct);
        return Results.Json(new Body(results));
    }

    /// <summary>PHP api_standard_mcq_ids: a non-empty array (a JSON list or object) of whole numbers from 1; duplicates dropped.</summary>
    private static (IReadOnlyList<long> Ids, IResult? Refusal) Ids(JsonBody body, string field)
    {
        var value = body.Get(field);
        var entries = JsonBody.Entries(value);
        if (entries.Count == 0)
        {
            return ([], Problem.Detail(StatusCodes.Status422UnprocessableEntity, "Choose at least one in " + field));
        }

        var ids = new List<long>();
        foreach (var entry in entries)
        {
            if (!PhpValue.IsInt(entry.Value, out var id) || id < 1)
            {
                return ([], Problem.Detail(StatusCodes.Status422UnprocessableEntity, field + " must be a list of ids"));
            }

            if (!ids.Contains(id))
            {
                ids.Add(id);
            }
        }

        return ids.Count > MaxIds
            ? ([], Problem.Detail(StatusCodes.Status422UnprocessableEntity, "Too many ids in " + field))
            : (ids, null);
    }

    private static async Task<List<Draft>> ReadAllAsync(ISheets sheets, ILogger log, IReadOnlyList<long> languages, IReadOnlyList<long> levels, CancellationToken ct)
    {
        var drafts = new List<Draft>();
        foreach (var languageId in languages)
        {
            foreach (var levelId in levels)
            {
                drafts.Add(await ReadOneAsync(sheets, log, languageId, levelId, ct));
            }
        }

        return drafts;
    }

    private static async Task<Draft> ReadOneAsync(ISheets sheets, ILogger log, long languageId, long levelId, CancellationToken ct)
    {
        var language = StandardMcqCatalog.NameOf(StandardMcqCatalog.Languages, languageId);
        var level = StandardMcqCatalog.NameOf(StandardMcqCatalog.Levels, levelId);
        if (language is null || level is null)
        {
            return new Draft(languageId, levelId, language ?? string.Empty, level ?? string.Empty, null, UnknownPair);
        }

        try
        {
            var rows = await sheets.ReadAsync(StandardMcqCatalog.SheetId, language + "-" + level + "!A2:M", ct);
            return new Draft(languageId, levelId, language, level, StandardMcqRows.Group(rows), null);
        }
        catch (SheetsException e)
        {
            LogReadFailed(log, e.Message);
            return new Draft(languageId, levelId, language, level, null, Unreadable);
        }
    }

    private static async Task<Result> ResultOfAsync(
        AssessmentContext db, IDbContextTransaction transaction, TimeProvider clock, ILogger log, Draft draft, bool anyUnreadable, CancellationToken ct)
    {
        Result Failed(string reason) => new(draft.LanguageId, draft.LevelId, draft.Language, draft.Level, "failed", null, reason);

        if (draft.Reason is not null)
        {
            return Failed(draft.Reason);
        }

        if (anyUnreadable)
        {
            return Failed("Not updated: another sheet could not be read");
        }

        var quizzes = draft.Quizzes!;
        if (quizzes.Count == 0)
        {
            return Failed("The sheet has no MCQs for this language and level");
        }

        if (!await SaveAsync(db, transaction, clock, log, draft, quizzes, ct))
        {
            return Failed("The save failed and nothing was changed");
        }

        return new Result(draft.LanguageId, draft.LevelId, draft.Language, draft.Level, "updated", quizzes.Count, null);
    }

    /// <summary>One pair in a savepoint: the delete, the inserts and the event commit together or not at all (a database error rolls back to the savepoint and is reported as false).</summary>
    private static async Task<bool> SaveAsync(
        AssessmentContext db, IDbContextTransaction transaction, TimeProvider clock, ILogger log, Draft draft, IReadOnlyList<StandardMcqRows.Quiz> quizzes, CancellationToken ct)
    {
        await transaction.CreateSavepointAsync("standard_mcq_pair", ct);
        try
        {
            var savedLevel = draft.LevelId + 1;
            await ReplaceAsync(db, draft.LanguageId, savedLevel, quizzes, ct);
            await Outbox.WriteAsync(db, "assessment.standard_mcqs_updated", new Updated(draft.LanguageId, savedLevel, quizzes.Count), clock, ct);
            await transaction.ReleaseSavepointAsync("standard_mcq_pair", ct);
            return true;
        }
        catch (Exception e) when (e is DbException or DbUpdateException)
        {
            LogSaveFailed(log, e.GetType().Name);
            await transaction.RollbackToSavepointAsync("standard_mcq_pair", ct);
            return false;
        }
    }

    private static async Task ReplaceAsync(AssessmentContext db, long languageId, long levelId, IReadOnlyList<StandardMcqRows.Quiz> quizzes, CancellationToken ct)
    {
        await db.Database.ExecuteSqlAsync(
            $"""
            delete from assessment.standard_mcq_questions
            where mcq_code in (select code from assessment.standard_mcqs where language_id = {languageId} and level_id = {levelId})
            """,
            ct);
        await db.Database.ExecuteSqlAsync($"delete from assessment.standard_mcqs where language_id = {languageId} and level_id = {levelId}", ct);

        var order = 0;
        foreach (var quiz in quizzes)
        {
            order++;
            await InsertQuizAsync(db, languageId, levelId, order, quiz, ct);
        }
    }

    private static async Task InsertQuizAsync(AssessmentContext db, long languageId, long levelId, int order, StandardMcqRows.Quiz quiz, CancellationToken ct)
    {
        var code = quiz.Code ?? string.Empty;
        var subject = quiz.Subject ?? string.Empty;
        var lesson = quiz.Lesson ?? string.Empty;
        var name = quiz.Name ?? string.Empty;
        await db.Database.ExecuteSqlAsync(
            $"""
            insert into assessment.standard_mcqs (code, language_id, level_id, topic, subject, lesson, name, sort_order)
            values ({code}, {languageId}, {levelId}, {quiz.Topic}, {subject}, {lesson}, {name}, {order})
            """,
            ct);

        var position = 0;
        foreach (var q in quiz.Questions)
        {
            position++;
            var text = q.Text ?? string.Empty;
            var answer = q.Answer ?? string.Empty;
            var option1 = q.Option1 ?? string.Empty;
            await db.Database.ExecuteSqlAsync(
                $"""
                insert into assessment.standard_mcq_questions (mcq_code, question, answer, option1, option2, option3, reason_option1, reason_option2, reason_option3, sort_order)
                values ({code}, {text}, {answer}, {option1}, {q.Option2}, {q.Option3}, {q.Reason1}, {q.Reason2}, {q.Reason3}, {position})
                """,
                ct);
        }
    }

    [LoggerMessage(Level = LogLevel.Warning, Message = "Standard MCQ sheet read failed: {Reason}")]
    private static partial void LogReadFailed(ILogger logger, string reason);

    [LoggerMessage(Level = LogLevel.Warning, Message = "Standard MCQ save failed ({ErrorType}); the pair was rolled back")]
    private static partial void LogSaveFailed(ILogger logger, string errorType);
}
