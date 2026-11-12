using System.Text.Json;
using NUnit.Framework;

namespace Tsr.Notifications.Api.Domain;

public sealed class AudienceWordsTests
{
    private static readonly AudienceNames Names = new(new() { [2] = "Bilal" }, new() { [7] = "AYD1 Evening class" }, new() { [900001] = "Tess Teacher" });

    private static AudienceDescription Describe(string json) => AudienceWords.Describe(JsonElement.Parse(json), Names);

    [Test]
    public void Levels_are_named_and_a_missing_one_says_removed()
    {
        var d = Describe("""{"type":"CLASS_LEVEL","value":[2,9]}""");
        Assert.That(d.Summary, Is.EqualTo("Students of class levels"));
        Assert.That(string.Join("|", d.Items), Is.EqualTo("Bilal|Level 9 (removed)"));
    }

    [Test]
    public void A_class_notification_names_its_class_by_class_id()
    {
        var d = Describe("""{"type":"CLASS","class_id":7}""");
        Assert.That((d.Summary, d.Items[0]), Is.EqualTo(("Students of a class", "AYD1 Evening class")));
    }

    [TestCase("""{"type":"GENDER","value":[1]}""", "Gents")]
    [TestCase("""{"type":"GENDER","value":["2"]}""", "Ladies")]
    [TestCase("""{"type":"GENDER","value":[]}""", "One gender")]
    [TestCase("""{"type":"ALL_USERS","value":null}""", "All users")]
    [TestCase("""{"type":"SOMETHING"}""", "SOMETHING")]
    [TestCase("""{}""", "Unknown")]
    public void The_summary_is_PHPs_words(string json, string summary) =>
        Assert.That(Describe(json).Summary, Is.EqualTo(summary));

    [Test]
    public void A_reminder_names_its_teacher_or_the_token()
    {
        Assert.That(Describe("""{"type":"CC_NUDGE","teacher":900001}""").Items[0], Is.EqualTo("Tess Teacher"));
        Assert.That(Describe("""{"type":"CC_NUDGE","teacher":5}""").Items[0], Is.EqualTo("Teacher 5"));
    }

    [Test]
    public void No_criteria_at_all_is_unknown() =>
        Assert.That(AudienceWords.Describe(null, Names).Summary, Is.EqualTo("Unknown"));
}
