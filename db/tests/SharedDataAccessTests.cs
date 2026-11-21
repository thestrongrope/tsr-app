using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.Extensions.DependencyInjection;
using Tsr.Platform.Api;
using Npgsql;
using NUnit.Framework;
using Tsr.Shared.Api;

namespace Tsr.Db.Tests;

/// <summary>
/// Probe for issue 96: what the slim Npgsql data source (arrays only, no extra conversions, no citext mapping)
/// does with citext columns and parameters, as the limited application role.
/// </summary>
public sealed class SharedDataAccessTests
{
    private const string Email = "Probe.Mixed@Example.invalid";
    private NpgsqlDataSource source = null!;
    private Microsoft.AspNetCore.Mvc.Testing.WebApplicationFactory<Program> factory = null!;
    private NpgsqlDataSource Data => factory.Services.GetRequiredService<NpgsqlDataSource>();
    private static readonly int[] OneId = [1];
    private static readonly int[] OneToken = [900990];
    private static readonly string[] AB = ["a", "b"];
    private static readonly string[] OneEmail = [Email];
    private static readonly string[] XY = ["x", "y"];
    private static readonly int[] OneTwo = [1, 2];
    private static readonly string Lower = Email.ToLowerInvariant();

    [OneTimeSetUp]
    public async Task StartAsync()
    {
        await using (var connection = new NpgsqlConnection(TestDatabase.OwnerConnection))
        {
            await connection.OpenAsync();
            await using var insert = new NpgsqlCommand(
                "insert into identity.users (token, email, firebase_uid) select 900990, @email, 'uid-probe-96' "
                + "where not exists (select 1 from identity.users where token = 900990)",
                connection);
            insert.Parameters.AddWithValue("email", Email);
            await insert.ExecuteNonQueryAsync();
        }

        source = new NpgsqlSlimDataSourceBuilder(TestDatabase.AppConnection).EnableArrays().Build();
        await TestDatabase.ExecuteAsync(
            """
            create table if not exists public.scratch_96 (id int primary key, note text);
            grant select, insert, update, delete on public.scratch_96 to tsr_app;
            """);
        // The data source the host registers (AddTsrDataSource), as the limited role.
        factory = TestApi.Create();
    }

    [SetUp]
    public Task ResetScratchAsync() => TestDatabase.ExecuteAsync("truncate public.scratch_96");

    [OneTimeTearDown]
    public void Stop()
    {
        source.Dispose();
        factory.Dispose();
    }

    private static Task<long> ScratchCountAsync() => TestDatabase.ScalarAsync<long>("select count(*) from public.scratch_96", TestDatabase.OwnerConnection);

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

    // TC-AOT-R1-01
    [Test]
    public async Task A_read_returns_each_row_mapped_by_name()
    {
        var rows = await Data.ListAsync(
            $"select token, email::text as email from identity.users where token = {900990} and email = {Email}::citext",
            r => (r.Int("token"), r.Text("email")),
            CancellationToken.None);

        Assert.That(rows, Is.EqualTo(new[] { (900990, Email) }));
    }

    // TC-AOT-R1-02
    [Test]
    public async Task A_committed_transaction_keeps_every_write()
    {
        await using (var tx = await Data.BeginAsync(CancellationToken.None))
        {
            Assert.That(await tx.ExecuteAsync($"insert into public.scratch_96 (id, note) values ({1}, {"a"})", CancellationToken.None), Is.EqualTo(1));
            await tx.ExecuteAsync($"insert into public.scratch_96 (id, note) values ({2}, {"b"})", CancellationToken.None);
            await tx.CommitAsync(CancellationToken.None);
        }

        Assert.That(await ScratchCountAsync(), Is.EqualTo(2));
    }

    [Test]
    public async Task A_transaction_disposed_without_commit_rolls_back()
    {
        await using (var tx = await Data.BeginAsync(CancellationToken.None))
        {
            await tx.ExecuteAsync($"insert into public.scratch_96 (id, note) values ({1}, {"a"})", CancellationToken.None);
            var inside = await tx.ListAsync($"select id from public.scratch_96", r => r.Int("id"), CancellationToken.None);
            Assert.That(inside, Is.EqualTo(OneId));
        }

        Assert.That(await ScratchCountAsync(), Is.EqualTo(0));
    }

