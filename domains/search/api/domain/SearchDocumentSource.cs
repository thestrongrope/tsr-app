using System.Runtime.CompilerServices;
using Npgsql;
using Tsr.Shared.Api;

namespace Tsr.Search.Api.Domain;

/// <summary>
/// What the index should hold, read from the database (PHP models/searchsource.php <c>allDocs</c>) through the published views only: <c>classes.v_classes</c>, <c>v_enrolments</c>, <c>v_teachers</c>, <c>v_guides</c>
/// and <c>membership.v_members</c>. Each kind is read in pages of <see cref="PageSize"/> by its id, so no query is unbounded. Documents: active classes; teachers with status 'A'; a guide per language-1 guide with text
/// of a level that has a public page (levels 2 to 5, as PHP's slugs), its id the level id; a person with a current enrolment in an active class is a student, otherwise a subscriber, never both; a token of 0 or less is never indexed.
/// One run at a time across instances: a PostgreSQL session advisory lock (key <see cref="LockKey"/>) taken with <c>pg_try_advisory_lock</c> on the run's own connection and released when the run is disposed;
/// a tick that finds it held is skipped (the next one tries again), which is simpler than waiting for it.
/// </summary>
internal sealed class SearchDocumentSource(DbSettings settings) : ISearchDocumentSource
{
    /// <summary>The advisory lock key of the search feed. Not used anywhere else (recorded in domains/search/CLAUDE.md).</summary>
    public const long LockKey = 8100001;

    public const int PageSize = 1000;

    private const int TimeoutSeconds = 30;

    public async Task<ISearchSourceRun?> TryOpenAsync(CancellationToken ct)
    {
        var builder = new NpgsqlConnectionStringBuilder(settings.ConnectionString) { Timeout = TimeoutSeconds, CommandTimeout = TimeoutSeconds };
        var connection = new NpgsqlConnection(builder.ConnectionString);
        try
        {
            await connection.OpenAsync(ct);
            await using var command = new NpgsqlCommand("select pg_try_advisory_lock(@key)", connection);
            command.Parameters.AddWithValue("key", LockKey);
            var taken = (bool)(await command.ExecuteScalarAsync(ct))!;
            if (taken)
            {
                return new Run(connection);
            }
        }
        catch
        {
            await connection.DisposeAsync();
            throw;
        }

        await connection.DisposeAsync();
        return null;
    }

    private sealed class Run(NpgsqlConnection connection) : ISearchSourceRun
    {
        private const string ClassesSql =
            """
            select id::bigint, coalesce(code, ''), case when gender in (1, 2) then gender::int else 0 end, coalesce(class_level_id, 0)::int, coalesce(level_name, '')
            from classes.v_classes where status = 'A' and id > @after order by id limit @page
            """;

        private const string TeachersSql =
            """
            select m.token::bigint, coalesce(max(m.name), ''), max(m.gender)
            from classes.v_teachers t join membership.v_members m on m.token = t.token
            where t.status = 'A' and m.token > 0 and m.token > @after
            group by m.token order by m.token limit @page
            """;

        private const string GuidesSql =
            """
            select level_id::bigint, coalesce(max(level_name), '')
            from classes.v_guides where language_id = 1 and has_text and level_id in (2, 3, 4, 5) and level_id > @after
            group by level_id order by level_id limit @page
            """;

        private const string PeopleSql =
            """
            select token::bigint, coalesce(max(name), ''), max(gender)
            from membership.v_members where token > 0 and token > @after
            group by token order by token limit @page
            """;

        private const string EnrolmentsSql =
            """
            select e.token_no::bigint, c.id::bigint, case when c.gender in (1, 2) then c.gender::int else 0 end
            from classes.v_enrolments e join classes.v_classes c on c.id = e.class_id and c.status = 'A'
            where e.removed_at is null and e.token_no = any(@tokens)
            order by e.token_no, c.id
            """;

        public async IAsyncEnumerable<SearchDocument> DocumentsAsync([EnumeratorCancellation] CancellationToken ct)
        {
            await foreach (var document in ClassesAsync(ct))
            {
                yield return document;
            }

            await foreach (var document in TeachersAsync(ct))
            {
                yield return document;
            }

            await foreach (var document in GuidesAsync(ct))
            {
                yield return document;
            }

            await foreach (var document in PeopleAsync(ct))
            {
                yield return document;
            }
        }

