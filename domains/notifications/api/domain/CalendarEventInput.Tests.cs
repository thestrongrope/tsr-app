using NUnit.Framework;
using Tsr.Shared.Api;

namespace Tsr.Notifications.Api.Domain;

public sealed class CalendarEventInputTests
{
    private const string Valid = """{"message":" Read the lesson ","description":"Chapter two","weekdays":[3,1,3],"send_time":"18:30","action_link":"https://www.thestrongrope.com/articles/abc"}""";

    private static Result<CalendarEventValues> Parse(string json) =>
        CalendarEventInput.Parse(JsonBody.Parse(System.Text.Encoding.UTF8.GetBytes(json)).Value!.Get);

    private static System.Text.Json.JsonElement Json(string json) => System.Text.Json.JsonElement.Parse(json);

    [Test]
    public void A_valid_event_is_trimmed_its_weekdays_sorted_without_repeats_and_its_link_made_an_in_app_path()
    {
        var values = Parse(Valid).Value!;
        Assert.That(values, Is.EqualTo(new CalendarEventValues("Read the lesson", "Chapter two", "/articles/abc", "1,3", new TimeOnly(18, 30))));
    }

    [TestCase("""{}""")]
    [TestCase("""{"message":null}""")]
    [TestCase("""{"message":"   "}""")]
    [TestCase("""{"message":7}""")]
    public void A_missing_blank_or_non_text_message_is_refused_first(string json) =>
        Assert.That(Parse(json).Error, Is.EqualTo("Message is required and must be at most 500 characters"));

    [Test]
    public void A_message_of_500_characters_passes_and_501_is_refused()
    {
        Assert.That(Parse($$"""{"message":"{{new string('m', 500)}}","weekdays":[1],"send_time":"00:00"}""").IsSuccess, Is.True);
        Assert.That(Parse($$"""{"message":"{{new string('m', 501)}}","weekdays":[1],"send_time":"00:00"}""").Error, Is.EqualTo(CalendarEventInput.MessageError));
    }

    [Test]
    public void A_description_is_optional_kept_untrimmed_and_at_most_2000_characters()
    {
        Assert.That(Parse("""{"message":"m","weekdays":[1],"send_time":"00:00"}""").Value!.Description, Is.Null);
        Assert.That(Parse("""{"message":"m","description":" d ","weekdays":[1],"send_time":"00:00"}""").Value!.Description, Is.EqualTo(" d "));
        Assert.That(Parse($$"""{"message":"m","description":"{{new string('d', 2001)}}"}""").Error, Is.EqualTo("Description must be at most 2000 characters"));
        Assert.That(Parse("""{"message":"m","description":5}""").Error, Is.EqualTo(CalendarEventInput.DescriptionError));
    }

    [TestCase("24:00")]
    [TestCase("9:00")]
    [TestCase("09:60")]
    [TestCase("09:00:00")]
    [TestCase("09:00\\n")]
    public void A_time_that_is_not_HH_MM_is_refused_before_the_link_and_the_weekdays(string time) =>
        Assert.That(Parse($$"""{"message":"m","send_time":"{{time}}","action_link":"ftp://x.invalid"}""").Error, Is.EqualTo("Time must be HH:MM"));

    [Test]
    public void The_link_follows_the_class_notification_rule_and_is_checked_before_the_weekdays()
    {
        Assert.That(Parse("""{"message":"m","send_time":"09:00","action_link":"ftp://x.invalid"}""").Error, Is.EqualTo(ClassMessage.LinkNotAllowedError));
        Assert.That(Parse("""{"message":"m","send_time":"09:00","action_link":7}""").Error, Is.EqualTo(ClassMessage.LinkLengthError));
        Assert.That(Parse("""{"message":"m","send_time":"09:00","action_link":"","weekdays":[1]}""").Value!.ActionLink, Is.Null);
    }

    [TestCase("""null""", CalendarEventInput.ChooseWeekdaysError)]
    [TestCase("""[]""", CalendarEventInput.ChooseWeekdaysError)]
    [TestCase(""" "1,2" """, CalendarEventInput.ChooseWeekdaysError)]
    [TestCase("""[1,1,1,1,1,1,1,1]""", CalendarEventInput.ChooseWeekdaysError)]
    [TestCase("""[0]""", CalendarEventInput.WeekdaysError)]
    [TestCase("""[8]""", CalendarEventInput.WeekdaysError)]
    [TestCase("""["1"]""", CalendarEventInput.WeekdaysError)]
    [TestCase("""[1.0]""", CalendarEventInput.WeekdaysError)]
    public void Weekdays_are_one_to_seven_whole_numbers_from_1_to_7(string weekdays, string error) =>
        Assert.That(Parse($$"""{"message":"m","send_time":"09:00","weekdays":{{weekdays}}}""").Error, Is.EqualTo(error));

    [Test]
    public void The_weekday_texts_are_PHPs() =>
        Assert.That(
            (string[])[CalendarEventInput.ChooseWeekdaysError, CalendarEventInput.WeekdaysError],
            Is.EqualTo((string[])["Choose between one and seven weekdays", "Weekdays must be integers from 1 (Monday) to 7"]));

    [TestCase("\"Asia/Kolkata\"", "Asia/Kolkata")]
    [TestCase("\" Europe/London \"", "Europe/London")]
    [TestCase("\"Asia/Calcutta\"", "Asia/Kolkata")]
    [TestCase("\"Nope/Nowhere\"", null)]
    [TestCase("\"\"", null)]
    [TestCase("5", null)]
    [TestCase("null", null)]
    public void The_zone_is_a_trimmed_IANA_name_and_Calcutta_is_stored_as_Kolkata(string json, string? expected) =>
        Assert.That(CalendarEventInput.Zone(Json(json)), Is.EqualTo(expected));
}