    // The hook issue 98 needs: a joined transaction belongs to its owner.
    [Test]
    public async Task A_joined_transaction_is_neither_closed_nor_rolled_back_by_dispose()
    {
        await using var connection = await Data.OpenConnectionAsync();
        await using var owned = await connection.BeginTransactionAsync();
        await using (var joined = DbTx.Join(connection, owned))
        {
            await joined.ExecuteAsync($"insert into public.scratch_96 (id, note) values ({1}, {"a"})", CancellationToken.None);
        }

        Assert.That(connection.State, Is.EqualTo(System.Data.ConnectionState.Open));
        await owned.CommitAsync();
        Assert.That(await ScratchCountAsync(), Is.EqualTo(1));
    }

    // TC-AOT-R9-02
    [Test]
    public async Task A_failed_commit_leaves_nothing_and_throws()
    {
        await TestDatabase.ExecuteAsync(
            """
            create or replace function public.scratch_96_fail() returns trigger language plpgsql as
            $$ begin raise exception 'commit refused (test)'; end $$;
            drop trigger if exists scratch_96_deferred on public.scratch_96;
            create constraint trigger scratch_96_deferred after insert on public.scratch_96
            deferrable initially deferred for each row execute function public.scratch_96_fail();
            """);
        try
        {
            await using var tx = await Data.BeginAsync(CancellationToken.None);
            await tx.ExecuteAsync($"insert into public.scratch_96 (id, note) values ({1}, {"a"})", CancellationToken.None);

            await Assert.ThrowsAsync<PostgresException>(() => tx.CommitAsync(CancellationToken.None));
        }
        finally
        {
            await TestDatabase.ExecuteAsync("drop trigger scratch_96_deferred on public.scratch_96");
        }

        Assert.That(await ScratchCountAsync(), Is.EqualTo(0));
    }

    // TC-AOT-R5-03
    [Test]
    public async Task A_column_of_another_type_fails_with_the_query_name()
    {
        var error = await Assert.ThrowsAsync<DbShapeException>(() =>
            Data.ListAsync($"select 'abc'::text as id", r => r.Int("id"), CancellationToken.None))!;

        Assert.That(error!.Message, Does.StartWith("SharedDataAccessTests.cs:" + nameof(A_column_of_another_type_fails_with_the_query_name))
            .And.Contain("column 'id'").And.Contain("String").And.Contain("Int32"));
    }

    // A long column read as Int would silently narrow, an int column read as Long would silently widen: both fail.
    [Test]
    public async Task A_reader_of_a_different_integer_width_fails()
    {
        var narrow = await Assert.ThrowsAsync<DbShapeException>(() =>
            Data.ListAsync($"select 1::int8 as x", r => r.Int("x"), CancellationToken.None))!;
        var wide = await Assert.ThrowsAsync<DbShapeException>(() =>
            Data.ListAsync($"select 1::int4 as x", r => r.Long("x"), CancellationToken.None))!;

        Assert.That(narrow!.Message, Does.Contain("column 'x'").And.Contain("Int64").And.Contain("Int32"));
        Assert.That(wide!.Message, Does.Contain("column 'x'").And.Contain("Int32").And.Contain("Int64"));
    }

    [Test]
    public async Task Every_typed_reader_reads_its_own_database_type()
    {
        var row = (await Data.ListAsync(
            $"""
            select 'a'::text as t, 1::int4 as i, 2::int8 as l, true as b, 1.5::numeric as n, now() as at, current_date as d,
                   array['x','y']::text[] as ts, array[1,2]::int4[] as ia, gen_random_uuid() as g
            """,
            r => (r.Text("t"), r.Int("i"), r.Long("l"), r.Bool("b"), r.Decimal("n"), r.Instant("at"), r.Date("d"), r.TextArray("ts"), r.IntArray("ia"), r.Guid("g")),
            CancellationToken.None)).Single();

        Assert.That((row.Item1, row.Item2, row.Item3, row.Item4, row.Item5), Is.EqualTo(("a", 1, 2L, true, 1.5m)));
        Assert.That(row.Item8, Is.EqualTo(XY));
        Assert.That(row.Item9, Is.EqualTo(OneTwo));
    }

    [Test]
    public async Task A_timestamp_without_zone_is_not_an_instant()
    {
        var error = await Assert.ThrowsAsync<DbShapeException>(() =>
            Data.ListAsync($"select now()::timestamp as at", r => r.Instant("at"), CancellationToken.None))!;

        Assert.That(error!.Message, Does.Contain("column 'at'"));
    }

