using System.Text.Json;
using NUnit.Framework;

namespace Tsr.Notifications.Api.Domain;

/// <summary>TC-CMD-R9-02: the queued push payload is byte for byte what the reflection serializer wrote for the anonymous object it replaces.</summary>
public sealed class NotificationsJsonTests
{
    // The code before issue 98: web-less defaults, an anonymous object, the data object picked at run time.
    private static string Before(Announcement a) =>
        JsonSerializer.Serialize(new
        {
            title = a.Title,
            body = a.Body,
            data = a.Data is not null ? (object)a.Data : DefaultData(a),
        });

    private static Dictionary<string, string?> DefaultData(Announcement a) => new()
    {
        ["type"] = a.DataType,
        ["action_link"] = a.ActionLink,
        ["title"] = a.Title,
        ["body"] = a.Body,
    };

    private static Announcement Sample(string? link, IReadOnlyDictionary<string, string>? data) =>
        new("Quiz été القرآن <b> & \"q\" 'x' +", "Body 😀 line\nbreak", link, "quiz_announcement", "key", Data: data);

    [Test]
    public void The_default_data_with_a_null_link_gives_the_same_bytes()
    {
        var announcement = Sample(null, null);
        Assert.That(NotificationsCommands.PushPayload(announcement), Is.EqualTo(Before(announcement)));
    }

    [Test]
    public void The_default_data_with_a_link_gives_the_same_bytes()
    {
        var announcement = Sample("/quiz/1", null);
        Assert.That(NotificationsCommands.PushPayload(announcement), Is.EqualTo(Before(announcement)));
    }

    [Test]
    public void The_callers_data_gives_the_same_bytes()
    {
        var announcement = Sample("/quiz/1", new Dictionary<string, string> { ["type"] = "quiz_released", ["quiz_id"] = "7", ["title"] = "T é" });
        Assert.That(NotificationsCommands.PushPayload(announcement), Is.EqualTo(Before(announcement)));
    }

    // A naming policy applied to dictionary keys would change these two.
    [Test]
    public void Data_keys_with_a_capital_or_an_underscore_keep_their_spelling()
    {
        var announcement = Sample("/quiz/1", new Dictionary<string, string> { ["QuizId"] = "7", ["_private"] = "x", ["Action_Link"] = "/y" });
        Assert.That(NotificationsCommands.PushPayload(announcement), Is.EqualTo(Before(announcement)));
    }

    // A null title or body (not allowed by the types, but a caller can pass one) stays in the JSON as null: an ignore-null option would drop the property.
    [Test]
    public void A_null_title_and_body_stay_in_the_json_as_null()
    {
        var announcement = new Announcement(null!, null!, null, "quiz_announcement", "key");
        Assert.That(NotificationsCommands.PushPayload(announcement), Is.EqualTo(Before(announcement)));
    }
}
