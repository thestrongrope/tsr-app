using NUnit.Framework;
using Tsr.Shared.Api;

namespace Tsr.Notifications.Api.Domain;

public sealed class AnnouncementRequestTests
{
    private static Result<AnnouncementInput> Parse(string json) =>
        AnnouncementRequest.Parse(JsonBody.Parse(System.Text.Encoding.UTF8.GetBytes(json)).Value!);

    [Test]
    public void A_valid_announcement_keeps_its_text_and_stores_the_criteria_as_type_and_value()
    {
        var result = Parse("""{"title":" Hi ","body":"B","target":{"type":"CLASS_LEVEL","value":[2,"3",null,""]},"action_link":"https://thestrongrope.com/articles/x"}""");
        var a = result.Value!;
        Assert.That(a.Title, Is.EqualTo(" Hi "));
        Assert.That(a.Target.Values, Has.Count.EqualTo(2));
        Assert.That(a.ActionLink, Is.EqualTo("/articles/x"));
        Assert.That(a.CriteriaJson, Is.EqualTo("""{"type":"CLASS_LEVEL","value":[2,"3",null,""]}"""));
    }

    [TestCase("""{"body":"b","target":{"type":"ALL_USERS"}}""", AnnouncementRequest.TitleError)]
    [TestCase("""{"title":"t","body":"","target":{"type":"ALL_USERS"}}""", AnnouncementRequest.BodyError)]
    [TestCase("""{"title":"t","body":"b"}""", AnnouncementRequest.TargetError)]
    [TestCase("""{"title":"t","body":"b","target":{"type":"CLASS"}}""", AnnouncementRequest.TypeError)]
    [TestCase("""{"title":"t","body":"b","target":{"type":"GENDER","value":1}}""", AnnouncementRequest.ValueError)]
    [TestCase("""{"title":"t","body":"b","target":{"type":"ALL_USERS"},"action_link":"/login?x=1"}""", ClassMessage.LinkNotAllowedError)]
    [TestCase("""{"title":"t\u0000","body":"b","target":{"type":"ALL_USERS"}}""", AnnouncementRequest.TitleError)]
    public void A_bad_request_gets_PHPs_words(string json, string error) =>
        Assert.That(Parse(json).Error, Is.EqualTo(error));

    [Test]
    public void The_title_limit_counts_characters_not_UTF16_units()
    {
        var emoji = string.Concat(Enumerable.Repeat("\U0001F600", 255));
        const string Rest = "\",\"body\":\"b\",\"target\":{\"type\":\"ALL_USERS\"}}";
        Assert.That(Parse("{\"title\":\"" + emoji + Rest).IsSuccess, Is.True);
        Assert.That(Parse("{\"title\":\"" + emoji + "x" + Rest).IsSuccess, Is.False);
    }

    [Test]
    public void The_pushed_body_is_cut_to_500_characters_without_splitting_a_pair()
    {
        var cut = PushBatch.CutBody(string.Concat(Enumerable.Repeat("\U0001F600", 501)));
        Assert.That(PhpText.CodePointCount(cut), Is.EqualTo(500));
    }
}
