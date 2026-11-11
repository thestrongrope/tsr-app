using Microsoft.EntityFrameworkCore;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api;

/// <summary>
/// assessment's tables, schema "assessment": spot quizzes with their questions, submissions and responses, the standard MCQ bank
/// and the quiz campaigns. Names, keys and indexes follow PHP's, so the data move is a copy. A class, level, language, topic or member
/// is a plain integer (another domain's row): no foreign key leaves the schema, and PHP declared none inside it. PHP's spot quiz
/// trigger (a random unique <c>code</c> on insert) is not ported: the slice that creates a quiz will do it.
/// </summary>
internal sealed class AssessmentContext(DbContextOptions<AssessmentContext> options) : TsrDbContext(options, SchemaName)
{
    public const string SchemaName = "assessment";

    private const string Now = "now()";

    public DbSet<SpotQuiz> SpotQuizzes => Set<SpotQuiz>();

    public DbSet<SpotQuizQuestion> SpotQuizQuestions => Set<SpotQuizQuestion>();

    public DbSet<SpotQuizSubmission> SpotQuizSubmissions => Set<SpotQuizSubmission>();

    public DbSet<SpotQuizResponse> SpotQuizResponses => Set<SpotQuizResponse>();

    public DbSet<StandardMcq> StandardMcqs => Set<StandardMcq>();

    public DbSet<StandardMcqQuestion> StandardMcqQuestions => Set<StandardMcqQuestion>();

    public DbSet<QuizCampaign> QuizCampaigns => Set<QuizCampaign>();

    protected override void Configure(ModelBuilder modelBuilder)
    {
        ConfigureSpotQuizzes(modelBuilder);
        ConfigureStandardMcqs(modelBuilder);

        modelBuilder.Entity<QuizCampaign>(campaign => campaign.Property(c => c.Name).HasMaxLength(300));
    }

    private static void ConfigureSpotQuizzes(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<SpotQuiz>(quiz =>
        {
            quiz.Property(q => q.Code).HasMaxLength(100);
            quiz.Property(q => q.McqCode).HasMaxLength(200);
            quiz.Property(q => q.Name).HasMaxLength(300);
            quiz.Property(q => q.Topic).HasMaxLength(300);
            quiz.Property(q => q.RestrictToClass).HasDefaultValue((short)1);
            quiz.Property(q => q.CreatedAt).HasDefaultValueSql(Now);
            quiz.HasIndex(q => new { q.ClassId, q.PublishedAt }).HasDatabaseName("idx_sq_class_published");
        });

        modelBuilder.Entity<SpotQuizQuestion>(question =>
        {
            question.Property(q => q.Question).HasMaxLength(1000);
            question.Property(q => q.Option1).HasMaxLength(1000);
            question.Property(q => q.Option2).HasMaxLength(1000);
            question.Property(q => q.Option3).HasMaxLength(1000);
            question.Property(q => q.Option4).HasMaxLength(1000);
            question.Property(q => q.Option5).HasMaxLength(1000);
            question.Property(q => q.CreatedAt).HasDefaultValueSql(Now);
            question.Property(q => q.OptionDisplayOrder).HasMaxLength(50);
            question.HasIndex(q => q.SpotQuizId).HasDatabaseName("idx_sqq_quiz");
        });

        modelBuilder.Entity<SpotQuizSubmission>(submission => submission.Property(s => s.CreatedAt).HasDefaultValueSql(Now));

        modelBuilder.Entity<SpotQuizResponse>(response =>
        {
            response.Property(r => r.Response).HasMaxLength(1000);
            response.Property(r => r.CorrectResponse).HasMaxLength(1000);
            response.Property(r => r.CreatedAt).HasDefaultValueSql(Now);
            response.HasIndex(r => new { r.SpotQuizQuestionId, r.Token }).IsUnique().HasDatabaseName("spot_quiz_responses_question_token");
            response.HasIndex(r => new { r.SpotQuizId, r.Token }).HasDatabaseName("idx_sqr_quiz_token");
            response.HasIndex(r => r.Token).HasDatabaseName("idx_sqr_token");
        });
    }

    private static void ConfigureStandardMcqs(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<StandardMcq>(mcq =>
        {
            mcq.Property(m => m.Code).HasMaxLength(200);
            mcq.Property(m => m.Topic).HasMaxLength(500);
            mcq.Property(m => m.Subject).HasMaxLength(500);
            mcq.Property(m => m.Lesson).HasMaxLength(500);
            mcq.Property(m => m.Name).HasMaxLength(100);
            mcq.Property(m => m.CreatedAt).HasDefaultValueSql(Now);
        });

        modelBuilder.Entity<StandardMcqQuestion>(question =>
        {
            question.Property(q => q.McqCode).HasMaxLength(200);
            question.Property(q => q.Question).HasMaxLength(500);
            question.Property(q => q.Answer).HasMaxLength(500);
            question.Property(q => q.Option1).HasMaxLength(500);
            question.Property(q => q.Option2).HasMaxLength(500);
            question.Property(q => q.Option3).HasMaxLength(500);
            question.Property(q => q.ReasonOption1).HasMaxLength(500);
            question.Property(q => q.ReasonOption2).HasMaxLength(500);
            question.Property(q => q.ReasonOption3).HasMaxLength(500);
            question.Property(q => q.CreatedAt).HasDefaultValueSql(Now);
        });
    }
}
