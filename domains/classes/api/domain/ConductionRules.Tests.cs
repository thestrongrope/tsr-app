using System.Globalization;
using System.Text;
using System.Text.Json;
using NUnit.Framework;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

[TestFixture]
internal sealed class ConductionRulesTests
{
    private static readonly DateOnly Today = new(2026, 11, 11);

    private static JsonBody Body(string json) => JsonBody.Parse(Encoding.UTF8.GetBytes(json)).Value!;

    private static JsonElement Json(string json) => JsonElement.Parse(json);

    private static string? Iso(DateOnly? day) => day?.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);

    private static DateOnly Day(string text) => DateOnly.ParseExact(text, "yyyy-MM-dd", CultureInfo.InvariantCulture);

    private static readonly bool[] NoneHeld = [false, false, false, false, false];

    private static readonly bool[] OnlyAqaed = [false, true, false, false, false];

    private static readonly string?[] OnlyAqaedTopic = [null, "Wudu", null, null, null];

    private static string? Error(string json) => ConductionRules.Parse(Body(json), Today).Error;

    private const string Held = """{"conductedOn":"2026-11-10","duration":30,"students":[{"token":1,"present":true}],"aqaedConducted":true,"aqaedTopic":"T"}""";

    [TestCase("true", true)]
    [TestCase("false", false)]
    [TestCase("\"1\"", true)]
    [TestCase("\" Yes \"", true)]
    [TestCase("\"on\"", true)]
    [TestCase("\"TRUE\"", true)]
    [TestCase("\"false\"", false)]
    [TestCase("\"abc\"", false)]
    [TestCase("\"\"", false)]
    [TestCase("1", true)]
    [TestCase("1.0", true)]
    [TestCase("2", false)]
    [TestCase("0", false)]
    [TestCase("[]", false)]
    public void A_flag_is_read_as_PHP_filter_var_boolean(string json, bool expected) =>
        Assert.That(ConductionRules.Truthy(Json(json), whenMissing: !expected), Is.EqualTo(expected));

    [Test]
    public void A_missing_or_null_flag_takes_the_default_because_PHP_uses_the_null_coalescing_operator()
    {
        Assert.That(ConductionRules.Truthy(default, true), Is.True);
        Assert.That(ConductionRules.Truthy(Json("null"), true), Is.True);
        Assert.That(ConductionRules.Truthy(default, false), Is.False);
    }

    [TestCase("2026-11-10", "2026-11-10")]
    [TestCase("2026-1-5", "2026-01-05")]
    [TestCase("2026-11-10 10:30", "2026-11-10")]
    [TestCase("2026-11-10T23:30:00-05:00", "2026-11-11")]
    [TestCase("2026-11-10T10:00:00Z", "2026-11-10")]
    [TestCase("20261110", "2026-11-10")]
    [TestCase("2025-02-30", "2025-03-02")]
    [TestCase("20-09-2025", "2025-09-20")]
    [TestCase("09/20/2025", "2025-09-20")]
    [TestCase("20 September 2025", "2025-09-20")]
    [TestCase("Sat 20 Sep 2025", "2025-09-20")]
    [TestCase("today", "2026-11-11")]
    [TestCase("tomorrow", "2026-11-12")]
    [TestCase("yesterday", "2026-11-10")]
    [TestCase("2025-02-32", null)]
    [TestCase("2025-13-01", null)]
    [TestCase("nonsense", null)]
    [TestCase("", null)]
    public void A_date_is_read_as_PHP_strtotime_for_the_forms_the_app_and_people_use(string text, string? expected) =>
        Assert.That(Iso(ConductionRules.ParseDate(text, Today)), Is.EqualTo(expected));

    [Test]
    public void The_ten_messages_come_in_PHP_order()
    {
        Assert.That(Error("""{}"""), Is.EqualTo("conductedOn is required and must be a valid date"));
        Assert.That(Error("""{"conductedOn":"nope"}"""), Is.EqualTo("conductedOn is required and must be a valid date"));
        Assert.That(Error("""{"conductedOn":"2026-11-10","conducted":false}"""), Is.EqualTo("nonConductionReason is required when the class was not conducted"));
        Assert.That(Error("""{"conductedOn":"2026-11-10"}"""), Is.EqualTo("duration is required for a conducted class"));
        Assert.That(Error("""{"conductedOn":"2026-11-10","duration":0}"""), Is.EqualTo("duration is required for a conducted class"));
        Assert.That(Error("""{"conductedOn":"2026-11-10","duration":5}"""), Is.EqualTo("At least one student must be marked present"));
        Assert.That(Error("""{"conductedOn":"2026-11-10","duration":5,"students":[{"token":1,"present":false}]}"""), Is.EqualTo("At least one student must be marked present"));
        Assert.That(Error("""{"conductedOn":"2026-11-10","duration":5,"students":[{"token":1,"present":true}]}"""), Is.EqualTo("At least one subject must be selected"));
        Assert.That(Error("""{"conductedOn":"2026-11-10","duration":5,"extraStudents":[{"name":"X","present":true}],"akhlaqConducted":true}"""), Is.EqualTo("Topic covered is required for Akhlaq"));
    }

    [TestCase("arabic", "Arabic")]
    [TestCase("aqaed", "Aqaed")]
    [TestCase("ahkam", "Ahkam")]
    [TestCase("akhlaq", "Akhlaq")]
    [TestCase("other", "Other")]
    public void Each_selected_subject_needs_a_topic(string key, string label) =>
        Assert.That(
            Error($$"""{"conductedOn":"2026-11-10","duration":5,"students":[{"token":1,"present":true}],"{{key}}Conducted":true,"{{key}}Topic":"  "}"""),
            Is.EqualTo($"Topic covered is required for {label}"));

    [Test]
    public void An_extra_student_with_a_blank_name_does_not_count_as_present()
    {
        const string json = """{"conductedOn":"2026-11-10","duration":5,"extraStudents":[{"name":"  ","present":true}],"aqaedConducted":true,"aqaedTopic":"T"}""";
        Assert.That(Error(json), Is.EqualTo("At least one student must be marked present"));
    }

    [Test]
    public void A_held_class_keeps_flags_topics_and_trims_the_ones_it_stores()
    {
        var parsed = ConductionRules.Parse(Body("""{"conductedOn":"2026-11-10","duration":"30","students":[{"token":"7","present":"yes","recitation":4},{"token":8,"recitation":9},"x"],"extraStudents":[{"name":" Ann ","token":2,"present":true}],"aqaedConducted":true,"aqaedTopic":" Wudu ","arabicTopic":"ignored","quranRecitationSurah":2}"""), Today).Value!;
        Assert.That(parsed.Conducted, Is.True);
        Assert.That(parsed.Duration, Is.EqualTo(30));
        Assert.That(parsed.Surah, Is.EqualTo(2));
        Assert.That(parsed.Verse, Is.Null);
        Assert.That(parsed.Held, Is.EqualTo(OnlyAqaed));
        Assert.That(parsed.Topics, Is.EqualTo(OnlyAqaedTopic));
        Assert.That(parsed.Students, Is.EqualTo(new[] { new ConductionRules.Student(7, true, 4), new ConductionRules.Student(8, false, 9) }));
        Assert.That(parsed.Extras, Is.EqualTo(new[] { new ConductionRules.Extra(2, "Ann", true) }));
    }

    [Test]
    public void A_class_not_held_stores_the_reason_and_no_flags_and_asks_nothing_else()
    {
        var parsed = ConductionRules.Parse(Body("""{"conductedOn":"2026-11-10","conducted":"no","nonConductionReason":" Rain ","aqaedConducted":true,"aqaedTopic":"T"}"""), Today).Value!;
        Assert.That(parsed.Conducted, Is.False);
        Assert.That(parsed.Reason, Is.EqualTo("Rain"));
        Assert.That(parsed.Held, Is.EqualTo(NoneHeld));
        Assert.That(parsed.Topics, Is.All.Null);
    }

    [Test]
    public void A_held_class_has_no_reason()
    {
        var parsed = ConductionRules.Parse(Body(Held.Replace("\"duration\"", "\"nonConductionReason\":\"x\",\"duration\"")), Today).Value!;
        Assert.That(parsed.Reason, Is.Null);
    }

    [Test]
    public void Limits_and_NUL_are_checked_after_PHP_s_rules_and_only_on_what_is_stored()
    {
        Assert.That(Error("""{"conductedOn":"2026-11-10","conducted":false,"nonConductionReason":"a\u0000b"}"""), Is.EqualTo("nonConductionReason must not contain a NUL byte"));
        Assert.That(Error($$"""{"conductedOn":"2026-11-10","conducted":false,"nonConductionReason":"{{new string('x', 101)}}"}"""), Is.EqualTo("nonConductionReason must be at most 100 characters"));
        Assert.That(Error($$"""{"conductedOn":"2026-11-10","duration":5,"students":[{"token":1,"present":true}],"aqaedConducted":true,"aqaedTopic":"{{new string('x', 1001)}}"}"""), Is.EqualTo("aqaedTopic must be at most 1000 characters"));
        Assert.That(Error("""{"conductedOn":"2026-11-10","duration":5,"students":[{"token":1,"present":true}],"aqaedConducted":true,"aqaedTopic":"T","arabicTopic":"a\u0000b"}"""), Is.Null);
        Assert.That(Error($$"""{"conductedOn":"2026-11-10","duration":5,"students":[{"token":1,"present":true}],"aqaedConducted":true,"aqaedTopic":"T","extraStudents":[{"name":"{{new string('x', 101)}}"}]}"""), Is.EqualTo("extraStudents name must be at most 100 characters"));
        Assert.That(Error("""{"conductedOn":"2026-11-10","duration":5,"students":[{"token":1,"present":true}],"aqaedConducted":true,"aqaedTopic":"T","extraStudents":[{"name":"a\u0000b"}]}"""), Is.EqualTo("extraStudents name must not contain a NUL byte"));
    }

    [Test]
    public void A_number_beyond_what_a_column_holds_is_a_refusal_not_a_server_error()
    {
        Assert.That(Error("""{"conductedOn":"2026-11-10","duration":99999999999,"students":[{"token":1,"present":true}],"aqaedConducted":true,"aqaedTopic":"T"}"""), Is.EqualTo("duration is out of range"));
        Assert.That(Error(Held.Replace("\"present\":true", "\"present\":true,\"recitation\":99999999999")), Is.EqualTo("recitation is out of range"));
        Assert.That(Error(Held.Replace("\"duration\":30", "\"duration\":30,\"quranRecitationVerse\":99999999999")), Is.EqualTo("quranRecitationVerse is out of range"));
    }

    [Test]
    public void A_session_is_editable_for_ten_whole_days_counted_as_PHP_diff_days()
    {
        var now = new DateTimeOffset(2026, 11, 11, 12, 0, 0, TimeSpan.Zero);
        Assert.That(ConductionRules.IsEditable(now.AddDays(-10).AddHours(-23), now), Is.True);
        Assert.That(ConductionRules.IsEditable(now.AddDays(-11), now), Is.False);
        Assert.That(ConductionRules.IsEditable(now.AddDays(11), now), Is.False);
        Assert.That(ConductionRules.IsEditable(now.AddDays(1), now), Is.True);
    }

    [Test]
    public void A_recorded_time_is_clamped_to_now_cut_to_the_second_and_unreadable_text_is_absent()
    {
        var now = new DateTimeOffset(2026, 11, 11, 12, 0, 0, 500, TimeSpan.Zero);
        Assert.That(ConductionRules.RecordedAt("2026-11-10T10:00:00.9Z", now), Is.EqualTo(new DateTimeOffset(2026, 11, 10, 10, 0, 0, TimeSpan.Zero)));
        Assert.That(ConductionRules.RecordedAt("2026-11-10T10:00:00+02:00", now), Is.EqualTo(new DateTimeOffset(2026, 11, 10, 8, 0, 0, TimeSpan.Zero)));
        Assert.That(ConductionRules.RecordedAt("2030-01-01T00:00:00Z", now), Is.EqualTo(new DateTimeOffset(2026, 11, 11, 12, 0, 0, TimeSpan.Zero)));
        Assert.That(ConductionRules.RecordedAt("garbage", now), Is.Null);
        Assert.That(ConductionRules.RecordedAt("  ", now), Is.Null);
        Assert.That(ConductionRules.RecordedAt(null, now), Is.Null);
    }

    [Test]
    public void A_week_runs_Monday_to_Sunday_and_a_Sunday_belongs_to_the_week_before_it()
    {
        Assert.That(ConductionRules.WeekOf(new DateOnly(2025, 10, 19)), Is.EqualTo((new DateOnly(2025, 10, 13), new DateOnly(2025, 10, 19))));
        Assert.That(ConductionRules.WeekOf(new DateOnly(2025, 10, 13)), Is.EqualTo((new DateOnly(2025, 10, 13), new DateOnly(2025, 10, 19))));
        Assert.That(ConductionRules.WeekOf(new DateOnly(2025, 10, 16)), Is.EqualTo((new DateOnly(2025, 10, 13), new DateOnly(2025, 10, 19))));
    }

    // 2025-09-20 is a Saturday (ISO 6), 2025-09-15 a Monday (1).
    [TestCase("2025-09-15", "2,6", "2025-09-16")]
    [TestCase("2025-09-20", "2,6", "2025-09-23")]
    [TestCase("2025-09-20", "6", "2025-09-27")]
    [TestCase("2025-09-15", "1", "2025-09-22")]
    [TestCase("2025-09-15", "", "2025-09-21")]
    [TestCase("2025-09-17", "", "2025-09-21")]
    public void The_next_session_is_the_first_schedule_day_after_the_last_session_else_next_week(string last, string days, string expected)
    {
        var scheduleDays = days.Length == 0 ? [] : days.Split(',').Select(int.Parse).ToList();
        Assert.That(Iso(ConductionRules.NextSessionDate(Day(last), Today, scheduleDays)), Is.EqualTo(expected));
    }

    [Test]
    public void With_no_session_and_no_start_the_search_begins_from_yesterday()
    {
        // 2026-11-10 is a Tuesday (2); day 3 is the next day after it.
        Assert.That(Iso(ConductionRules.NextSessionDate(null, Today, [3])), Is.EqualTo("2026-11-11"));
    }

    [Test]
    public void Extra_students_are_the_names_before_the_first_comma_numbered_in_order_blank_lines_skipped()
    {
        var parsed = ConductionRules.ExtraStudentsOf("Ann, +91 1\r\n\n  \nBob\n , x\nCy, a, b\n");
        Assert.That(parsed, Is.EqualTo(new[] { (1, "Ann"), (2, "Bob"), (3, "Cy") }));
        Assert.That(ConductionRules.ExtraStudentsOf(null), Is.Empty);
        Assert.That(ConductionRules.ExtraStudentsOf("  \n"), Is.Empty);
    }

    [Test]
    public void The_week_of_the_last_days_the_calendar_holds_ends_on_the_last_day()
    {
        // 9999-12-31 is a Friday: its Sunday does not exist. A caller can send that date, so it must not throw.
        Assert.That(ConductionRules.WeekOf(new DateOnly(9999, 12, 31)), Is.EqualTo((new DateOnly(9999, 12, 27), DateOnly.MaxValue)));
    }
}