        public async ValueTask DisposeAsync()
        {
            try
            {
                await using var command = new NpgsqlCommand("select pg_advisory_unlock(@key)", connection);
                command.Parameters.AddWithValue("key", LockKey);
                await command.ExecuteScalarAsync();
            }
            finally
            {
                await connection.DisposeAsync();
            }
        }

        private async IAsyncEnumerable<SearchDocument> ClassesAsync([EnumeratorCancellation] CancellationToken ct)
        {
            var after = 0L;
            while (true)
            {
                var page = await ReadPageAsync(ClassesSql, after, r => SearchDocument.ForClass(r.GetInt64(0), r.GetString(1), r.GetInt32(2), r.GetInt32(3), r.GetString(4)), ct);
                foreach (var document in page)
                {
                    yield return document;
                }

                if (page.Count < PageSize)
                {
                    yield break;
                }

                after = page[^1].Id;
            }
        }

        private async IAsyncEnumerable<SearchDocument> TeachersAsync([EnumeratorCancellation] CancellationToken ct)
        {
            var after = 0L;
            while (true)
            {
                var page = await ReadPageAsync(TeachersSql, after, r => SearchDocument.ForTeacher(r.GetInt64(0), r.GetString(1), SearchDocument.GenderOf(Text(r, 2))), ct);
                foreach (var document in page)
                {
                    yield return document;
                }

                if (page.Count < PageSize)
                {
                    yield break;
                }

                after = page[^1].Id;
            }
        }

        private async IAsyncEnumerable<SearchDocument> GuidesAsync([EnumeratorCancellation] CancellationToken ct)
        {
            // At most four levels have a page, so one page is all there is.
            var page = await ReadPageAsync(GuidesSql, 0, r => SearchDocument.ForGuide(r.GetInt64(0), r.GetString(1)), ct);
            foreach (var document in page)
            {
                yield return document;
            }
        }

        private async IAsyncEnumerable<SearchDocument> PeopleAsync([EnumeratorCancellation] CancellationToken ct)
        {
            var after = 0L;
            while (true)
            {
                var people = await ReadPageAsync(PeopleSql, after, r => (r.GetInt64(0), r.GetString(1), SearchDocument.GenderOf(Text(r, 2))), ct);
                var classes = await ClassesOfAsync(people.Select(p => p.Item1).ToArray(), ct);
                foreach (var (token, name, gender) in people)
                {
                    yield return classes.TryGetValue(token, out var own) && own.Count > 0
                        ? SearchDocument.ForStudent(token, name, gender, own.Select(c => c.Id).ToList(), own.Select(c => c.Gender).Distinct().ToList())
                        : SearchDocument.ForSubscriber(token, name, gender);
                }

                if (people.Count < PageSize)
                {
                    yield break;
                }

                after = people[^1].Item1;
            }
        }

        private async Task<Dictionary<long, List<(long Id, int Gender)>>> ClassesOfAsync(long[] tokens, CancellationToken ct)
        {
            var byToken = new Dictionary<long, List<(long Id, int Gender)>>();
            await using var command = new NpgsqlCommand(EnrolmentsSql, connection);
            command.Parameters.AddWithValue("tokens", tokens);
            await using var reader = await command.ExecuteReaderAsync(ct);
            while (await reader.ReadAsync(ct))
            {
                var token = reader.GetInt64(0);
                if (!byToken.TryGetValue(token, out var list))
                {
                    list = [];
                    byToken[token] = list;
                }

                if (!list.Any(c => c.Id == reader.GetInt64(1)))
                {
                    list.Add((reader.GetInt64(1), reader.GetInt32(2)));
                }
            }

            return byToken;
        }

        private async Task<List<T>> ReadPageAsync<T>(string sql, long after, Func<NpgsqlDataReader, T> map, CancellationToken ct)
        {
            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("after", after);
            command.Parameters.AddWithValue("page", PageSize);
            var rows = new List<T>();
            await using var reader = await command.ExecuteReaderAsync(ct);
            while (await reader.ReadAsync(ct))
            {
                rows.Add(map(reader));
            }

            return rows;
        }

        private static string? Text(NpgsqlDataReader reader, int column) => reader.IsDBNull(column) ? null : reader.GetString(column);
    }
}
