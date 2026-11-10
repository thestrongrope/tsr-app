using Npgsql;
using NUnit.Framework;

namespace Tsr.Db.Tests;

/// <summary>
/// membership's tables, platform's lookups and the identity change, read from a database built by the migrations alone:
/// PHP's enums and SET become CHECKs, PHP's keys stay as they were (no unique token on a registration, a unique guardian code),
/// no key leaves the schema, and the seeded option lists are the ones PHP holds.
/// </summary>
public sealed class MembershipSchemaTests
{
    [SetUp]
    public Task CleanAsync() => TestDatabase.ExecuteAsync(
        "truncate membership.member_profiles, membership.class_registrations, membership.class_registrations_languages, "
        + "membership.student_interests, membership.user_guardians restart identity");

    [Test]
    public async Task Identity_users_no_longer_has_a_gender_column()
    {
        var count = await TestDatabase.ScalarAsync<long>(
            "select count(*) from information_schema.columns where table_schema = 'identity' and table_name = 'users' and column_name = 'gender'",
            TestDatabase.OwnerConnection);

        Assert.That(count, Is.EqualTo(0));
    }

    [Test]
    public async Task Only_student_interests_has_a_foreign_key_and_it_stays_inside_the_schema()
    {
        var keys = await ColumnAsync(
            """
            select t.relname || ' -> ' || r.relname || ' (' || n1.nspname || ' to ' || n2.nspname || ')'
            from pg_constraint c
            join pg_class t on t.oid = c.conrelid join pg_namespace n1 on n1.oid = t.relnamespace
            join pg_class r on r.oid = c.confrelid join pg_namespace n2 on n2.oid = r.relnamespace
            where c.contype = 'f' and n1.nspname = 'membership'
            """);

        Assert.That(keys, Is.EqualTo(["student_interests -> interest_options (membership to membership)"]));
    }

    [Test]
    public async Task A_profile_keeps_PHPs_raw_gender_text_and_its_defaults()
    {
        await TestDatabase.ExecuteAsync(
            "insert into membership.member_profiles (user_id, gender) values (1, '1'), (2, '2'), (3, 'Male'), (4, 'Female'), (5, ''), (6, null)");

        var row = await TestDatabase.RowAsync("select * from membership.member_profiles order by user_id limit 1");
        Assert.That(row!["mobile"], Is.EqualTo(string.Empty));
        Assert.That(row["language"], Is.EqualTo("0"));
        Assert.That(row["sendupdates"], Is.EqualTo("N"));
        Assert.That(row["unsubscribe"], Is.EqualTo("N"));
        Assert.That(
            await TestDatabase.ScalarAsync<long>("select count(distinct gender) from membership.member_profiles where gender is not null", TestDatabase.OwnerConnection),
            Is.EqualTo(5));
    }

    [Test]
    public async Task A_token_may_have_several_registrations_and_the_token_has_a_plain_index()
    {
        await TestDatabase.ExecuteAsync(
            "insert into membership.class_registrations (token, status) values (900221, 'Pending'), (900221, 'Rejected')");

        Assert.That(
            await TestDatabase.ScalarAsync<long>("select count(*) from membership.class_registrations where token = 900221", TestDatabase.OwnerConnection),
            Is.EqualTo(2));
        var index = await ColumnAsync(
            "select indexdef from pg_indexes where schemaname = 'membership' and tablename = 'class_registrations' and indexname = 'idx_class_registrations_token'");
        Assert.That(index, Has.Count.EqualTo(1));
        Assert.That(index[0], Does.Not.Contain("UNIQUE"));
    }

    [Test]
    public async Task A_new_registration_is_pending_and_stamped_now()
    {
        await TestDatabase.ExecuteAsync("insert into membership.class_registrations (token) values (900222)");

        var row = await TestDatabase.RowAsync("select status, created_at is not null as stamped from membership.class_registrations");
        Assert.That(row!["status"], Is.EqualTo("Pending"));
        Assert.That(row["stamped"], Is.EqualTo("true"));
    }

