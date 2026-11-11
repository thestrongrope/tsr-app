using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Metadata;
using NUnit.Framework;

namespace Tsr.Classes.Api.Tests;

/// <summary>The tables of schema "classes", read from the model alone (no database). The migrated database is checked in db/tests.</summary>
public sealed class ClassesContextTests
{
    private static readonly string[] Expected =
    [
        "class_attendance",
        "class_audit_log",
        "class_levels",
        "class_schedule_topics",
        "class_schedules",
        "class_sessions",
        "class_students",
        "class_tags",
        "classes",
        "guides",
        "student_transfers",
        "syllabus",
        "tags",
        "teachers",
        "teachers_history",
        "topics",
    ];

    [Test]
    public void The_context_owns_exactly_the_ported_tables_in_its_schema()
    {
        var options = new DbContextOptionsBuilder<ClassesContext>().UseNpgsql("Host=unused").Options;
        using var context = new ClassesContext(options);

        var model = context.GetService<IDesignTimeModel>().Model;
        var tables = model.GetEntityTypes().Select(e => e.GetTableName()).Order().ToList();

        Assert.That(model.GetDefaultSchema(), Is.EqualTo("classes"));
        Assert.That(tables, Is.EqualTo(Expected.Order().ToList()));
    }
}
