using NUnit.Framework;
using Tsr.Shared.Api;

namespace Tsr.Notifications.Api.Domain;

public sealed class ScheduleInputTests
{
    private static readonly DateTimeOffset Now = new(2026, 11, 12, 10, 0, 0, TimeSpan.Zero);
    private static readonly Dictionary<int, string> Slots = new() { [7] = "UTC" };

    private static JsonBody Body(string json) => JsonBody.Parse(System.Text.Encoding.UTF8.GetBytes(json)).Value!;

    [TestCase("""{"kind":"once"}""", "ONCE")]
    [TestCase("""{"kind":" weekly "}""", "WEEKLY")]
    [TestCase("""{"kind":"daily"}""", null)]
    [TestCase("""{}""", null)]
    public void The_kind_is_trimmed_and_upper_cased(string json, string? expected) =>
        Assert.That(ScheduleInput.Kind(Body(json)), Is.EqualTo(expected));

    [Test]
    public void A_missing_zone_is_refused_first() =>
        Assert.That(ScheduleInput.Parse(Body("""{"send_at":"2030-01-01T10:00"}"""), "ONCE", Now, Slots).Error, Is.EqualTo(ScheduleInput.ZoneError));

    [Test]
    public void A_once_in_the_past_is_refused() =>
        Assert.That(ScheduleInput.Parse(Body("""{"timezone":"UTC","send_at":"2026-11-12T09:59"}"""), "ONCE", Now, Slots).Error, Is.EqualTo("send_at must be in the future"));

    [Test]
    public void A_once_with_an_offset_or_a_bad_date_is_refused()
    {
        Assert.That(ScheduleInput.Parse(Body("""{"timezone":"UTC","send_at":"2030-01-01T10:00:00Z"}"""), "ONCE", Now, Slots).IsSuccess, Is.False);
        Assert.That(ScheduleInput.Parse(Body("""{"timezone":"UTC","send_at":"2030-02-30T10:00"}"""), "ONCE", Now, Slots).IsSuccess, Is.False);
    }

    [Test]
    public void A_once_keeps_its_wall_clock_and_the_old_zone_spelling_is_mapped()
    {
        var draft = ScheduleInput.Parse(Body("""{"timezone":"Asia/Calcutta","send_at":"2030-01-01 10:00"}"""), "ONCE", Now, Slots).Value!;
        Assert.That(draft.Tz, Is.EqualTo("Asia/Kolkata"));
        Assert.That(draft.SendAt, Is.EqualTo(new DateTime(2030, 1, 1, 10, 0, 0)));
    }

    [Test]
    public void Weekly_days_are_sorted_and_unique()
    {
        var draft = ScheduleInput.Parse(Body("""{"timezone":"UTC","weekdays":[5,1,5],"send_time":"18:30"}"""), "WEEKLY", Now, Slots).Value!;
        Assert.That(draft.Weekdays, Is.EqualTo("1,5"));
        Assert.That(draft.SendTime, Is.EqualTo(new TimeOnly(18, 30)));
    }

    [TestCase("""{"timezone":"UTC","weekdays":[],"send_time":"18:30"}""")]
    [TestCase("""{"timezone":"UTC","weekdays":[8],"send_time":"18:30"}""")]
    [TestCase("""{"timezone":"UTC","weekdays":[1],"send_time":"24:00"}""")]
    public void Bad_weekly_fields_are_refused(string json) =>
        Assert.That(ScheduleInput.Parse(Body(json), "WEEKLY", Now, Slots).IsSuccess, Is.False);

    [Test]
    public void A_reminder_needs_one_of_the_classes_slots_and_an_offset_within_a_week()
    {
        Assert.That(ScheduleInput.Parse(Body("""{"timezone":"UTC","class_schedule_id":9,"offset_minutes":0}"""), "REMINDER", Now, Slots).IsSuccess, Is.False);
        Assert.That(ScheduleInput.Parse(Body("""{"timezone":"UTC","class_schedule_id":7,"offset_minutes":10081}"""), "REMINDER", Now, Slots).IsSuccess, Is.False);
        Assert.That(ScheduleInput.Parse(Body("""{"timezone":"UTC","class_schedule_id":7}"""), "REMINDER", Now, Slots).IsSuccess, Is.False);
        var ok = ScheduleInput.Parse(Body("""{"timezone":"UTC","class_schedule_id":7,"offset_minutes":"-60","repeat_weekly":1}"""), "REMINDER", Now, Slots).Value!;
        Assert.That((ok.OffsetMinutes, ok.RepeatWeekly), Is.EqualTo((-60, true)));
    }
}
