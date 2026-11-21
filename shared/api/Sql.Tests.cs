using NpgsqlTypes;
using NUnit.Framework;

namespace Tsr.Shared.Api.Tests;

/// <summary>
/// The compile-error property (an unsupported hole type does not compile) is not tested here: the test project has no Roslyn
/// reference, and <see cref="Sql"/> has no generic overload to make it hold.
/// </summary>
public sealed class SqlTests
{
    [Test]
    public void A_DateTime_hole_is_a_compile_error()
    {
        // A DateTime converts to DateTimeOffset implicitly, shifting an Unspecified value by the machine's offset, so both overloads exist only to be refused.
        foreach (var type in new[] { typeof(DateTime), typeof(DateTime?) })
        {
            var method = typeof(Sql).GetMethod(nameof(Sql.AppendFormatted), [type]);

            Assert.That(method, Is.Not.Null, type.Name);
            Assert.That(method!.GetCustomAttributes(typeof(ObsoleteAttribute), false).Cast<ObsoleteAttribute>().Single().IsError, Is.True, type.Name);
        }
    }

    [Test]
    public void A_hole_becomes_a_typed_parameter()
    {
        const string hostile = "x'; drop table t; --";
        int? none = null;

        Sql sql = $"select 1 where name = {hostile}::citext and n = {none}";

        Assert.Multiple(() =>
        {
            Assert.That(sql.Text, Is.EqualTo("select 1 where name = @p0::citext and n = @p1"));
            Assert.That(sql.Parameters, Has.Length.EqualTo(2));
            Assert.That(sql.Parameters[0].ParameterName, Is.EqualTo("p0"));
            Assert.That(sql.Parameters[0].NpgsqlDbType, Is.EqualTo(NpgsqlDbType.Text));
            Assert.That(sql.Parameters[0].Value, Is.EqualTo(hostile));
            Assert.That(sql.Parameters[1].ParameterName, Is.EqualTo("p1"));
            Assert.That(sql.Parameters[1].NpgsqlDbType, Is.EqualTo(NpgsqlDbType.Integer));
            Assert.That(sql.Parameters[1].Value, Is.EqualTo(DBNull.Value));
        });
    }

    [Test]
    public void Each_supported_type_arrives_with_its_database_type_and_value()
    {
        var id = Guid.NewGuid();
        var when = new DateTimeOffset(2026, 11, 21, 12, 0, 0, TimeSpan.FromHours(5));
        var day = new DateOnly(2026, 11, 21);
        string[] words = ["a", "b"];
        int[] numbers = [1, 2];
        string? text = "t";
        int? number = 7;
        long? big = 8;
        bool? flag = true;

        Sql sql = $"{text} {5} {number} {6L} {big} {false} {flag} {1.5m} {2.5d} {id} {when} {day} {words} {numbers}";

        (NpgsqlDbType Type, object Value)[] expected =
        [
            (NpgsqlDbType.Text, "t"), (NpgsqlDbType.Integer, 5), (NpgsqlDbType.Integer, 7), (NpgsqlDbType.Bigint, 6L),
            (NpgsqlDbType.Bigint, 8L), (NpgsqlDbType.Boolean, false), (NpgsqlDbType.Boolean, true), (NpgsqlDbType.Numeric, 1.5m),
            (NpgsqlDbType.Double, 2.5d), (NpgsqlDbType.Uuid, id), (NpgsqlDbType.TimestampTz, when.ToUniversalTime()),
            (NpgsqlDbType.Date, day), (NpgsqlDbType.Array | NpgsqlDbType.Text, words), (NpgsqlDbType.Array | NpgsqlDbType.Integer, numbers),
        ];
        Assert.That(sql.Parameters, Has.Length.EqualTo(expected.Length));
        for (var i = 0; i < expected.Length; i++)
        {
            Assert.That(sql.Parameters[i].NpgsqlDbType, Is.EqualTo(expected[i].Type), "type of p" + i);
            Assert.That(sql.Parameters[i].Value, Is.EqualTo(expected[i].Value), "value of p" + i);
        }
    }

    [Test]
    public void A_date_time_offset_is_sent_as_utc()
    {
        var when = new DateTimeOffset(2026, 11, 21, 12, 0, 0, TimeSpan.FromHours(5));

        Sql sql = $"{when}";

        Assert.That(((DateTimeOffset)sql.Parameters[0].Value!).Offset, Is.EqualTo(TimeSpan.Zero));
        Assert.That(((DateTimeOffset)sql.Parameters[0].Value!).UtcDateTime, Is.EqualTo(when.UtcDateTime));
    }

    [Test]
    public void A_null_is_sent_as_database_null_with_its_type()
    {
        string? text = null;
        long? big = null;
        bool? flag = null;
        DateTimeOffset? when = null;

        Sql sql = $"{text} {big} {flag} {when}";

        NpgsqlDbType[] types = [NpgsqlDbType.Text, NpgsqlDbType.Bigint, NpgsqlDbType.Boolean, NpgsqlDbType.TimestampTz];
        for (var i = 0; i < types.Length; i++)
        {
            Assert.That(sql.Parameters[i].NpgsqlDbType, Is.EqualTo(types[i]));
            Assert.That(sql.Parameters[i].Value, Is.EqualTo(DBNull.Value));
        }
    }

    [Test]
    public void A_repeated_value_makes_two_parameters()
    {
        var name = "same";

        Sql sql = $"a = {name} or b = {name}";

        Assert.Multiple(() =>
        {
            Assert.That(sql.Text, Is.EqualTo("a = @p0 or b = @p1"));
            Assert.That(sql.Parameters, Has.Length.EqualTo(2));
        });
    }

    [Test]
    public void Literal_braces_and_text_around_holes_are_kept_exactly()
    {
        var n = 1;

        Sql sql = $$"""  select '{"a": 1}'::jsonb, "q"  {{n}}  -- end """;

        Assert.That(sql.Text, Is.EqualTo("""  select '{"a": 1}'::jsonb, "q"  @p0  -- end """));
    }

    [Test]
    public void A_query_without_holes_has_no_parameters()
    {
        Sql sql = $"select 1";

        Assert.Multiple(() =>
        {
            Assert.That(sql.Text, Is.EqualTo("select 1"));
            Assert.That(sql.Parameters, Is.Empty);
        });
    }
}
