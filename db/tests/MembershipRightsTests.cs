using Npgsql;
using NUnit.Framework;

namespace Tsr.Db.Tests;

/// <summary>
/// What the limited role the API connects as (<c>tsr_app</c>) may do with the membership schema: the data operations the ten operations
/// need (read, insert, update, delete on every table, sequences, the advisory lock) and nothing that changes the schema.
/// </summary>
public sealed class MembershipRightsTests
{
    [Test]
    public async Task The_app_role_may_read_write_and_delete_every_membership_table()
    {
        await using var connection = new NpgsqlConnection(TestDatabase.AppConnection);
        await connection.OpenAsync();

        foreach (var table in new[] { "member_profiles", "class_registrations", "class_registrations_languages", "student_interests", "user_guardians", "interest_options" })
        {
            Assert.That(await ExecuteAsync(connection, "select count(*) from membership." + table), Is.Not.Null, table + " readable");
        }

        await ExecuteAsync(connection, "insert into membership.class_registrations_languages (token, language, skill, proficiency) values (900999, 'English', 'Read', 'Fluent')");
        await ExecuteAsync(connection, "insert into membership.student_interests (token, interest_id) values (900999, 11)");
        await ExecuteAsync(connection, "insert into membership.user_guardians (child_token, status, source, code, created_by) values (900999, 'invited', 'link', 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeee01', 0)");
        await ExecuteAsync(connection, "update membership.user_guardians set status = 'revoked' where child_token = 900999");
        await ExecuteAsync(connection, "delete from membership.class_registrations_languages where token = 900999");
        await ExecuteAsync(connection, "delete from membership.student_interests where token = 900999");
        await ExecuteAsync(connection, "delete from membership.user_guardians where child_token = 900999");
    }

    [Test]
    public async Task The_app_role_may_take_the_transaction_level_advisory_lock_the_guardian_operations_use()
    {
        await using var connection = new NpgsqlConnection(TestDatabase.AppConnection);
        await connection.OpenAsync();
        await using var transaction = await connection.BeginTransactionAsync();

        var locked = await ScalarAsync(connection, "select pg_advisory_xact_lock(3001, 1) is null", transaction);

        Assert.That(locked, Is.Not.Null);
    }

    [Test]
    public async Task Two_sessions_asking_for_the_same_child_lock_wait_for_each_other()
    {
        await using var first = new NpgsqlConnection(TestDatabase.AppConnection);
        await using var second = new NpgsqlConnection(TestDatabase.AppConnection);
        await first.OpenAsync();
        await second.OpenAsync();
        await using var held = await first.BeginTransactionAsync();
        await ExecuteAsync(first, "select pg_advisory_xact_lock(3001, 77)", held);

        await using var other = await second.BeginTransactionAsync();
        var free = await ScalarAsync(second, "select pg_try_advisory_xact_lock(3001, 77)", other);
        var different = await ScalarAsync(second, "select pg_try_advisory_xact_lock(3001, 78)", other);

        Assert.That(free, Is.False, "the same child's lock is held");
        Assert.That(different, Is.True, "another child's lock is free");
    }

    [Test]
    public void The_app_role_cannot_change_the_schema()
    {
        using var connection = new NpgsqlConnection(TestDatabase.AppConnection);
        connection.Open();

        Assert.Throws<PostgresException>(() => ExecuteAsync(connection, "create table membership.extra (id int)").GetAwaiter().GetResult());
        Assert.Throws<PostgresException>(() => ExecuteAsync(connection, "alter table membership.user_guardians add column extra int").GetAwaiter().GetResult());
        Assert.Throws<PostgresException>(() => ExecuteAsync(connection, "truncate membership.user_guardians").GetAwaiter().GetResult());
    }

    [Test]
    public async Task A_token_may_have_several_registrations_and_the_same_active_pair_twice_because_PHPs_tables_have_no_key_for_it()
    {
        await TestDatabase.ExecuteAsync("truncate membership.class_registrations, membership.user_guardians restart identity");
        await TestDatabase.ExecuteAsync(
            """
            insert into membership.class_registrations (token, preferred_location) values (900998, 'a'), (900998, 'b');
            insert into membership.user_guardians (parent_token, child_token, relationship, status, source, created_by)
              values (900997, 900998, 'father', 'active', 'token_entry', 0), (900997, 900998, 'father', 'active', 'token_entry', 0);
            """);

        Assert.That(await MembershipTestKit.CountAsync("membership.class_registrations", "token = 900998"), Is.EqualTo(2));
        Assert.That(await MembershipTestKit.CountAsync("membership.user_guardians", "status = 'active'"), Is.EqualTo(2));
    }

    [Test]
    public async Task An_invite_code_is_unique()
    {
        var ex = await Assert.ThrowsAsync<PostgresException>(async () => await TestDatabase.ExecuteAsync(
            """
            insert into membership.user_guardians (child_token, status, source, code, created_by) values (1, 'invited', 'link', 'ffffffffffffffffffffffffffffff01', 0);
            insert into membership.user_guardians (child_token, status, source, code, created_by) values (2, 'invited', 'link', 'ffffffffffffffffffffffffffffff01', 0);
            """));

        Assert.That(ex!.SqlState, Is.EqualTo(PostgresErrorCodes.UniqueViolation));
    }

    private static async Task<object?> ScalarAsync(NpgsqlConnection connection, string sql, NpgsqlTransaction? transaction = null)
    {
        await using var command = new NpgsqlCommand(sql, connection, transaction);
        return await command.ExecuteScalarAsync();
    }

    private static async Task<object?> ExecuteAsync(NpgsqlConnection connection, string sql, NpgsqlTransaction? transaction = null)
    {
        await using var command = new NpgsqlCommand(sql, connection, transaction);
        return await command.ExecuteScalarAsync();
    }
}