    [Test]
    public async Task Two_columns_of_one_name_fail()
    {
        var error = await Assert.ThrowsAsync<DbShapeException>(() =>
            Data.ListAsync($"select 1 as a, 2 as a", r => r.Int("a"), CancellationToken.None))!;

        Assert.That(error!.Message, Does.Contain("column 'a'").And.Contain("twice"));
    }

    // The message names the test's own file (by name, not by path) and method: the caller info reaches the message.
    [Test]
    public async Task The_error_names_the_real_calling_file_and_member()
    {
        var error = await Assert.ThrowsAsync<DbShapeException>(() =>
            Data.ListAsync($"select 1 as id", r => r.Int("wrong"), CancellationToken.None))!;

        Assert.That(error!.Message, Does.StartWith("SharedDataAccessTests.cs:" + nameof(The_error_names_the_real_calling_file_and_member) + ": "));
        Assert.That(error!.Message, Does.Not.Contain("/").And.Not.Contain("\\"));
    }

    [Test]
    public async Task A_scalar_is_the_first_column_of_the_first_row()
    {
        Assert.That(await Data.ScalarAsync<long>($"select count(*) from identity.users where token = {900990}", CancellationToken.None), Is.EqualTo(1L));
        Assert.That(await Data.ScalarAsync<int>($"select token from identity.users where token = {900990}", CancellationToken.None), Is.EqualTo(900990));
    }

    [Test]
    public async Task A_scalar_with_no_row_or_a_null_is_null()
    {
        Assert.That(await Data.ScalarAsync<int>($"select token from identity.users where token = {-1}", CancellationToken.None), Is.Null);
        Assert.That(await Data.ScalarAsync<int>($"select null::int", CancellationToken.None), Is.Null);
        Assert.That(await Data.ScalarAsync<int>($"select 1 where false", CancellationToken.None), Is.Null);
    }

    // Fix 2: a real 0 is not "no row".
    [Test]
    public async Task A_scalar_of_zero_is_zero_and_a_scalar_with_no_row_is_null()
    {
        Assert.That(await Data.ScalarAsync<int>($"select 0", CancellationToken.None), Is.EqualTo(0));
        Assert.That(await Data.ScalarAsync<int>($"select 0 where false", CancellationToken.None), Is.Null);
    }

    [Test]
    public async Task A_scalar_of_two_columns_or_another_type_fails()
    {
        var two = await Assert.ThrowsAsync<DbShapeException>(() => Data.ScalarAsync<int>($"select 1 as a, 2 as b", CancellationToken.None));
        var other = await Assert.ThrowsAsync<DbShapeException>(() => Data.ScalarAsync<int>($"select 'x'::text", CancellationToken.None));
        var wide = await Assert.ThrowsAsync<DbShapeException>(() => Data.ScalarAsync<int>($"select 1::int8", CancellationToken.None));

        Assert.That(two!.Message, Does.StartWith("SharedDataAccessTests.cs:").And.Contain("one column"));
        Assert.That(other!.Message, Does.Contain("String").And.Contain("Int32"));
        Assert.That(wide!.Message, Does.Contain("Int64").And.Contain("Int32"));
    }

    // Fix 1: the type is checked before any row is read, so an empty result cannot hide a wrongly typed scalar.
    [Test]
    public async Task A_wrongly_typed_scalar_with_no_row_still_fails()
    {
        var error = await Assert.ThrowsAsync<DbShapeException>(() =>
            Data.ScalarAsync<long>($"select 1::int4 where false", CancellationToken.None));

        Assert.That(error!.Message, Does.Contain("Int32").And.Contain("Int64"));
    }

    // Fix 3: a Sql value can be run twice (a count, then a list; a retry).
    [Test]
    public async Task One_Sql_value_runs_twice_with_the_same_rows()
    {
        Sql sql = $"select token from identity.users where token = {900990} and email = {Email}::citext";

        var first = await Data.ListAsync(sql, r => r.Int("token"), CancellationToken.None);
        var second = await Data.ListAsync(sql, r => r.Int("token"), CancellationToken.None);

        Assert.That(first, Is.EqualTo(OneToken));
        Assert.That(second, Is.EqualTo(first));
    }

