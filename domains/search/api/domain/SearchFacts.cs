using Npgsql;
using Tsr.Shared.Api;

namespace Tsr.Search.Api.Domain;

/// <summary>An active class as the re-check reads it: its code, its level's name (empty without one) and its gender (0 when unknown).</summary>
internal sealed record ClassFact(int Id, string Code, string LevelName, int Gender, int LevelId);

/// <summary>
/// The fresh reads that follow the index (PHP SearchSourceModel and EntityAccessModel): the index is only a list of pointers, so
/// every hit is checked again against the database. Published views only: <c>classes.v_classes</c>, <c>classes.v_enrolments</c>
/// and <c>membership.v_members</c>. Fake in unit tests.
/// </summary>
internal interface ISearchFacts
{
    /// <summary>PHP api_require_identity: the caller's stored gender is numeric.</summary>
    Task<bool> HasNumericGenderAsync(int userId, CancellationToken ct);

    /// <summary>The active classes among these ids.</summary>
    Task<IReadOnlyList<ClassFact>> ActiveClassesAsync(IReadOnlyCollection<long> classIds, CancellationToken ct);

    /// <summary>The active classes of these levels, by id.</summary>
    Task<IReadOnlyList<ClassFact>> ActiveClassesOfLevelsAsync(IReadOnlyCollection<long> levelIds, CancellationToken ct);

    /// <summary>The member's current (not removed) active classes, by code, for each token.</summary>
    Task<IReadOnlyDictionary<long, IReadOnlyList<ClassFact>>> CurrentClassesAsync(IReadOnlyCollection<long> tokens, CancellationToken ct);

    /// <summary>The name of each token's member (the first row when several share a token); a token with no member is absent.</summary>
    Task<IReadOnlyDictionary<long, string>> MemberNamesAsync(IReadOnlyCollection<long> tokens, CancellationToken ct);
}

internal sealed class SearchFacts(DbSettings settings) : ISearchFacts
{
    private const int TimeoutSeconds = 15;

    private const string ClassColumns = "id::int, code, coalesce(level_name, '') as level_name, coalesce(gender, 0)::int as gender, coalesce(class_level_id, 0)::int as level_id";

    private const string ClassesByIdSql = "select " + ClassColumns + " from classes.v_classes where status = 'A' and id = any(@ids) order by id";

    private const string ClassesByLevelSql = "select " + ClassColumns + " from classes.v_classes where status = 'A' and class_level_id = any(@ids) order by id";

    public async Task<bool> HasNumericGenderAsync(int userId, CancellationToken ct)
    {
        await using var connection = await OpenAsync(ct);
        await using var command = new NpgsqlCommand("select coalesce(gender, '') from membership.v_members where user_id = @user limit 1", connection);
        command.Parameters.AddWithValue("user", userId);
        var gender = await command.ExecuteScalarAsync(ct) as string;
        return gender is not null && PhpValue.IsNumeric(gender);
    }

    public Task<IReadOnlyList<ClassFact>> ActiveClassesAsync(IReadOnlyCollection<long> classIds, CancellationToken ct) =>
        ReadClassesAsync(ClassesByIdSql, classIds, ct);

    public Task<IReadOnlyList<ClassFact>> ActiveClassesOfLevelsAsync(IReadOnlyCollection<long> levelIds, CancellationToken ct) =>
        ReadClassesAsync(ClassesByLevelSql, levelIds, ct);

    public async Task<IReadOnlyDictionary<long, IReadOnlyList<ClassFact>>> CurrentClassesAsync(IReadOnlyCollection<long> tokens, CancellationToken ct)
    {
        var byToken = new Dictionary<long, List<ClassFact>>();
        if (tokens.Count == 0)
        {
            return new Dictionary<long, IReadOnlyList<ClassFact>>();
        }

        await using var connection = await OpenAsync(ct);
        await using var command = new NpgsqlCommand(
            """
            select e.token_no::bigint, c.id::int, c.code, coalesce(c.level_name, ''), coalesce(c.gender, 0)::int, coalesce(c.class_level_id, 0)::int
            from classes.v_enrolments e
            join classes.v_classes c on c.id = e.class_id and c.status = 'A'
            where e.token_no = any(@ids) and e.removed_at is null
            order by c.code, c.id
            """,
            connection);
        command.Parameters.AddWithValue("ids", tokens.ToArray());
        await using var reader = await command.ExecuteReaderAsync(ct);
        while (await reader.ReadAsync(ct))
        {
            var token = reader.GetInt64(0);
            if (!byToken.TryGetValue(token, out var list))
            {
                list = [];
                byToken[token] = list;
            }

            list.Add(new ClassFact(reader.GetInt32(1), reader.GetString(2), reader.GetString(3), reader.GetInt32(4), reader.GetInt32(5)));
        }

        return byToken.ToDictionary(pair => pair.Key, pair => (IReadOnlyList<ClassFact>)pair.Value);
    }

    public async Task<IReadOnlyDictionary<long, string>> MemberNamesAsync(IReadOnlyCollection<long> tokens, CancellationToken ct)
    {
        var names = new Dictionary<long, string>();
        if (tokens.Count == 0)
        {
            return names;
        }

        await using var connection = await OpenAsync(ct);
        await using var command = new NpgsqlCommand("select token::bigint, coalesce(name, '') from membership.v_members where token = any(@ids) order by user_id", connection);
        command.Parameters.AddWithValue("ids", tokens.ToArray());
        await using var reader = await command.ExecuteReaderAsync(ct);
        while (await reader.ReadAsync(ct))
        {
            names.TryAdd(reader.GetInt64(0), reader.GetString(1));
        }

        return names;
    }

    private async Task<IReadOnlyList<ClassFact>> ReadClassesAsync(string sql, IReadOnlyCollection<long> ids, CancellationToken ct)
    {
        var classes = new List<ClassFact>();
        if (ids.Count == 0)
        {
            return classes;
        }

        await using var connection = await OpenAsync(ct);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("ids", ids.ToArray());
        await using var reader = await command.ExecuteReaderAsync(ct);
        while (await reader.ReadAsync(ct))
        {
            classes.Add(new ClassFact(reader.GetInt32(0), reader.GetString(1), reader.GetString(2), reader.GetInt32(3), reader.GetInt32(4)));
        }

        return classes;
    }

    private async Task<NpgsqlConnection> OpenAsync(CancellationToken ct)
    {
        var builder = new NpgsqlConnectionStringBuilder(settings.ConnectionString) { Timeout = TimeoutSeconds, CommandTimeout = TimeoutSeconds };
        var connection = new NpgsqlConnection(builder.ConnectionString);
        await connection.OpenAsync(ct);
        return connection;
    }
}
