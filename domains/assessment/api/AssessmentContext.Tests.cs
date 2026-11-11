using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Metadata;
using NUnit.Framework;

namespace Tsr.Assessment.Api.Tests;

/// <summary>The tables of schema "assessment", read from the model alone (no database). The migrated database is checked in db/tests.</summary>
public sealed class AssessmentContextTests
{
    private static readonly string[] Expected =
    [
        "spot_quiz_questions",
        "spot_quiz_responses",
        "spot_quiz_submissions",
        "spot_quizzes",
        "standard_mcq_questions",
        "standard_mcqs",
        "quiz_campaigns",
    ];

    [Test]
    public void The_context_owns_exactly_the_ported_tables_in_its_schema()
    {
        var options = new DbContextOptionsBuilder<AssessmentContext>().UseNpgsql("Host=unused").Options;
        using var context = new AssessmentContext(options);

        var model = context.GetService<IDesignTimeModel>().Model;
        var tables = model.GetEntityTypes().Select(e => e.GetTableName()).Order().ToList();

        Assert.That(model.GetDefaultSchema(), Is.EqualTo("assessment"));
        Assert.That(tables, Is.EqualTo(Expected.Order().ToList()));
    }
}
