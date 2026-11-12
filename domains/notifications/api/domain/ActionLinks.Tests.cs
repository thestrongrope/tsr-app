using NUnit.Framework;

namespace Tsr.Notifications.Api.Domain;

public sealed class ActionLinksTests
{
    [TestCase("https://thestrongrope.com/articles/my-post/", "/articles/my-post")]
    [TestCase("https://www.thestrongrope.com/articles/abc", "/articles/abc")]
    [TestCase("https://www.youtube.com/watch?v=abc_12", "/videos/abc_12")]
    [TestCase("https://youtube.com/watch?x=1&v=abc", "/videos/abc")]
    [TestCase("https://youtu.be/abc?t=5", "/videos/abc")]
    [TestCase("https://thestrongrope.com.evil.example/articles/x", "https://thestrongrope.com.evil.example/articles/x")]
    [TestCase("  /classes/12/syllabus ", "/classes/12/syllabus")]
    public void A_pasted_link_becomes_its_in_app_path_and_any_other_stays(string link, string expected) =>
        Assert.That(ActionLinks.InApp(link), Is.EqualTo(expected));

    [TestCase("/classes/12/syllabus", true)]
    [TestCase("/home", true)]
    [TestCase("/login?error=x", false)]
    [TestCase("/admin/users", false)]
    [TestCase("https://example.org/a?b=c", true)]
    [TestCase("http://example.org", false)]
    [TestCase("javascript:alert(1)", false)]
    [TestCase("/classes/1\n", false)]
    public void Only_content_paths_and_https_links_are_allowed(string link, bool allowed) =>
        Assert.That(ActionLinks.Allowed(link), Is.EqualTo(allowed));
}
