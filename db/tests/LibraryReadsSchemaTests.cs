using Npgsql;
using NUnit.Framework;

namespace Tsr.Db.Tests;

/// <summary>
/// The four tables of the Library reads (content's copy of the published content files), read from a database built by the
/// migrations alone: the planned columns, and the columns an address, a category and a tag are matched on are case-sensitive
/// (LIB-R3, LIB-R4, LIB-R11), unlike the rest of the schema.
/// </summary>
public sealed class LibraryReadsSchemaTests
{
    private const string ArticleColumns =
        "slug, slug_decoded, title, body_markdown, body_html, published_at, published_date_text, author, language, reading_minutes, categories, tags";

    [SetUp]
    public Task CleanAsync() => TestDatabase.ExecuteAsync(
        "truncate content.published_articles, content.categories, content.publications, content.refresh_state");

    [Test]
    public async Task Published_articles_has_the_planned_columns()
    {
        string[] expected =
        [
            "slug text not null",
            "slug_decoded text not null",
            "legacy_id int4 null",
            "title citext not null",
            "excerpt citext null",
            "body_markdown citext not null",
            "body_html citext not null",
            "published_at timestamptz not null",
            "published_date_text citext not null",
            "modified_at timestamptz null",
            "modified_date_text citext null",
            "author citext not null",
            "language citext not null",
            "reading_minutes int4 not null",
            "categories _text not null",
            "tags _text not null",
        ];

        Assert.That(await ColumnsAsync("published_articles"), Is.EqualTo(expected));
        Assert.That(await PrimaryKeyAsync("published_articles"), Is.EqualTo(["slug"]));
    }

    [Test]
    public async Task Categories_has_the_planned_columns()
    {
        string[] expected =
        [
            "slug text not null",
            "title citext not null",
            "description citext null",
            "sort_order int4 not null",
            "parent_slug text null",
        ];

        Assert.That(await ColumnsAsync("categories"), Is.EqualTo(expected));
        Assert.That(await PrimaryKeyAsync("categories"), Is.EqualTo(["slug"]));
    }

    [Test]
    public async Task Publications_has_the_planned_columns()
    {
        string[] expected =
        [
            "position int4 not null",
            "title citext not null",
            "summary citext null",
            "type citext null",
            "size citext null",
            "updated citext null",
            "language citext null",
            "file citext null",
            "read_online_url citext null",
            "download_only bool not null",
        ];

        Assert.That(await ColumnsAsync("publications"), Is.EqualTo(expected));
        Assert.That(await PrimaryKeyAsync("publications"), Is.EqualTo(["position"]));
    }

    [Test]
    public async Task Refresh_state_has_the_planned_columns()
    {
        string[] expected =
        [
            "id int4 not null",
            "content_hash citext not null",
            "article_count int4 not null",
            "refreshed_at timestamptz null",
            "last_failure_at timestamptz null",
            "last_failure_cause citext null",
        ];

        Assert.That(await ColumnsAsync("refresh_state"), Is.EqualTo(expected));
        Assert.That(await PrimaryKeyAsync("refresh_state"), Is.EqualTo(["id"]));
    }

    [Test]
    public async Task Published_articles_has_its_three_indexes()
    {
        var indexes = await ListAsync(
            """
            select indexname || ' ' || split_part(split_part(indexdef, ' USING ', 2), ' ', 1)
            from pg_indexes
            where schemaname = 'content' and tablename = 'published_articles' and indexname like 'idx_%'
            order by indexname
            """);

        Assert.That(indexes, Is.EqualTo(
        [
            "idx_published_articles_categories gin",
            "idx_published_articles_published_at btree",
            "idx_published_articles_tags gin",
        ]));
    }

