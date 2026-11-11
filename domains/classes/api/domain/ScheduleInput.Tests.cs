using System.Text.Json;
using NUnit.Framework;

namespace Tsr.Classes.Api.Domain;

[TestFixture]
internal sealed class ScheduleInputTests
{
    private static JsonElement Json(string text) => JsonElement.Parse(text);

    private const string SlotsMessage = "schedules must be a list of at most 21 entries";
    private const string FieldsMessage = "each schedule needs a day (1-7), hour (0-23), minute (0-59) and timezone";

    [TestCase("null", SlotsMessage)]
    [TestCase("\"weekly\"", SlotsMessage)]
    [TestCase("[\"monday\"]", FieldsMessage)]
    [TestCase("[{\"day\":0,\"hour\":1,\"minute\":1,\"timezone\":\"Asia/Kolkata\"}]", FieldsMessage)]
    [TestCase("[{\"day\":8,\"hour\":1,\"minute\":1,\"timezone\":\"Asia/Kolkata\"}]", FieldsMessage)]
    [TestCase("[{\"day\":1.0,\"hour\":1,\"minute\":1,\"timezone\":\"Asia/Kolkata\"}]", FieldsMessage)]
    [TestCase("[{\"day\":\"1\",\"hour\":1,\"minute\":1,\"timezone\":\"Asia/Kolkata\"}]", FieldsMessage)]
    [TestCase("[{\"day\":1,\"hour\":24,\"minute\":1,\"timezone\":\"Asia/Kolkata\"}]", FieldsMessage)]
    [TestCase("[{\"day\":1,\"hour\":1,\"minute\":60,\"timezone\":\"Asia/Kolkata\"}]", FieldsMessage)]
    [TestCase("[{\"day\":1,\"hour\":1,\"minute\":1}]", FieldsMessage)]
    [TestCase("[{\"day\":1,\"hour\":1,\"minute\":1,\"timezone\":\"Mars/Base\"}]", "timezone is not one of the supported timezones")]
    public void A_bad_schedule_list_is_refused_with_PHPs_message(string schedules, string message)
    {
        var result = ScheduleInput.Parse(Json(schedules), topicIds: null);

        Assert.That(result.IsSuccess, Is.False);
        Assert.That(result.Error, Is.EqualTo(message));
    }

    [Test]
    public void More_than_21_slots_are_refused()
    {
        var slot = "{\"day\":1,\"hour\":1,\"minute\":1,\"timezone\":\"Asia/Kolkata\"}";
        var result = ScheduleInput.Parse(Json("[" + string.Join(',', Enumerable.Repeat(slot, 22)) + "]"), topicIds: null);

        Assert.That(result.Error, Is.EqualTo(SlotsMessage));
    }

    [Test]
    public void Calcutta_is_read_as_Kolkata_and_topics_are_checked_only_when_asked_for()
    {
        var text = "[{\"day\":1,\"hour\":1,\"minute\":1,\"timezone\":\"Asia/Calcutta\",\"topics\":[{\"topicId\":7}]}]";

        var ignored = ScheduleInput.Parse(Json(text), topicIds: null);
        var checkedTopics = ScheduleInput.Parse(Json(text), new HashSet<int> { 8 });
        var known = ScheduleInput.Parse(Json(text), new HashSet<int> { 7 });

        Assert.That(ignored.Value![0].Timezone, Is.EqualTo("Asia/Kolkata"));
        Assert.That(checkedTopics.Error, Is.EqualTo("each topic needs a topicId from the topics list"));
        Assert.That(known.Value![0].Topics[0].TopicId, Is.EqualTo(7));
    }
}
