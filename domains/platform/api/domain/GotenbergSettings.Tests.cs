using NUnit.Framework;

namespace Tsr.Platform.Api.Domain;

[TestFixture]
internal sealed class GotenbergSettingsTests
{
    [TestCase("http://gotenberg:3000", true)]
    [TestCase("https://render.example.invalid/", true)]
    [TestCase(null, false)]
    [TestCase("", false)]
    [TestCase("gotenberg:3000", false)]
    [TestCase("ftp://gotenberg", false)]
    [TestCase("/relative", false)]
    public void Only_an_absolute_http_or_https_URL_is_a_setting(string? url, bool valid) =>
        Assert.That(GotenbergSettings.IsValid(url), Is.EqualTo(valid));

    [TestCase("http://gotenberg:3000", "http://gotenberg:3000/")]
    [TestCase("http://gotenberg:3000/", "http://gotenberg:3000/")]
    public void The_base_address_ends_in_a_slash_so_a_relative_route_is_added_to_it(string url, string expected) =>
        Assert.That(new GotenbergSettings { Url = url }.BaseUri.ToString(), Is.EqualTo(expected));
}
