using System.Net;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using NUnit.Framework;
using Tsr.Membership.Api;

namespace Tsr.Db.Tests;

/// <summary>
/// GET and PATCH /me against a real database, as the limited role: PHP's cast (routes/users.php), validation order and messages,
/// the place rules against the geo tables, the gender lock through the classes port, and what PDO and MariaDB make of odd values.
/// </summary>
public sealed class ProfileTests
{
    private const int Token = 900501;
    private static readonly string[] Keys =
        ["id", "token", "email", "name", "roleid", "picture", "gender", "age_range", "mobile", "country", "state", "city", "language", "zip", "sendupdates", "unsubscribe"];

    private MembershipTestKit _kit = null!;
    private int _userId;

    [OneTimeSetUp]
    public void Start() => _kit = new MembershipTestKit();

    [OneTimeTearDown]
    public void Stop() => _kit.Dispose();

    [SetUp]
    public async Task SeedAsync()
    {
        await MembershipTestKit.ResetAsync();
        await TestDatabase.ExecuteAsync(
            """
            truncate platform.geo_cities, platform.geo_postal_codes, platform.geo_countries;
            insert into platform.geo_countries (code, name, has_postal_codes, postal_code_regex) values
              ('CH', 'Switzerland', true, null), ('IR', 'Iran', false, '^\d{10}$'), ('XX', 'Nowhere', false, null);
            insert into platform.geo_postal_codes (country_code, postal_code, city, state) values ('CH', '8001', 'Zürich', 'Zürich'), ('CH', '3011', '0', 'Bern');
            """);
        _userId = await MembershipTestKit.AddMemberAsync(Token, "Synthetic Member", "1");
    }

    // ---- POST /auth/link: the app's first call after sign-in reads the same profile as GET /me (PHP routes/auth.php)

    [Test]
    public async Task Signing_in_answers_me_with_the_same_sixteen_fields_as_GET_me()
    {
        await TestDatabase.ExecuteAsync($"update membership.member_profiles set mobile = '+911234567890', language = 2 where user_id = {_userId}");
        await TestDatabase.ExecuteAsync($"insert into access.user_roles (user_id, roleid) values ({_userId}, 3)");

        var link = await _kit.SendAsync(Token, HttpMethod.Post, "/auth/link");
        var me = await _kit.SendAsync(Token, HttpMethod.Get, "/me");

        Assert.That(link.Status, Is.EqualTo(HttpStatusCode.OK), link.Body);
        Assert.That(link.Json!.AsObject().Select(p => p.Key).Single(), Is.EqualTo("me"));
        Assert.That(link.Json!["me"]!.ToJsonString(), Is.EqualTo(me.Json!.ToJsonString()));
    }

    // ---- GET /me

