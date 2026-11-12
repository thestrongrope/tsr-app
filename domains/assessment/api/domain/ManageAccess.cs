using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Tsr.Access.Api;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Domain;

/// <summary>
/// What the manage routes (a teacher or class admin works on a class's quizzes) ask first, each PHP's own: the active class (lib/response.php api_find_class), the quiz and its class (mcq_admin.php api_find_mcq_quiz),
/// the permission <c>mcqs:manage</c> on the class (api_require) and the circulating link (McqModel::link). The class comes from classes' published view <c>classes.v_classes</c>.
/// </summary>
internal static class ManageAccess
{
    private const string FallbackBase = "https://account.thestrongrope.com";

    /// <summary>PHP's refusal text for every manage route.</summary>
    public const string NotPermittedText = "You do not have permission to manage MCQs for this class";

    /// <summary>A quiz with its class, as McqModel::get() reads it.</summary>
    internal sealed record QuizRow(
        int Id, string? Code, string? Name, string? Topic, int ClassId, string? ClassCode, string? ClassName, int RestrictToClass, DateTimeOffset? PublishedAt, DateTimeOffset? DeactivatedAt, string ClassStatus);

    /// <summary>An active class as the manage routes need it.</summary>
    internal sealed record ActiveClass(int Id, string Code, int? LanguageId);

    public static IResult NotPermitted() => Problem.Detail(StatusCodes.Status403Forbidden, NotPermittedText);

    /// <summary>PHP's refusal for the copy picker routes that name a class.</summary>
    public static IResult CopyNotPermitted() => Problem.Detail(StatusCodes.Status403Forbidden, "You do not have permission to copy MCQs from this class");

    public static IResult ClassNotFound() => Problem.Detail(StatusCodes.Status404NotFound, "Class not found");

    /// <summary>PHP ClassesModel::get requires status A: an inactive or missing class is the same 404 (null here). The class code and language are what the standard list needs.</summary>
    public static async Task<ActiveClass?> ActiveClassAsync(AssessmentContext db, long classId, CancellationToken ct)
    {
        var rows = await db.Database
            .SqlQuery<ActiveClass>($"""select id as "Id", code::text as "Code", language_id as "LanguageId" from classes.v_classes where id = {classId} and status = 'A' limit 1""")
            .ToListAsync(ct);
        return rows.Count == 0 ? null : rows[0];
    }

    /// <summary>PHP api_find_mcq_quiz: the quiz (404 "Quiz not found"), then its class active (404 "Class not found").</summary>
    public static async Task<(QuizRow? Quiz, IResult? Refusal)> ResolveQuizAsync(AssessmentContext db, long quizId, CancellationToken ct)
    {
        var rows = await db.Database
            .SqlQuery<QuizRow>($"""
                select q.id as "Id", q.code::text as "Code", q.name::text as "Name", q.topic::text as "Topic", q.class_id as "ClassId",
                       c.code::text as "ClassCode", c.name::text as "ClassName", q.restrict_to_class::int as "RestrictToClass",
                       q.published_at as "PublishedAt", q.deactivated_at as "DeactivatedAt", c.status::text as "ClassStatus"
                from assessment.spot_quizzes q
                join classes.v_classes c on c.id = q.class_id
                where q.id = {quizId}
                limit 1
                """)
            .ToListAsync(ct);
        if (rows.Count == 0)
        {
            return (null, Refusals.QuizNotFound());
        }

        return rows[0].ClassStatus == "A" ? (rows[0], null) : (null, ClassNotFound());
    }

    /// <summary>The permission check of PHP's api_require with a class target; an id beyond the integer range is a class that does not exist.</summary>
    public static Task<bool> CanAsync(Permissions permissions, Caller caller, string action, long classId, CancellationToken ct) =>
        permissions.CanAsync(caller, action, AccessTarget.ForClass((int)Math.Clamp(classId, int.MinValue, int.MaxValue)), ct);

    /// <summary>PHP getTopics plus the trim of its two callers: the class's distinct topics in order, each trimmed (PHP trim set), blank ones dropped. At most 5000.</summary>
    public static async Task<IReadOnlyList<string>> TopicsAsync(AssessmentContext db, long classId, CancellationToken ct)
    {
        var topics = await db.Database
            .SqlQuery<string>($"""
                select t::text as "Value"
                from (
                    select distinct rtrim(topic::text, ' ')::citext as t
                    from assessment.spot_quizzes
                    where class_id = {classId} and topic is not null
                ) topics
                order by t
                limit 5000
                """)
            .ToListAsync(ct);
        return topics.Select(PhpText.Trim).Where(t => t.Length > 0).ToList();
    }

    /// <summary>PHP McqModel::link: null until the quiz is published and has a code; else the public base (TSR_PUBLIC_WEB_BASE; unset is PHP's fallback host) plus /mcq/&lt;code&gt;.</summary>
    public static string? Link(IConfiguration configuration, string? code, DateTimeOffset? publishedAt)
    {
        if (publishedAt is null || string.IsNullOrEmpty(code))
        {
            return null;
        }

        var configured = (configuration["TSR_PUBLIC_WEB_BASE"] ?? string.Empty).TrimEnd('/');
        return (configured.Length > 0 ? configured : FallbackBase) + "/mcq/" + Uri.EscapeDataString(code);
    }

    /// <summary>The clock cut to the second, as MariaDB's now() stores it.</summary>
    public static DateTimeOffset NowToSecond(TimeProvider clock)
    {
        var now = clock.GetUtcNow();
        return new DateTimeOffset(now.Year, now.Month, now.Day, now.Hour, now.Minute, now.Second, TimeSpan.Zero);
    }
}
