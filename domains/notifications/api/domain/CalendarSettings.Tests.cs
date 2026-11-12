using System.Text.Json;
using NUnit.Framework;

namespace Tsr.Notifications.Api.Domain;

public sealed class CalendarSettingsTests
{
    private static readonly DateTimeOffset Now = new(2026, 11, 12, 10, 0, 0, TimeSpan.Zero);

    private static JsonElement Json(string json) => JsonElement.Parse(json);

    [TestCase("\"abcdefghijklmnop\"", true)]
    [TestCase("\"abcdefghijklmno\"", false)]
    [TestCase("\"ABC_def-0123456789\"", true)]
    [TestCase("\"abcdefghijklmnop!\"", false)]
    [TestCase("\"abcdefghijklmnop\\n\"", false)]
    [TestCase("1234567890123456", false)]
    [TestCase("null", false)]
    public void A_device_key_is_16_to_64_letters_digits_underscores_or_hyphens(string json, bool expected) =>
        Assert.That(CalendarSettings.IsDeviceKey(Json(json)), Is.EqualTo(expected));

    [Test]
    public void A_device_key_of_64_characters_passes_and_65_does_not()
    {
        Assert.That(CalendarSettings.IsDeviceKey(Json("\"" + new string('k', 64) + "\"")), Is.True);
        Assert.That(CalendarSettings.IsDeviceKey(Json("\"" + new string('k', 65) + "\"")), Is.False);
    }

    [Test]
    public void An_event_key_names_an_event_or_a_slot_by_id()
    {
        Assert.That(CalendarSettings.Key(Json("""{"event_key":"event:12"}""")).Value, Is.EqualTo(new EventKey("event:12", true, 12)));
        Assert.That(CalendarSettings.Key(Json("""{"event_key":"slot:9999999999"}""")).Value, Is.EqualTo(new EventKey("slot:9999999999", false, 9999999999)));
    }

    [TestCase("""{}""", "Invalid event_key")]
    [TestCase("""[]""", "Invalid event_key")]
    [TestCase("""{"event_key":null}""", "Invalid event_key")]
    [TestCase("""{"event_key":"event:0"}""", "Invalid event_key")]
    [TestCase("""{"event_key":"Event:1"}""", "Invalid event_key")]
    [TestCase("""{"event_key":"event:12345678901"}""", "Invalid event_key")]
    [TestCase("""{"event_key":"event:1\n"}""", "Invalid event_key")]
    [TestCase("""{"event_key":12}""", "event_key must be a string")]
    public void A_bad_event_key_is_refused(string json, string error) =>
        Assert.That(CalendarSettings.Key(Json(json)).Error, Is.EqualTo(error));

    [Test]
    public void A_change_carries_its_offset_switches_and_client_time()
    {
        var change = CalendarSettings.Change(Json("""{"offset_minutes":-15,"muted":true,"deleted":false,"client_updated_at":"2026-11-12T09:59:58.5Z"}""")).Value!;
        Assert.That(change, Is.EqualTo(new SettingChange(-15, true, false, new DateTimeOffset(2026, 11, 12, 9, 59, 58, 500, TimeSpan.Zero))));
        Assert.That(CalendarSettings.Change(Json("""{"muted":false,"deleted":true,"client_updated_at":"2026-11-12T09:59:58Z"}""")).Value!.OffsetMinutes, Is.Null);
    }