    [Test]
    public async Task Two_slugs_that_differ_only_in_case_are_two_articles()
    {
        await InsertArticleAsync("ziyarat-ashura", "ziyarat-ashura");
        await InsertArticleAsync("Ziyarat-Ashura", "Ziyarat-Ashura");

        Assert.That(await CountAsync("select count(*) from content.published_articles"), Is.EqualTo(2));
        Assert.That(await CountAsync("select count(*) from content.published_articles where slug = 'Ziyarat-Ashura'"), Is.EqualTo(1));
        Assert.That(await CountAsync("select count(*) from content.published_articles where slug_decoded = 'ZIYARAT-ASHURA'"), Is.EqualTo(0));
    }

    [Test]
    public async Task A_tag_and_a_category_match_only_in_their_own_case()
    {
        await InsertArticleAsync("one", "one", categories: "{Supplications}", tags: "{Dua}");

        Assert.That(await CountAsync("select count(*) from content.published_articles where 'Dua' = any(tags)"), Is.EqualTo(1));
        Assert.That(await CountAsync("select count(*) from content.published_articles where 'dua' = any(tags)"), Is.EqualTo(0));
        Assert.That(await CountAsync("select count(*) from content.published_articles where 'Supplications' = any(categories)"), Is.EqualTo(1));
        Assert.That(await CountAsync("select count(*) from content.published_articles where 'supplications' = any(categories)"), Is.EqualTo(0));
    }

    [Test]
    public async Task Two_articles_cannot_share_a_decoded_slug()
    {
        await InsertArticleAsync("a%20b", "a b");

        var failure = await Assert.ThrowsAsync<PostgresException>(() => InsertArticleAsync("a%20B", "a b"));

        Assert.That(failure!.SqlState, Is.EqualTo(PostgresErrorCodes.UniqueViolation));
        Assert.That(failure.ConstraintName, Is.EqualTo("uq_published_articles_slug_decoded"));
    }

    [Test]
    public async Task Two_category_slugs_that_differ_only_in_case_are_two_categories()
    {
        await TestDatabase.ExecuteAsync(
            "insert into content.categories (slug, title, sort_order, parent_slug) values ('ahlulbayt', 'One', 1, null), ('Ahlulbayt', 'Two', 2, 'ahlulbayt')");

        Assert.That(await CountAsync("select count(*) from content.categories"), Is.EqualTo(2));
        Assert.That(await CountAsync("select count(*) from content.categories where parent_slug = 'AHLULBAYT'"), Is.EqualTo(0));
    }

    private static Task InsertArticleAsync(string slug, string slugDecoded, string categories = "{}", string tags = "{}") =>
        TestDatabase.ExecuteAsync(
            "insert into content.published_articles (" + ArticleColumns + ") values ('" + slug + "', '" + slugDecoded
            + "', 'Title', 'Body', '<p>Body</p>', now(), '2026-01-01', 'Author', 'en', 1, '" + categories + "', '" + tags + "')");

    private static Task<long> CountAsync(string sql) => TestDatabase.ScalarAsync<long>(sql, TestDatabase.OwnerConnection);

    /// <summary>"name type null|not null" for each column of a content table, in the table's own order.</summary>
    private static Task<List<string>> ColumnsAsync(string table) => ListAsync(
        "select column_name || ' ' || udt_name || case when is_nullable = 'YES' then ' null' else ' not null' end "
        + "from information_schema.columns where table_schema = 'content' and table_name = '" + table + "' order by ordinal_position");

    private static Task<List<string>> PrimaryKeyAsync(string table) => ListAsync(
        "select a.attname::text from pg_index i join pg_attribute a on a.attrelid = i.indrelid and a.attnum = any(i.indkey) "
        + "where i.indisprimary and i.indrelid = 'content." + table + "'::regclass");

    private static async Task<List<string>> ListAsync(string sql)
    {
        await using var connection = new NpgsqlConnection(TestDatabase.OwnerConnection);
        await connection.OpenAsync();
        await using var command = new NpgsqlCommand(sql, connection);
        var values = new List<string>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            values.Add(reader.GetString(0));
        }

        return values;
    }
}
