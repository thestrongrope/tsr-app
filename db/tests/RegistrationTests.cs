using System.Net;
using NUnit.Framework;

namespace Tsr.Db.Tests;

/// <summary>
/// GET and POST /registration against a real database, as the limited role: what PHP's routes/registration.php answers and writes,
/// quirks included (an update changes every row of a token and wipes three legacy columns, languages and interests are separate
/// unguarded writes, a duplicate interest id is a 500 after the old choices are gone).
/// </summary>
public sealed class RegistrationTests
{
    private const int Token = 900301;
    private const string Required = "\"preferredLocation\":\"Zurich\",\"birthYear\":1990,\"islamicStudyYears\":5";

    private MembershipTestKit _kit = null!;

    [OneTimeSetUp]
    public void Start() => _kit = new MembershipTestKit();

    [OneTimeTearDown]
    public void Stop() => _kit.Dispose();

    [SetUp]
    public async Task SeedAsync()
    {
        await MembershipTestKit.ResetAsync();
        await MembershipTestKit.AddMemberAsync(Token);
    }

    [Test]
    public async Task A_member_with_nothing_saved_gets_a_null_registration_the_option_list_and_empty_choices()
    {
        var reply = await _kit.SendAsync(Token, HttpMethod.Get, "/registration");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK));
        var body = reply.Json!;
        Assert.That(body["registration"], Is.Null);
        Assert.That(body["interestOptions"]!.AsArray(), Has.Count.EqualTo(16), "19 seeded, 3 inactive");
        Assert.That(body["interestOptions"]![0]!["id"]!.GetValue<int>(), Is.GreaterThan(0));
        Assert.That(body["interestOptions"]![0]!["name"]!.GetValue<string>(), Is.Not.Empty);
        Assert.That(body["selectedInterestIds"]!.AsArray(), Is.Empty);
        Assert.That(reply.Body, Does.Contain("\"languages\":{}"));
    }

    [Test]
    public async Task The_options_are_in_sort_order_then_name_and_inactive_ones_are_left_out()
    {
        await TestDatabase.ExecuteAsync("update membership.interest_options set is_active = false where id = 11");
        try
        {
            var reply = await _kit.SendAsync(Token, HttpMethod.Get, "/registration");

            var ids = reply.Json!["interestOptions"]!.AsArray().Select(o => o!["id"]!.GetValue<int>()).ToList();
            Assert.That(ids, Has.Count.EqualTo(15));
            Assert.That(ids, Does.Not.Contain(11));
            var expected = await TestDatabase.ScalarAsync<string>(
                "select string_agg(id::text, ',' order by sort_order, name) from membership.interest_options where is_active",
                TestDatabase.OwnerConnection);
            Assert.That(string.Join(',', ids), Is.EqualTo(expected));
        }
        finally
        {
            await TestDatabase.ExecuteAsync("update membership.interest_options set is_active = true where id = 11");
        }
    }

    [Test]
    public async Task With_duplicate_rows_the_first_by_id_is_read_with_raw_values_and_choices_are_listed()
    {
        await TestDatabase.ExecuteAsync(
            $"""
            insert into membership.class_registrations (token, preferred_location, birth_year, islamic_study_years, other_interests, field_of_study, status)
              values ({Token}, 'First', 1990, 5, 'O&#039;x', '["Law", "Science"]', 'Accepted'), ({Token}, 'Second', 1991, 1, null, null, 'Rejected');
            insert into membership.class_registrations_languages (token, language, skill, proficiency)
              values ({Token}, 'English', 'Read', 'Fluent'), ({Token}, 'Urdu', 'Read', 'Learning'), ({Token}, 'English', 'Speak', 'Fluent');
            insert into membership.student_interests (token, interest_id) values ({Token}, 13), ({Token}, 11);
            """);

        var body = (await _kit.SendAsync(Token, HttpMethod.Get, "/registration")).Json!;

        var registration = body["registration"]!;
        Assert.That(registration["preferredLocation"]!.GetValue<string>(), Is.EqualTo("First"));
        Assert.That(registration["status"]!.GetValue<string>(), Is.EqualTo("Accepted"));
        Assert.That(registration["otherInterests"]!.GetValue<string>(), Is.EqualTo("O&#039;x"));
        Assert.That(registration["fieldOfStudy"]!.AsArray().Select(n => n!.GetValue<string>()), Is.EqualTo(["Law", "Science"]));
        Assert.That(body["languages"]!.ToJsonString(), Is.EqualTo("{\"English\":{\"Read\":\"Fluent\",\"Speak\":\"Fluent\"},\"Urdu\":{\"Read\":\"Learning\"}}"));
        Assert.That(body["selectedInterestIds"]!.AsArray().Select(n => n!.GetValue<int>()).Order(), Is.EqualTo([11, 13]));
    }

    [Test]
    public async Task A_first_save_inserts_one_pending_row_with_the_cast_and_whitelisted_values()
    {
        var reply = await _kit.SendAsync(
            Token,
            HttpMethod.Post,
            "/registration",
            "{" + Required + ",\"education\":\"Doctorate (PhD / DPhil)\",\"fieldOfStudy\":[\"Law\",\"Nope\"],\"linkedinUrl\":\"https://www.linkedin.com/in/x\",\"workLocation\":\" Basel \"}");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(reply.Body, Is.EqualTo("{\"success\":true,\"message\":\"Class request submitted successfully\"}"));
        var row = (await TestDatabase.RowAsync(
            $"select preferred_location, birth_year, islamic_study_years, education, field_of_study::text as fos, linkedin_url, work_location, status, for_classid, modified_at from membership.class_registrations where token = {Token}"))!;
        Assert.That(row["preferred_location"], Is.EqualTo("Zurich"));
        Assert.That(row["birth_year"], Is.EqualTo("1990"));
        Assert.That(row["education"], Is.EqualTo("Doctorate (PhD / DPhil)"));
        Assert.That(row["fos"], Does.Contain("Law").And.Not.Contain("Nope"));
        Assert.That(row["work_location"], Is.EqualTo("Basel"));
        Assert.That(row["status"], Is.EqualTo("Pending"));
        Assert.That(row["for_classid"], Is.Null);
        Assert.That(row["modified_at"], Is.Null);
        Assert.That(await MembershipTestKit.CountAsync("membership.class_registrations", $"token = {Token}"), Is.EqualTo(1));
    }

    [TestCase("{}")]
    [TestCase("{\"preferredLocation\":\"Z\",\"birthYear\":1990}")]
    [TestCase("{\"preferredLocation\":\"Z\",\"birthYear\":1990,\"islamicStudyYears\":\"\"}")]
    public async Task A_missing_required_field_is_a_422_and_writes_nothing(string json)
    {
        var reply = await _kit.SendAsync(Token, HttpMethod.Post, "/registration", json);

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.UnprocessableEntity));
        Assert.That(reply.Detail, Is.EqualTo("preferredLocation, birthYear and islamicStudyYears are required"));
        Assert.That(await MembershipTestKit.CountAsync("membership.class_registrations"), Is.EqualTo(0));
    }

    [TestCase("not json")]
    [TestCase("null")]
    [TestCase("5")]
    public async Task A_body_that_is_not_an_object_or_list_is_a_422_Invalid_JSON_body(string json)
    {
        var reply = await _kit.SendAsync(Token, HttpMethod.Post, "/registration", json);

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.UnprocessableEntity));
        Assert.That(reply.Detail, Is.EqualTo("Invalid JSON body"));
    }

    [Test]
    public async Task An_empty_body_is_an_empty_form_so_the_required_message()
    {
        var reply = await _kit.SendAsync(Token, HttpMethod.Post, "/registration");

        Assert.That(reply.Detail, Is.EqualTo("preferredLocation, birthYear and islamicStudyYears are required"));
    }

    [Test]
    public async Task A_save_updates_every_row_of_the_token_wipes_three_legacy_columns_and_keeps_the_status()
    {
        await TestDatabase.ExecuteAsync(
            $"""
            insert into membership.class_registrations (token, preferred_location, birth_year, islamic_study_years, for_classid, profession, interests, status)
              values ({Token}, 'First', 1990, 5, 42, 'Teacher', 'Teaching,Research', 'Accepted'), ({Token}, 'Second', 1991, 1, 43, 'Writer', 'Debates', 'Rejected');
            """);

        var reply = await _kit.SendAsync(Token, HttpMethod.Post, "/registration", "{\"preferredLocation\":\"Basel\",\"birthYear\":\"1985\",\"islamicStudyYears\":\"0\"}");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(await MembershipTestKit.CountAsync("membership.class_registrations", $"token = {Token}"), Is.EqualTo(2), "no row added");
        Assert.That(await MembershipTestKit.CountAsync("membership.class_registrations", "preferred_location = 'Basel' and birth_year = 1985 and islamic_study_years = 0"), Is.EqualTo(2));
        Assert.That(await MembershipTestKit.CountAsync("membership.class_registrations", "for_classid is null and profession is null and interests is null"), Is.EqualTo(2));
        Assert.That(await MembershipTestKit.CountAsync("membership.class_registrations", "modified_at is not null"), Is.EqualTo(2));
        Assert.That(await MembershipTestKit.CountAsync("membership.class_registrations", "status = 'Accepted'"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("membership.class_registrations", "status = 'Rejected'"), Is.EqualTo(1));
    }

    [Test]
    public async Task A_non_empty_languages_map_replaces_the_saved_ones_with_the_valid_entries()
    {
        await TestDatabase.ExecuteAsync($"insert into membership.class_registrations_languages (token, language, skill, proficiency) values ({Token}, 'Hindi', 'Read', 'Fluent')");

        await _kit.SendAsync(
            Token,
            HttpMethod.Post,
            "/registration",
            "{" + Required + ",\"languages\":{\"English\":{\"Read\":\"Fluent\",\"Write\":\"Don't Know\"},\"Klingon\":{\"Read\":\"Fluent\"}}}");

        var rows = await TestDatabase.ScalarAsync<string>(
            $"select string_agg(language || '/' || skill || '/' || proficiency, ',') from membership.class_registrations_languages where token = {Token}",
            TestDatabase.OwnerConnection);
        Assert.That(rows, Is.EqualTo("English/Read/Fluent"));
    }

    [Test]
    public async Task A_non_empty_map_of_only_invalid_entries_erases_the_saved_languages()
    {
        await TestDatabase.ExecuteAsync($"insert into membership.class_registrations_languages (token, language, skill, proficiency) values ({Token}, 'Hindi', 'Read', 'Fluent')");

        await _kit.SendAsync(Token, HttpMethod.Post, "/registration", "{" + Required + ",\"languages\":{\"Klingon\":{\"Read\":\"Fluent\"}}}");

        Assert.That(await MembershipTestKit.CountAsync("membership.class_registrations_languages"), Is.EqualTo(0));
    }

    [TestCase("[]")]
    [TestCase("{}")]
    [TestCase("null")]
    public async Task An_empty_or_missing_languages_value_leaves_the_saved_ones(string languages)
    {
        await TestDatabase.ExecuteAsync($"insert into membership.class_registrations_languages (token, language, skill, proficiency) values ({Token}, 'Hindi', 'Read', 'Fluent')");

        await _kit.SendAsync(Token, HttpMethod.Post, "/registration", "{" + Required + ",\"languages\":" + languages + "}");

        Assert.That(await MembershipTestKit.CountAsync("membership.class_registrations_languages"), Is.EqualTo(1));
    }

    [Test]
    public async Task Interest_ids_replace_the_choices_keeping_only_active_options()
    {
        await TestDatabase.ExecuteAsync($"insert into membership.student_interests (token, interest_id) values ({Token}, 9)");
        await TestDatabase.ExecuteAsync("update membership.interest_options set is_active = false where id = 13");
        try
        {
            var reply = await _kit.SendAsync(Token, HttpMethod.Post, "/registration", "{" + Required + ",\"interestIds\":[11,999,13,\"1x\"]}");

            Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK));
            var ids = await TestDatabase.ScalarAsync<string>(
                $"select string_agg(interest_id::text, ',' order by interest_id) from membership.student_interests where token = {Token}",
                TestDatabase.OwnerConnection);
            Assert.That(ids, Is.EqualTo("1,11"));
        }
        finally
        {
            await TestDatabase.ExecuteAsync("update membership.interest_options set is_active = true where id = 13");
        }
    }

    [Test]
    public async Task An_empty_interest_list_erases_the_choices_and_a_missing_one_leaves_them()
    {
        await TestDatabase.ExecuteAsync($"insert into membership.student_interests (token, interest_id) values ({Token}, 9)");

        await _kit.SendAsync(Token, HttpMethod.Post, "/registration", "{" + Required + "}");
        Assert.That(await MembershipTestKit.CountAsync("membership.student_interests"), Is.EqualTo(1));

        await _kit.SendAsync(Token, HttpMethod.Post, "/registration", "{" + Required + ",\"interestIds\":[]}");
        Assert.That(await MembershipTestKit.CountAsync("membership.student_interests"), Is.EqualTo(0));
    }

    [Test]
    public async Task A_duplicate_interest_id_is_a_500_after_the_old_choices_are_deleted_and_the_first_copy_is_kept_as_in_PHP()
    {
        await TestDatabase.ExecuteAsync($"insert into membership.student_interests (token, interest_id) values ({Token}, 9)");

        var reply = await _kit.SendAsync(Token, HttpMethod.Post, "/registration", "{" + Required + ",\"interestIds\":[11,11]}");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.InternalServerError));
        var ids = await TestDatabase.ScalarAsync<string>(
            $"select coalesce(string_agg(interest_id::text, ','), '') from membership.student_interests where token = {Token}",
            TestDatabase.OwnerConnection);
        Assert.That(ids, Is.EqualTo("11"));
        Assert.That(await MembershipTestKit.CountAsync("membership.class_registrations", $"token = {Token}"), Is.EqualTo(1), "the registration was saved first");
    }

    [Test]
    public async Task A_member_never_reads_or_writes_another_members_rows()
    {
        const int other = 900302;
        await MembershipTestKit.AddMemberAsync(other);
        await TestDatabase.ExecuteAsync(
            $"insert into membership.class_registrations (token, preferred_location, birth_year, islamic_study_years) values ({other}, 'Other', 1980, 1)");

        var read = await _kit.SendAsync(Token, HttpMethod.Get, "/registration");
        await _kit.SendAsync(Token, HttpMethod.Post, "/registration", "{" + Required + "}");

        Assert.That(read.Json!["registration"], Is.Null);
        Assert.That(await MembershipTestKit.CountAsync("membership.class_registrations", $"token = {other} and preferred_location = 'Other'"), Is.EqualTo(1));
    }
}
