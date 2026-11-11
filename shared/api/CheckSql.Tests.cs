using NUnit.Framework;

namespace Tsr.Shared.Api.Tests;

/// <summary>The text of a CHECK that lists an enum's values (a NULL passes, as a nullable MariaDB enum accepts NULL).</summary>
public sealed class CheckSqlTests
{
    [Test]
    public void In_lists_the_values_quoted()
    {
        Assert.That(CheckSql.In("status", "active", "done"), Is.EqualTo("status in ('active', 'done')"));
    }

    [Test]
    public void In_doubles_a_quote_inside_a_value()
    {
        Assert.That(CheckSql.In("skill", "Don't Know"), Is.EqualTo("skill in ('Don''t Know')"));
    }

    [Test]
    public void IsJson_tests_the_column_as_text()
    {
        Assert.That(CheckSql.IsJson("details"), Is.EqualTo("details::text is json"));
    }
}