    [TestCase("status", "Done")]
    [TestCase("class_level", "Expert")]
    [TestCase("interests", "Teaching,Nope")]
    public async Task A_registration_value_outside_PHPs_enum_or_set_is_refused(string column, string value)
    {
        var refused = await RefusedAsync(
            "insert into membership.class_registrations (token, " + column + ") values (900223, '" + value + "')");

        Assert.That(refused, Is.EqualTo(PostgresErrorCodes.CheckViolation));
    }

    [Test]
    public async Task A_registration_accepts_PHPs_set_values_in_any_case_and_an_empty_set()
    {
        await TestDatabase.ExecuteAsync(
            "insert into membership.class_registrations (token, interests, class_level) values "
            + "(900224, 'Teaching,Writing (articles / scripts),hr', 'IKP'), (900225, '', 'Primary'), (900226, null, null)");

        Assert.That(
            await TestDatabase.ScalarAsync<long>("select count(*) from membership.class_registrations", TestDatabase.OwnerConnection),
            Is.EqualTo(3));
    }

    [Test]
    public async Task The_multi_select_columns_hold_valid_JSON_only()
    {
        await TestDatabase.ExecuteAsync("insert into membership.class_registrations (token, field_of_study) values (900227, '[\"Law\",\"Science\"]')");

        var refused = await RefusedAsync("insert into membership.class_registrations (token, field_of_study) values (900228, 'not json')");

        Assert.That(refused, Is.Not.Null);
    }

    [TestCase("language", "Klingon")]
    [TestCase("skill", "Sing")]
    [TestCase("proficiency", "Expert")]
    public async Task A_language_row_outside_PHPs_enums_is_refused(string column, string value)
    {
        var refused = await RefusedAsync("insert into membership.class_registrations_languages (token, " + column + ") values (900221, '" + value + "')");

        Assert.That(refused, Is.EqualTo(PostgresErrorCodes.CheckViolation));
    }

    [Test]
    public async Task A_language_row_accepts_dont_know()
    {
        await TestDatabase.ExecuteAsync(
            "insert into membership.class_registrations_languages (token, language, skill, proficiency) values (900221, 'Urdu', 'Read', 'Don''t Know')");

        Assert.That(
            await TestDatabase.ScalarAsync<long>("select count(*) from membership.class_registrations_languages", TestDatabase.OwnerConnection),
            Is.EqualTo(1));
    }

    [Test]
    public async Task The_interest_options_are_the_19_PHP_holds_with_their_ids()
    {
        var row = await TestDatabase.RowAsync(
            "select count(*) as total, count(*) filter (where is_active) as active, "
            + "(select name from membership.interest_options where id = 1) as first, "
            + "(select name from membership.interest_options where id = 19) as last, "
            + "(select is_active from membership.interest_options where id = 12) as writing_active from membership.interest_options");

        Assert.That(row!["total"], Is.EqualTo("19"));
        Assert.That(row["active"], Is.EqualTo("16"));
        Assert.That(row["first"], Is.EqualTo("Class Coordination"));
        Assert.That(row["last"], Is.EqualTo("Legal"));
        Assert.That(row["writing_active"], Is.EqualTo("false"));
    }

    [Test]
    public async Task An_interest_option_name_is_unique_and_a_pick_names_an_existing_option_once()
    {
        Assert.That(
            await RefusedAsync("insert into membership.interest_options (name) values ('teaching')"),
            Is.EqualTo(PostgresErrorCodes.UniqueViolation));
        await TestDatabase.ExecuteAsync("insert into membership.student_interests (token, interest_id) values (900221, 11)");
        Assert.That(
            await RefusedAsync("insert into membership.student_interests (token, interest_id) values (900221, 11)"),
            Is.EqualTo(PostgresErrorCodes.UniqueViolation));
        Assert.That(
            await RefusedAsync("insert into membership.student_interests (token, interest_id) values (900221, 9999)"),
            Is.EqualTo(PostgresErrorCodes.ForeignKeyViolation));
    }