    [Test]
    public async Task A_member_gets_the_sixteen_fields_of_the_wire_contract_in_order()
    {
        await TestDatabase.ExecuteAsync(
            $"update membership.member_profiles set mobile = '+911234567890', country = 'Switzerland', state = 'Zürich', city = 'Zürich', zip = '8001', language = 2, age_range = '5', picture = 'https://example.invalid/p.png' where user_id = {_userId}");
        await TestDatabase.ExecuteAsync($"insert into access.user_roles (user_id, roleid) values ({_userId}, 3)");

        var reply = await _kit.SendAsync(Token, HttpMethod.Get, "/me");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK));
        var body = reply.Json!.AsObject();
        Assert.That(body.Select(p => p.Key), Is.EqualTo(Keys));
        Assert.That(body["id"]!.GetValue<int>(), Is.EqualTo(_userId));
        Assert.That(body["token"]!.GetValue<int>(), Is.EqualTo(Token));
        Assert.That(body["email"]!.GetValue<string>(), Is.EqualTo(MembershipTestKit.EmailOf(Token)));
        Assert.That(body["name"]!.GetValue<string>(), Is.EqualTo("Synthetic Member"));
        Assert.That(body["roleid"]!.GetValue<int>(), Is.EqualTo(3));
        Assert.That(body["gender"]!.GetValue<int>(), Is.EqualTo(1));
        Assert.That(body["age_range"]!.GetValue<int>(), Is.EqualTo(5));
        Assert.That(body["mobile"]!.GetValue<string>(), Is.EqualTo("+911234567890"));
        Assert.That(body["language"]!.GetValue<int>(), Is.EqualTo(2));
        Assert.That(body["sendupdates"]!.GetValue<string>(), Is.EqualTo("N"));
    }

    [Test]
    public async Task A_member_with_no_profile_row_shows_PHPs_defaults_and_a_role_of_zero()
    {
        await TestDatabase.ExecuteAsync($"delete from membership.member_profiles where user_id = {_userId}");

        var body = (await _kit.SendAsync(Token, HttpMethod.Get, "/me")).Json!;

        Assert.That(body["name"]!.GetValue<int>(), Is.EqualTo(0));
        Assert.That(body["roleid"]!.GetValue<int>(), Is.EqualTo(0));
        Assert.That(body["language"]!.GetValue<int>(), Is.EqualTo(0));
        Assert.That(body["mobile"], Is.Null);
        Assert.That(body["sendupdates"]!.GetValue<string>(), Is.EqualTo("N"));
        Assert.That(await MembershipTestKit.CountAsync("membership.member_profiles"), Is.EqualTo(0), "a read creates nothing");
    }

    [Test]
    public async Task Text_fields_are_entity_decoded_the_picture_is_not_and_an_empty_name_is_zero()
    {
        await TestDatabase.ExecuteAsync(
            $"update membership.member_profiles set name = 'O&#039;Neil &amp; Co', picture = 'https://example.invalid/p?a=1&amp;b=2', city = 'St&#039;s' where user_id = {_userId}");

        var body = (await _kit.SendAsync(Token, HttpMethod.Get, "/me")).Json!;

        Assert.That(body["name"]!.GetValue<string>(), Is.EqualTo("O'Neil & Co"));
        Assert.That(body["city"]!.GetValue<string>(), Is.EqualTo("St's"));
        Assert.That(body["picture"]!.GetValue<string>(), Is.EqualTo("https://example.invalid/p?a=1&amp;b=2"));

        await TestDatabase.ExecuteAsync($"update membership.member_profiles set name = '' where user_id = {_userId}");
        Assert.That((await _kit.SendAsync(Token, HttpMethod.Get, "/me")).Json!["name"]!.GetValue<int>(), Is.EqualTo(0));
    }

    [TestCase("Male")]
    [TestCase("Female")]
    [TestCase("")]
    public async Task A_gender_that_is_not_a_number_reads_as_null(string stored)
    {
        await TestDatabase.ExecuteAsync($"update membership.member_profiles set gender = '{stored}' where user_id = {_userId}");

        Assert.That((await _kit.SendAsync(Token, HttpMethod.Get, "/me")).Json!["gender"], Is.Null);
    }

    [Test]
    public async Task A_pending_account_deletion_still_lets_the_member_read_but_not_change_their_profile()
    {
        await TestDatabase.ExecuteAsync($"insert into identity.account_deletion_requests (token, status, requested_at) values ({Token}, 'pending', now())");

        var read = await _kit.SendAsync(Token, HttpMethod.Get, "/me");
        var write = await _kit.SendAsync(Token, HttpMethod.Patch, "/me", "{\"name\":\"Another Name\"}");

        Assert.That(read.Status, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(write.Status, Is.EqualTo(HttpStatusCode.Forbidden));
        Assert.That(write.Detail, Is.EqualTo("Account deletion pending"));
        Assert.That(write.Json!["deletion_status"]!.GetValue<string>(), Is.EqualTo("pending"));
    }

    // ---- PATCH /me: validation

    [Test]
    public async Task A_body_with_no_updatable_key_is_a_200_with_the_current_profile_and_nothing_is_validated()
    {
        var reply = await _kit.SendAsync(Token, HttpMethod.Patch, "/me", "{\"bogus\":\"x\",\"id\":5,\"email\":\"other@example.invalid\",\"roleid\":1}");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(reply.Json!["name"]!.GetValue<string>(), Is.EqualTo("Synthetic Member"));
        Assert.That(reply.Json!["roleid"]!.GetValue<int>(), Is.EqualTo(0));
        Assert.That((await _kit.SendAsync(Token, HttpMethod.Patch, "/me", "[]")).Status, Is.EqualTo(HttpStatusCode.OK));
        Assert.That((await _kit.SendAsync(Token, HttpMethod.Patch, "/me")).Status, Is.EqualTo(HttpStatusCode.OK));
    }

    [TestCase("not json")]
    [TestCase("null")]
    [TestCase("7")]
    public async Task A_body_that_is_not_an_object_or_list_is_a_422_Invalid_JSON_body(string json)
    {
        var reply = await _kit.SendAsync(Token, HttpMethod.Patch, "/me", json);

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.UnprocessableEntity));
        Assert.That(reply.Detail, Is.EqualTo("Invalid JSON body"));
    }

    [TestCase("{\"name\":\"\"}", "Name cannot be empty")]
    [TestCase("{\"name\":\"a\"}", "Must be at least 2 characters")]
    [TestCase("{\"city\":\"  \"}", "City cannot be empty")]
    [TestCase("{\"name\":\"a\\tb\"}", "Contains invalid characters")]
    [TestCase("{\"gender\":3}", "Invalid gender value. Use 1 for Male, 2 for Female.")]
    [TestCase("{\"language\":4}", "Invalid language value. Use 1 for English, 2 for Urdu, 3 for Gujarati.")]
    [TestCase("{\"mobile\":\"123\"}", "Invalid mobile number")]
    [TestCase("{\"zip\":\"ab\"}", "Invalid ZIP code")]
    [TestCase("{\"name\":\"\",\"gender\":3,\"zip\":\"ab\"}", "Name cannot be empty")]
    [TestCase("{\"zip\":\"ab\",\"mobile\":\"1\",\"gender\":3}", "Invalid gender value. Use 1 for Male, 2 for Female.")]
    public async Task The_first_invalid_field_in_PHPs_order_is_a_422_and_nothing_is_written(string json, string detail)
    {
        var reply = await _kit.SendAsync(Token, HttpMethod.Patch, "/me", json);

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.UnprocessableEntity));
        Assert.That(reply.Detail, Is.EqualTo(detail));
        Assert.That(await MembershipTestKit.CountAsync("membership.member_profiles", "name = 'Synthetic Member' and gender = '1' and mobile = ''"), Is.EqualTo(1));
    }

    [Test]
    public async Task A_null_value_is_not_validated_and_clears_the_column_where_it_may()
    {
        await TestDatabase.ExecuteAsync($"update membership.member_profiles set city = 'Bern', gender = '1' where user_id = {_userId}");

        var reply = await _kit.SendAsync(Token, HttpMethod.Patch, "/me", "{\"city\":null,\"gender\":null,\"age_range\":null}");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(reply.Json!["city"], Is.Null);
        Assert.That(reply.Json!["gender"], Is.Null);
        Assert.That(await MembershipTestKit.CountAsync("membership.member_profiles", "city is null and gender is null"), Is.EqualTo(1));
    }

    [Test]
    public async Task A_null_mobile_passes_validation_then_the_not_null_column_refuses_it_a_500_as_in_PHP_and_nothing_is_saved()
    {
        var reply = await _kit.SendAsync(Token, HttpMethod.Patch, "/me", "{\"name\":\"Changed Name\",\"mobile\":null}");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.InternalServerError));
        Assert.That(await MembershipTestKit.CountAsync("membership.member_profiles", "name = 'Synthetic Member'"), Is.EqualTo(1));
    }

    // ---- PATCH /me: storing

    [Test]
    public async Task A_valid_update_stores_the_values_as_sent_untrimmed_and_answers_with_the_new_profile()
    {
        var reply = await _kit.SendAsync(
            Token,
            HttpMethod.Patch,
            "/me",
            "{\"name\":\"  Ab Cd  \",\"mobile\":\"+911234567890\",\"age_range\":5,\"language\":2,\"zip\":\"\",\"country\":\"Nowhere\",\"state\":\"Ab\",\"city\":\"  Bern  \"}");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(reply.Json!["name"]!.GetValue<string>(), Is.EqualTo("  Ab Cd  "));
        Assert.That(reply.Json!["city"]!.GetValue<string>(), Is.EqualTo("  Bern  "));
        Assert.That(reply.Json!["mobile"]!.GetValue<string>(), Is.EqualTo("+911234567890"));
        Assert.That(reply.Json!["age_range"]!.GetValue<int>(), Is.EqualTo(5));
        Assert.That(reply.Json!["language"]!.GetValue<int>(), Is.EqualTo(2));
        Assert.That(reply.Json!["zip"], Is.Null);
        var row = (await TestDatabase.RowAsync($"select name, age_range, zip from membership.member_profiles where user_id = {_userId}"))!;
        Assert.That(row["name"], Is.EqualTo("  Ab Cd  "));
        Assert.That(row["age_range"], Is.EqualTo("5"));
        Assert.That(row["zip"], Is.EqualTo(string.Empty));
    }

    [Test]
    public async Task A_member_with_no_profile_row_gets_one_on_their_first_write()
    {
        await TestDatabase.ExecuteAsync($"delete from membership.member_profiles where user_id = {_userId}");

        var reply = await _kit.SendAsync(Token, HttpMethod.Patch, "/me", "{\"name\":\"First Write\"}");

        Assert.That(reply.Json!["name"]!.GetValue<string>(), Is.EqualTo("First Write"));
        Assert.That(await MembershipTestKit.CountAsync("membership.member_profiles", $"user_id = {_userId}"), Is.EqualTo(1));
    }

    [Test]
    public async Task A_name_with_entities_is_stored_raw_and_answered_decoded()
    {
        var reply = await _kit.SendAsync(Token, HttpMethod.Patch, "/me", "{\"name\":\"O&#039;Neil &amp; Co\"}");

        Assert.That(reply.Json!["name"]!.GetValue<string>(), Is.EqualTo("O'Neil & Co"));
        Assert.That(await MembershipTestKit.CountAsync("membership.member_profiles", "name = 'O&#039;Neil &amp; Co'"), Is.EqualTo(1));
    }

    [Test]
    public async Task PDO_style_casts_apply_a_numeric_string_gender_a_float_and_a_boolean_are_stored_as_text_and_read_back_as_ints_or_null()
    {
        Assert.That((await _kit.SendAsync(Token, HttpMethod.Patch, "/me", "{\"gender\":\"2\"}")).Json!["gender"]!.GetValue<int>(), Is.EqualTo(2));
        Assert.That((await _kit.SendAsync(Token, HttpMethod.Patch, "/me", "{\"gender\":1.9}")).Json!["gender"]!.GetValue<int>(), Is.EqualTo(1));
        Assert.That((await _kit.SendAsync(Token, HttpMethod.Patch, "/me", "{\"gender\":true}")).Json!["gender"]!.GetValue<int>(), Is.EqualTo(1));
        var odd = await _kit.SendAsync(Token, HttpMethod.Patch, "/me", "{\"gender\":\"1abc\"}");
        Assert.That(odd.Status, Is.EqualTo(HttpStatusCode.OK), "(int)\"1abc\" is 1, so it validates");
        Assert.That(odd.Json!["gender"], Is.Null, "and reads back as null");
        Assert.That(await MembershipTestKit.CountAsync("membership.member_profiles", "gender = '1abc'"), Is.EqualTo(1));
    }

    [Test]
    public async Task A_decimal_language_is_rounded_by_the_database_and_text_that_is_not_a_number_is_a_500()
    {
        Assert.That((await _kit.SendAsync(Token, HttpMethod.Patch, "/me", "{\"language\":2.5}")).Json!["language"]!.GetValue<int>(), Is.EqualTo(3));
        Assert.That((await _kit.SendAsync(Token, HttpMethod.Patch, "/me", "{\"language\":\" 2\"}")).Json!["language"]!.GetValue<int>(), Is.EqualTo(2));
        Assert.That((await _kit.SendAsync(Token, HttpMethod.Patch, "/me", "{\"language\":\"2abc\"}")).Status, Is.EqualTo(HttpStatusCode.InternalServerError));
    }

    // ---- PATCH /me: the place

    [Test]
    public async Task A_state_or_city_with_a_digit_is_refused_but_only_when_it_changed()
    {
        Assert.That((await _kit.SendAsync(Token, HttpMethod.Patch, "/me", "{\"state\":\"ab3\"}")).Detail, Is.EqualTo("State cannot contain numbers"));
        Assert.That((await _kit.SendAsync(Token, HttpMethod.Patch, "/me", "{\"city\":\"Zurich1\"}")).Detail, Is.EqualTo("City cannot contain numbers"));
        Assert.That((await _kit.SendAsync(Token, HttpMethod.Patch, "/me", "{\"city\":\"\\u0663x\"}")).Detail, Is.EqualTo("City cannot contain numbers"), "any Unicode digit");

        await TestDatabase.ExecuteAsync($"update membership.member_profiles set city = 'Old Town 2' where user_id = {_userId}");
        var unchanged = await _kit.SendAsync(Token, HttpMethod.Patch, "/me", "{\"city\":\" Old Town 2 \",\"name\":\"Same Again\"}");
        Assert.That(unchanged.Status, Is.EqualTo(HttpStatusCode.OK), "a value saved long ago keeps saving (compared trimmed)");
    }

    [Test]
    public async Task A_country_must_be_from_the_list_when_the_list_is_loaded_and_anything_goes_when_it_is_not()
    {
        var refused = await _kit.SendAsync(Token, HttpMethod.Patch, "/me", "{\"country\":\"Narnia\"}");

        Assert.That(refused.Status, Is.EqualTo(HttpStatusCode.UnprocessableEntity));
        Assert.That(refused.Detail, Is.EqualTo("Choose your country from the list"));
        Assert.That((await _kit.SendAsync(Token, HttpMethod.Patch, "/me", "{\"country\":\" switzerland \"}")).Status, Is.EqualTo(HttpStatusCode.OK), "case and edges do not matter");

        await TestDatabase.ExecuteAsync("truncate platform.geo_postal_codes, platform.geo_countries");
        Assert.That((await _kit.SendAsync(Token, HttpMethod.Patch, "/me", "{\"country\":\"Narnia\"}")).Status, Is.EqualTo(HttpStatusCode.OK));
    }

    [Test]
    public async Task A_zip_that_looks_like_an_email_or_a_phone_number_is_refused_unless_the_country_vouches_for_it()
    {
        Assert.That((await _kit.SendAsync(Token, HttpMethod.Patch, "/me", "{\"zip\":\"0123456789\"}")).Detail, Is.EqualTo("That does not look like a postal code. Leave it empty if you do not have one."));
        Assert.That((await _kit.SendAsync(Token, HttpMethod.Patch, "/me", "{\"country\":\"Iran\",\"zip\":\"1234567890\"}")).Status, Is.EqualTo(HttpStatusCode.OK), "Iran's own regex");
        Assert.That((await _kit.SendAsync(Token, HttpMethod.Patch, "/me", "{\"country\":\"Iran\",\"zip\":\"12345678901\"}")).Detail, Is.EqualTo("That does not look like a postal code. Leave it empty if you do not have one."));
    }

    [Test]
    public async Task A_new_postal_code_we_hold_overwrites_state_and_city_whatever_was_sent()
    {
        var reply = await _kit.SendAsync(Token, HttpMethod.Patch, "/me", "{\"country\":\"Switzerland\",\"zip\":\"8001\",\"city\":\"Typed City\",\"state\":\"Typed State\"}");

        Assert.That(reply.Json!["state"]!.GetValue<string>(), Is.EqualTo("Zürich"));
        Assert.That(reply.Json!["city"]!.GetValue<string>(), Is.EqualTo("Zürich"));
        Assert.That(reply.Json!["zip"]!.GetValue<string>(), Is.EqualTo("8001"));
    }

    [Test]
    public async Task A_postal_code_with_no_change_leaves_the_typed_state_and_city_and_an_empty_postal_city_is_not_used()
    {
        await _kit.SendAsync(Token, HttpMethod.Patch, "/me", "{\"country\":\"Switzerland\",\"zip\":\"8001\"}");

        var same = await _kit.SendAsync(Token, HttpMethod.Patch, "/me", "{\"country\":\"Switzerland\",\"zip\":\"8001\",\"city\":\"Typed City\"}");
        var zero = await _kit.SendAsync(Token, HttpMethod.Patch, "/me", "{\"zip\":\"3011\",\"city\":\"Typed City\"}");

        Assert.That(same.Json!["city"]!.GetValue<string>(), Is.EqualTo("Typed City"), "nothing changed, so nothing is overwritten");
        Assert.That(zero.Json!["state"]!.GetValue<string>(), Is.EqualTo("Bern"), "the new code overwrites state");
        Assert.That(zero.Json!["city"]!.GetValue<string>(), Is.EqualTo("Typed City"), "PHP's empty() treats the city \"0\" as nothing");
    }

    // ---- PATCH /me: the gender lock

    [Test]
    public async Task A_member_enrolled_in_a_class_cannot_change_gender_but_can_repeat_it()
    {
        using var enrolled = Enrolled();

        var refused = await enrolled.SendAsync(Token, HttpMethod.Patch, "/me", "{\"gender\":2}");
        var same = await enrolled.SendAsync(Token, HttpMethod.Patch, "/me", "{\"gender\":1}");
        var cleared = await enrolled.SendAsync(Token, HttpMethod.Patch, "/me", "{\"gender\":null}");

        Assert.That(refused.Status, Is.EqualTo(HttpStatusCode.UnprocessableEntity));
        Assert.That(refused.Detail, Is.EqualTo("Gender cannot be changed while you are enrolled in a class"));
        Assert.That(same.Status, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(cleared.Status, Is.EqualTo(HttpStatusCode.UnprocessableEntity), "null counts as 0, a change");
        Assert.That(await MembershipTestKit.CountAsync("membership.member_profiles", "gender = '1'"), Is.EqualTo(1));
    }

    [Test]
    public async Task A_member_whose_gender_is_not_set_may_set_it_even_when_enrolled()
    {
        using var enrolled = Enrolled();
        await TestDatabase.ExecuteAsync($"update membership.member_profiles set gender = 'Male' where user_id = {_userId}");

        var reply = await enrolled.SendAsync(Token, HttpMethod.Patch, "/me", "{\"gender\":2}");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), "the stored 'Male' reads as 0, not 1 or 2, so nothing is locked");
    }

    [Test]
    public async Task Without_classes_nobody_is_enrolled_so_the_gender_changes()
    {
        var reply = await _kit.SendAsync(Token, HttpMethod.Patch, "/me", "{\"gender\":2}");

        Assert.That(reply.Json!["gender"]!.GetValue<int>(), Is.EqualTo(2));
    }

    private static EnrolledKit Enrolled() => new();

    /// <summary>The API with a classes port that says every member is enrolled.</summary>
    private sealed class EnrolledKit : IDisposable
    {
        private readonly WebApplicationFactory<Program> _factory = TestApi.Create().WithWebHostBuilder(
            builder => builder.ConfigureTestServices(services => services.AddScoped<IClassEnrolments, AlwaysEnrolled>()));

        public async Task<MembershipTestKit.Reply> SendAsync(int token, HttpMethod method, string path, string json)
        {
            using var client = _factory.CreateClient();
            using var request = new HttpRequestMessage(method, path)
            {
                Content = new StringContent(json, System.Text.Encoding.UTF8, "application/json"),
            };
            foreach (var (name, value) in TestApi.SignedInAs("uid-" + token, MembershipTestKit.EmailOf(token)))
            {
                request.Headers.Add(name, value);
            }

            using var response = await client.SendAsync(request);
            return new MembershipTestKit.Reply(response.StatusCode, await response.Content.ReadAsStringAsync());
        }

        public void Dispose() => _factory.Dispose();
    }

    private sealed class AlwaysEnrolled : IClassEnrolments
    {
        public Task<bool> IsEnrolledAsync(int token, CancellationToken ct) => Task.FromResult(true);
    }
}
