using Npgsql;
using NUnit.Framework;

namespace Tsr.Db.Tests;

/// <summary>
/// Probe for issue 96: what the slim Npgsql data source (arrays only, no extra conversions, no citext mapping)
/// does with citext columns and parameters, as the limited application role.
/// </summary>
public sealed class SharedDataAccessTests
{
    private const string Email = "Probe.Mixed@Example.invalid";
    private NpgsqlDataSource source = null!;
    private static readonly string Lower = Email.ToLowerInvariant();

    [OneTimeSetUp]
    public async Task StartAsync()
    {
        await TestDatabase.ExecuteAsync(
            "insert into identity.users (token, email, firebase_uid) select 900990, '" + Email + "', 'uid-probe-96' "
            + "where not exists (select 1 from identity.users where token = 900990)");
        source = new NpgsqlSlimDataSourceBuilder(TestDatabase.AppConnection).EnableArrays().Build();
    }

    [OneTimeTearDown]
    public void Stop() => source.Dispose();

    private async Task<List<string>> ColumnAsync(string sql, params NpgsqlParameter[] parameters)
    {
        await using var command = source.CreateCommand(sql);
        command.Parameters.AddRange(parameters);
        await using var reader = await command.ExecuteReaderAsync();
        var rows = new List<string>();
        while (await reader.ReadAsync())
        {
            rows.Add(reader.GetString(0));
        }
        return rows;
    }

    // Pins (a): an uncast citext column is read by the slim source, as string, with the stored value.
    [Test]
    public async Task A_uncast_citext_column_reads_as_string()
    {
        var rows = await ColumnAsync("select email from identity.users where token = 900990 limit 1");
        Assert.That(rows, Is.EqualTo(new[] { Email }));

        await using var command = source.CreateCommand("select email from identity.users where token = 900990 limit 1");
        await using var reader = await command.ExecuteReaderAsync();
        Assert.That(await reader.ReadAsync(), Is.True);
        Assert.That(reader.GetFieldValue<string>(0), Is.EqualTo(Email));
    }

    // Pins (b): with zero rows and before any ReadAsync, the metadata still names citext, so an uncast citext column is detectable.
    [Test]
    public async Task B_citext_metadata_is_known_with_zero_rows()
    {
        await using var command = source.CreateCommand("select email from identity.users where token = -1 limit 1");
        await using var reader = await command.ExecuteReaderAsync();
        Assert.That(reader.GetDataTypeName(0), Is.EqualTo("public.citext"));
        Assert.That(reader.GetFieldType(0), Is.EqualTo(typeof(string)));
        Assert.That(reader.GetPostgresType(0).Name, Is.EqualTo("citext"));
    }

    // Pins (c): a text parameter without a cast runs but compares case-sensitively (the wrong case finds nothing).
    [Test]
    public async Task C1_text_parameter_without_cast_is_case_sensitive()
    {
        var wrongCase = await ColumnAsync("select email from identity.users where email = @p0", new NpgsqlParameter("p0", Lower));
        var exact = await ColumnAsync("select email from identity.users where email = @p0", new NpgsqlParameter("p0", Email));
        Assert.That(wrongCase, Is.Empty);
        Assert.That(exact, Is.EqualTo(new[] { Email }));
    }

    // Pins (c): with ::citext the comparison ignores case, so the wrong case finds the row.
    [Test]
    public async Task C2_text_parameter_cast_to_citext_is_case_insensitive()
    {
        var rows = await ColumnAsync("select email from identity.users where email = @p0::citext", new NpgsqlParameter("p0", Lower));
        Assert.That(rows, Is.EqualTo(new[] { Email }));
    }

    // Pins (d): a string[] parameter cast ::citext[] runs and is case-insensitive; uncast it runs and is case-sensitive.
    [Test]
    public async Task D_string_array_with_citext_cast_is_case_insensitive_and_without_is_not()
    {
        var cast = await ColumnAsync("select email from identity.users where email = any(@p0::citext[])", new NpgsqlParameter("p0", new[] { Lower }));
        var uncast = await ColumnAsync("select email from identity.users where email = any(@p0)", new NpgsqlParameter("p0", new[] { Lower }));
        Assert.That(cast, Is.EqualTo(new[] { Email }));
        Assert.That(uncast, Is.Empty);
    }

    // Pins (e): the control, the column cast to text, reads as string with the stored value and reports type text.
    [Test]
    public async Task E_text_cast_control_reads_as_string()
    {
        await using var command = source.CreateCommand("select email::text from identity.users where token = 900990");
        await using var reader = await command.ExecuteReaderAsync();
        Assert.That(reader.GetDataTypeName(0), Is.EqualTo("text"));
        Assert.That(await reader.ReadAsync(), Is.True);
        Assert.That(reader.GetString(0), Is.EqualTo(Email));
    }
}
