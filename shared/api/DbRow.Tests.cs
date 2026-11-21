using System.Data;
using System.Data.Common;
using NUnit.Framework;

namespace Tsr.Shared.Api.Tests;

public sealed class DbRowTests
{
    private const string File = "Articles.cs";
    private const string Member = "ListAsync";
    private static readonly string[] TwoTexts = ["a", "b"];
    private static readonly string[] OneText = ["a"];
    private static readonly int[] TwoInts = [1, 2];

    private static DataTableReader Reader(params (string Name, Type Type, object?[] Values)[] columns)
    {
        var table = new DataTable();
        foreach (var column in columns)
        {
            table.Columns.Add(column.Name, column.Type);
        }

        for (var r = 0; r < columns[0].Values.Length; r++)
        {
            table.Rows.Add(columns.Select(c => c.Values[r] ?? DBNull.Value).ToArray());
        }

        return new DataTableReader(table);
    }

    private static DbRow Row(DbDataReader reader) => new(reader, File + ":" + Member);

    /// <summary>Runs a row reader over every row the way <c>Db</c> will: begin the row, read, end the row.</summary>
    private static List<T> ReadAll<T>(DbDataReader reader, Func<DbRow, T> read)
    {
        var row = Row(reader);
        var result = new List<T>();
        while (reader.Read())
        {
            row.Begin();
            result.Add(read(row));
            row.End();
        }

        return result;
    }

    [Test]
    public void A_missing_column_fails_with_the_query_name()
    {
        using var reader = Reader(("id", typeof(int), [1]), ("title", typeof(string), ["t"]));

        var error = Assert.Throws<DbShapeException>(() => ReadAll(reader, r => r.Text("slug")))!;

        Assert.That(error.Message, Does.StartWith("Articles.cs:ListAsync: ").And.Contain("column 'slug'"));
    }

    [Test]
    public void A_column_the_reader_never_reads_fails_on_the_first_row()
    {
        using var reader = Reader(("id", typeof(int), [1]), ("title", typeof(string), ["t"]), ("slug", typeof(string), ["s"]));

        var error = Assert.Throws<DbShapeException>(() => ReadAll(reader, r => (r.Int("id"), r.Text("title"))))!;

        Assert.That(error.Message, Does.StartWith("Articles.cs:ListAsync: ").And.Contain("'slug'").And.Contain("not read")
            .And.Not.Contain("'id'").And.Not.Contain("'title'"));
    }

    [Test]
    public void A_row_reader_that_skips_a_column_on_a_later_row_fails_on_that_row()
    {
        using var reader = Reader(("id", typeof(int), [1, 2]), ("title", typeof(string), ["a", "b"]));

        var error = Assert.Throws<DbShapeException>(() =>
            ReadAll(reader, r => r.Int("id") == 1 ? r.Text("title") : "skipped"))!;

        Assert.That(error.Message, Does.Contain("read 1 of 2 columns"));
    }

    [Test]
    public void A_column_read_twice_fails()
    {
        using var reader = Reader(("id", typeof(int), [1]));

        var error = Assert.Throws<DbShapeException>(() => ReadAll(reader, r => r.Int("id") + r.Int("id")))!;

        Assert.That(error.Message, Does.Contain("column 'id'").And.Contain("read twice"));
    }

    [Test]
    public void Each_typed_reader_returns_the_value()
    {
        var id = Guid.NewGuid();
        var when = new DateTimeOffset(2026, 11, 21, 10, 0, 0, TimeSpan.Zero);
        var day = new DateOnly(2026, 11, 21);
        using var reader = Reader(
            ("text", typeof(string), ["t"]), ("int", typeof(int), [1]), ("long", typeof(long), [2L]), ("bool", typeof(bool), [true]),
            ("decimal", typeof(decimal), [3.5m]), ("instant", typeof(DateTimeOffset), [when]), ("date", typeof(DateOnly), [day]),
            ("texts", typeof(string[]), [TwoTexts]), ("ints", typeof(int[]), [TwoInts]), ("guid", typeof(Guid), [id]));

        var values = ReadAll(reader, r => (object)(r.Text("text"), r.Int("int"), r.Long("long"), r.Bool("bool"), r.Decimal("decimal"),
            r.Instant("instant"), r.Date("date"), r.TextArray("texts"), r.IntArray("ints"), r.Guid("guid")));

        var (text, number, big, flag, money, instant, date, texts, ints, guid) =
            ((string, int, long, bool, decimal, DateTimeOffset, DateOnly, string[], int[], Guid))values.Single();
        Assert.Multiple(() =>
        {
            Assert.That(text, Is.EqualTo("t"));
            Assert.That(number, Is.EqualTo(1));
            Assert.That(big, Is.EqualTo(2L));
            Assert.That(flag, Is.True);
            Assert.That(money, Is.EqualTo(3.5m));
            Assert.That(instant, Is.EqualTo(when));
            Assert.That(date, Is.EqualTo(day));
            Assert.That(texts, Is.EqualTo(TwoTexts));
            Assert.That(ints, Is.EqualTo(TwoInts));
            Assert.That(guid, Is.EqualTo(id));
        });
    }

    [Test]
    public void Each_or_null_reader_returns_the_value_when_there_is_one()
    {
        using var reader = Reader(
            ("text", typeof(string), ["t"]), ("int", typeof(int), [1]), ("long", typeof(long), [2L]), ("bool", typeof(bool), [true]),
            ("instant", typeof(DateTimeOffset), [DateTimeOffset.UnixEpoch]), ("texts", typeof(string[]), [OneText]));

        var values = ReadAll(reader, r => new object?[]
        {
            r.TextOrNull("text"), r.IntOrNull("int"), r.LongOrNull("long"), r.BoolOrNull("bool"), r.InstantOrNull("instant"), r.TextArrayOrNull("texts"),
        }).Single();

        Assert.That(values, Is.EqualTo(new object?[] { "t", 1, 2L, true, DateTimeOffset.UnixEpoch, OneText }));
    }

    [Test]
    public void Each_or_null_reader_returns_null_for_a_database_null()
    {
        using var reader = Reader(
            ("text", typeof(string), [null]), ("int", typeof(int), [null]), ("long", typeof(long), [null]), ("bool", typeof(bool), [null]),
            ("instant", typeof(DateTimeOffset), [null]), ("texts", typeof(string[]), [null]));

        var values = ReadAll(reader, r => new object?[]
        {
            r.TextOrNull("text"), r.IntOrNull("int"), r.LongOrNull("long"), r.BoolOrNull("bool"), r.InstantOrNull("instant"), r.TextArrayOrNull("texts"),
        }).Single();

        Assert.That(values, Is.All.Null);
    }

    [Test]
    public void A_non_null_reader_on_a_database_null_names_the_column()
    {
        using var reader = Reader(("title", typeof(string), [null]));

        var error = Assert.Throws<DbShapeException>(() => ReadAll(reader, r => r.Text("title")))!;

        Assert.That(error.Message, Does.StartWith("Articles.cs:ListAsync: ").And.Contain("column 'title'").And.Contain("null"));
    }

    [Test]
    public void A_column_of_another_type_fails_naming_both_types()
    {
        using var reader = Reader(("id", typeof(string), ["abc"]));

        var error = Assert.Throws<DbShapeException>(() => ReadAll(reader, r => r.Int("id")))!;

        Assert.That(error.Message, Does.Contain("column 'id'").And.Contain("String").And.Contain("Int32"));
    }
}