    [TestCase("""{"offset_minutes":-7,"muted":true,"deleted":false,"client_updated_at":"2026-11-12T09:00:00Z"}""", "Choose a supported alert offset")]
    [TestCase("""{"offset_minutes":-5.0,"muted":true,"deleted":false,"client_updated_at":"2026-11-12T09:00:00Z"}""", "Choose a supported alert offset")]
    [TestCase("""{"offset_minutes":"-5","muted":true,"deleted":false,"client_updated_at":"2026-11-12T09:00:00Z"}""", "Choose a supported alert offset")]
    [TestCase("""{"muted":1,"deleted":false,"client_updated_at":"2026-11-12T09:00:00Z"}""", "muted and deleted must be booleans")]
    [TestCase("""{"muted":true,"client_updated_at":"2026-11-12T09:00:00Z"}""", "muted and deleted must be booleans")]
    [TestCase("""{"muted":true,"deleted":false}""", "client_updated_at must be an ISO UTC timestamp")]
    [TestCase("""{"muted":true,"deleted":false,"client_updated_at":"2026-11-12T09:00:00+00:00"}""", "client_updated_at must be an ISO UTC timestamp")]
    [TestCase("""{"muted":true,"deleted":false,"client_updated_at":"2026-11-12T09:00:00.1234Z"}""", "client_updated_at must be an ISO UTC timestamp")]
    [TestCase("""{"muted":true,"deleted":false,"client_updated_at":"2026-02-31T09:00:00Z"}""", "Invalid client_updated_at")]
    [TestCase("""{"muted":true,"deleted":false,"client_updated_at":"2026-11-12T24:00:00Z"}""", "Invalid client_updated_at")]
    public void A_bad_change_is_refused_offset_first_then_the_switches_then_the_time(string json, string error) =>
        Assert.That(CalendarSettings.Change(Json(json)).Error, Is.EqualTo(error));

    [TestCase(0)]
    [TestCase(-5)]
    [TestCase(-15)]
    [TestCase(-30)]
    [TestCase(-60)]
    [TestCase(-1440)]
    [TestCase(-2880)]
    public void The_supported_offsets_pass(int offset) =>
        Assert.That(CalendarSettings.Change(Json($$"""{"offset_minutes":{{offset}},"muted":true,"deleted":false,"client_updated_at":"2026-11-12T09:00:00Z"}""")).IsSuccess, Is.True);

    [Test]
    public void A_client_time_more_than_five_minutes_ahead_is_replaced_by_the_servers_and_flagged()
    {
        Assert.That(CalendarSettings.Stamp(Now.AddMinutes(5), Now), Is.EqualTo((Now.AddMinutes(5), false)));
        Assert.That(CalendarSettings.Stamp(Now.AddMinutes(5).AddMilliseconds(1), Now), Is.EqualTo((Now, true)));
        Assert.That(CalendarSettings.Stamp(Now.AddYears(-3), Now), Is.EqualTo((Now.AddYears(-3), false)));
    }

    [Test]
    public void A_stamp_is_cut_to_whole_milliseconds()
    {
        var late = Now.AddTicks(12_345_678);
        Assert.That(CalendarSettings.Stamp(Now.AddDays(1), late).Stamp, Is.EqualTo(Now.AddMilliseconds(1234)));
    }

    [Test]
    public void The_last_writer_wins_and_a_tie_goes_to_the_greater_device_key()
    {
        Assert.That(CalendarSettings.Loses(Now.AddMilliseconds(-1), "zzzzzzzzzzzzzzzz", Now, "aaaaaaaaaaaaaaaa"), Is.True, "older loses whatever the device");
        Assert.That(CalendarSettings.Loses(Now.AddMilliseconds(1), "aaaaaaaaaaaaaaaa", Now, "zzzzzzzzzzzzzzzz"), Is.False, "newer wins whatever the device");
        Assert.That(CalendarSettings.Loses(Now, "aaaaaaaaaaaaaaaa", Now, "aaaaaaaaaaaaaaaa"), Is.True, "the same change again writes nothing");
        Assert.That(CalendarSettings.Loses(Now, "aaaaaaaaaaaaaaaa", Now, "bbbbbbbbbbbbbbbb"), Is.True);
        Assert.That(CalendarSettings.Loses(Now, "bbbbbbbbbbbbbbbb", Now, "aaaaaaaaaaaaaaaa"), Is.False);
        Assert.That(CalendarSettings.Loses(Now, "Bbbbbbbbbbbbbbbb", Now, "aaaaaaaaaaaaaaaa"), Is.True, "bytes are compared, as strcmp: B sorts before a");
    }

    [Test]
    public void The_wire_time_has_milliseconds_and_a_Z() =>
        Assert.That(CalendarSettings.Iso(new DateTimeOffset(2026, 11, 12, 9, 5, 7, 40, TimeSpan.Zero)), Is.EqualTo("2026-11-12T09:05:07.040Z"));
}