    // Fix 4: a failed value read is a named shape error, with the cause kept.
    [Test]
    public async Task An_array_with_a_null_read_as_IntArray_fails_naming_the_column()
    {
        var error = await Assert.ThrowsAsync<DbShapeException>(() =>
            Data.ListAsync($"select array[1,null]::int4[] as ids", r => r.IntArray("ids"), CancellationToken.None))!;

        Assert.That(error!.Message, Does.StartWith("SharedDataAccessTests.cs:").And.Contain("column 'ids'"));
        Assert.That(error.InnerException, Is.InstanceOf<InvalidCastException>());
    }

    // Fix 5: text arrays of varchar and citext are read as string[].
    [Test]
    public async Task Varchar_and_citext_arrays_are_read_as_text_arrays()
    {
        var row = (await Data.ListAsync(
            $"select array['a','b']::varchar[] as v, array_agg(email) as c from identity.users where token = {900990}",
            r => (r.TextArray("v"), r.TextArray("c")),
            CancellationToken.None)).Single();

        Assert.That(row.Item1, Is.EqualTo(AB));
        Assert.That(row.Item2, Is.EqualTo(OneEmail));
    }

    [Test]
    public async Task Pin_the_array_type_names_npgsql_reports()
    {
        await using var command = Data.CreateCommand(
            "select array['a']::varchar[] as v, array_agg(email) as c, array['a']::text[] as t from identity.users where token = 900990");
        await using var reader = await command.ExecuteReaderAsync();
        Assert.Multiple(() =>
        {
            Assert.That(reader.GetDataTypeName(0), Is.EqualTo("character varying[]"));
            Assert.That(reader.GetDataTypeName(1), Is.EqualTo("public.citext[]"));
            Assert.That(reader.GetDataTypeName(2), Is.EqualTo("text[]"));
        });
    }

    [Test]
    public async Task A_smallint_is_read_and_sent_as_a_short()
    {
        short? none = null;
        var row = (await Data.ListAsync(
            $"select {(short)7}::int2 as s, {none}::int2 as n, 3::int2 as lit",
            r => (r.Short("s"), r.ShortOrNull("n"), r.Short("lit")),
            CancellationToken.None)).Single();

        Assert.That(row, Is.EqualTo(((short)7, (short?)null, (short)3)));
    }

    // Fix 6b
    [Test]
    public async Task A_joined_transaction_cannot_be_committed_by_the_joiner()
    {
        await using var connection = await Data.OpenConnectionAsync();
        await using var owned = await connection.BeginTransactionAsync();
        var joined = DbTx.Join(connection, owned);

        var error = await Assert.ThrowsAsync<InvalidOperationException>(() => joined.CommitAsync(CancellationToken.None));

        Assert.That(error!.Message, Does.Contain("owner commits"));
        await owned.RollbackAsync();
    }

    // Fix 6c
    [Test]
    public async Task A_committed_transaction_refuses_every_further_call()
    {
        await using var tx = await Data.BeginAsync(CancellationToken.None);
        await tx.CommitAsync(CancellationToken.None);
        var ct = CancellationToken.None;

        var errors = new[]
        {
            await Assert.ThrowsAsync<InvalidOperationException>(() => tx.ListAsync($"select 1 as x", r => r.Int("x"), ct)),
            await Assert.ThrowsAsync<InvalidOperationException>(() => tx.ScalarAsync<int>($"select 1", ct)),
            await Assert.ThrowsAsync<InvalidOperationException>(() => tx.ExecuteAsync($"delete from public.scratch_96", ct)),
            await Assert.ThrowsAsync<InvalidOperationException>(() => tx.CommitAsync(ct)),
            await Assert.ThrowsAsync<InvalidOperationException>(() =>
                Outbox.WriteAsync(tx, "test.committed", new OutboxSample("a", [1]), OutboxJson.Default.OutboxSample, TimeProvider.System, ct)),
        };

        Assert.That(errors.Select(e => e!.Message), Has.All.Contain("already committed"));
    }

    private static Task<long> OutboxCountAsync(string eventType) =>
        OwnerScalarAsync<long>("select count(*) from platform.outbox where event_type = @type", new NpgsqlParameter("type", eventType));

    private static async Task<T> OwnerScalarAsync<T>(string sql, params NpgsqlParameter[] parameters)
    {
        await using var connection = new NpgsqlConnection(TestDatabase.OwnerConnection);
        await connection.OpenAsync();
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddRange(parameters);
        return (T)(await command.ExecuteScalarAsync())!;
    }