    [Test]
    public async Task A_guardian_code_is_unique_but_invites_without_one_and_duplicate_pairs_are_allowed()
    {
        await TestDatabase.ExecuteAsync(
            "insert into membership.user_guardians (child_token, source, created_by, code) values (900212, 'link', 1, 'CODE-A')");

        Assert.That(
            await RefusedAsync("insert into membership.user_guardians (child_token, source, created_by, code) values (900213, 'link', 1, 'code-a')"),
            Is.EqualTo(PostgresErrorCodes.UniqueViolation));
        await TestDatabase.ExecuteAsync(
            "insert into membership.user_guardians (parent_token, child_token, status, source, created_by) values "
            + "(900211, 900212, 'active', 'token_entry', 1), (900211, 900212, 'active', 'token_entry', 1)");
        Assert.That(
            await TestDatabase.ScalarAsync<long>("select count(*) from membership.user_guardians", TestDatabase.OwnerConnection),
            Is.EqualTo(3));
    }

    [TestCase("source, created_by, status", "'link', 1, 'pending'")]
    [TestCase("source, created_by", "'email', 1")]
    public async Task A_guardian_status_or_source_outside_PHPs_enum_is_refused(string columns, string values)
    {
        var refused = await RefusedAsync("insert into membership.user_guardians (child_token, " + columns + ") values (900212, " + values + ")");

        Assert.That(refused, Is.EqualTo(PostgresErrorCodes.CheckViolation));
    }

    [Test]
    public async Task A_guardian_relationship_outside_PHPs_enum_is_refused()
    {
        var refused = await RefusedAsync(
            "insert into membership.user_guardians (child_token, source, created_by, relationship) values (900212, 'link', 1, 'uncle')");

        Assert.That(refused, Is.EqualTo(PostgresErrorCodes.CheckViolation));
    }

    [Test]
    public async Task A_new_guardian_row_is_an_invite()
    {
        await TestDatabase.ExecuteAsync("insert into membership.user_guardians (child_token, source, created_by) values (900212, 'link', 1)");

        Assert.That(
            await TestDatabase.ScalarAsync<string>("select status::text from membership.user_guardians", TestDatabase.OwnerConnection),
            Is.EqualTo("invited"));
    }

    [Test]
    public async Task The_lookups_hold_the_seven_form_lists_with_72_options()
    {
        var types = await ColumnAsync(
            "select type::text || '=' || count(*) from platform.lookups where is_active group by type order by type");

        Assert.That(
            types,
            Is.EqualTo(
            [
                "education=8", "field_of_study=15", "field_of_work=18", "occupation_type=7",
                "professional_courses=10", "role_level=7", "years_experience=7",
            ]));
    }

    [Test]
    public async Task A_lookup_is_unique_by_type_and_code()
    {
        Assert.That(
            await RefusedAsync("insert into platform.lookups (type, code, label) values ('education', 'doctorate_phd_dphil', 'again')"),
            Is.EqualTo(PostgresErrorCodes.UniqueViolation));
    }

    [Test]
    public async Task The_education_labels_keep_PHPs_apostrophes_and_order()
    {
        var labels = await ColumnAsync("select label::text from platform.lookups where type = 'education' order by sort_order");

        Assert.That(labels[1], Is.EqualTo("Graduate (Bachelor's Degree)"));
        Assert.That(labels[0], Is.EqualTo("Doctorate (PhD / DPhil)"));
        Assert.That(labels, Has.Count.EqualTo(8));
    }

    private static async Task<List<string>> ColumnAsync(string sql)
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

    /// <summary>The SQLSTATE the database refused the statement with, or null when it ran.</summary>
    private static async Task<string?> RefusedAsync(string sql)
    {
        try
        {
            await TestDatabase.ExecuteAsync(sql);
            return null;
        }
        catch (PostgresException e)
        {
            return e.SqlState;
        }
    }
}