    // TC-AOT-R3-01
    [Test]
    public async Task An_event_is_stored_only_when_its_transaction_commits()
    {
        const string type = "test.r3-01";
        await Data.ExecuteAsync($"delete from platform.outbox where event_type = {type}", CancellationToken.None);
        var payload = new OutboxSample("a", [1]);

        await using (var tx = await Data.BeginAsync(CancellationToken.None))
        {
            await tx.ExecuteAsync($"insert into public.scratch_96 (id, note) values ({1}, {"a"})", CancellationToken.None);
            await Outbox.WriteAsync(tx, type, payload, OutboxJson.Default.OutboxSample, TimeProvider.System, CancellationToken.None);
        }

        Assert.That(await ScratchCountAsync(), Is.EqualTo(0));
        Assert.That(await OutboxCountAsync(type), Is.EqualTo(0));

        await using (var tx = await Data.BeginAsync(CancellationToken.None))
        {
            await tx.ExecuteAsync($"insert into public.scratch_96 (id, note) values ({1}, {"a"})", CancellationToken.None);
            await Outbox.WriteAsync(tx, type, payload, OutboxJson.Default.OutboxSample, TimeProvider.System, CancellationToken.None);
            await tx.CommitAsync(CancellationToken.None);
        }

        Assert.That(await ScratchCountAsync(), Is.EqualTo(1));
        Assert.That(await OwnerScalarAsync<string>("select payload::text from platform.outbox where event_type = @type", new NpgsqlParameter("type", type)),
            Is.EqualTo("""{"name": "a", "member_token": [1]}"""));
    }

    // TC-AOT-R9-01
    [Test]
    public async Task A_failed_write_leaves_nothing_and_throws()
    {
        const string type = "test.r9-01";
        await TestDatabase.ExecuteAsync(
            """
            create function platform.fail_outbox_96() returns trigger language plpgsql as
            $$ begin raise exception 'outbox unavailable (test)'; end $$;
            create trigger fail_outbox_96 before insert on platform.outbox
            for each row execute function platform.fail_outbox_96();
            """);
        try
        {
            await using var tx = await Data.BeginAsync(CancellationToken.None);
            await tx.ExecuteAsync($"insert into public.scratch_96 (id, note) values ({1}, {"a"})", CancellationToken.None);

            await Assert.ThrowsAsync<PostgresException>(() =>
                Outbox.WriteAsync(tx, type, new OutboxSample("a", [1]), OutboxJson.Default.OutboxSample, TimeProvider.System, CancellationToken.None));
        }
        finally
        {
            await TestDatabase.ExecuteAsync("drop trigger fail_outbox_96 on platform.outbox; drop function platform.fail_outbox_96();");
        }

        Assert.That(await ScratchCountAsync(), Is.EqualTo(0));
        Assert.That(await OutboxCountAsync(type), Is.EqualTo(0));
    }

    // TC-AOT-R6-02
    [Test]
    public async Task An_ef_transaction_and_a_joined_DbTx_commit_or_roll_back_together()
    {
        await RunEfAndJoinedAsync(commit: false);
        Assert.That(await ScratchCountAsync(), Is.EqualTo(0));

        await RunEfAndJoinedAsync(commit: true);
        Assert.That(await ScratchCountAsync(), Is.EqualTo(2));
    }

    private async Task RunEfAndJoinedAsync(bool commit)
    {
        await TestDatabase.ExecuteAsync("truncate public.scratch_96");
        await using var scope = factory.Services.CreateAsyncScope();
        var context = scope.ServiceProvider.GetRequiredService<PlatformContext>();
        await using var efTransaction = await context.Database.BeginTransactionAsync();

        var joined = DbTx.Join((NpgsqlConnection)context.Database.GetDbConnection(), (NpgsqlTransaction)efTransaction.GetDbTransaction());
        await joined.ExecuteAsync($"insert into public.scratch_96 (id, note) values ({1}, {"joined"})", CancellationToken.None);
        await context.Database.ExecuteSqlAsync($"insert into public.scratch_96 (id, note) values ({2}, {"ef"})");

        if (commit)
        {
            await efTransaction.CommitAsync();
        }
        else
        {
            await efTransaction.RollbackAsync();
        }
    }
}

internal sealed record OutboxSample(string Name, [property: JsonPropertyName("member_token")] int[] MemberToken);

[JsonSourceGenerationOptions(JsonSerializerDefaults.Web)]
[JsonSerializable(typeof(OutboxSample))]
internal sealed partial class OutboxJson : JsonSerializerContext;
