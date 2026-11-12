using NUnit.Framework;

namespace Tsr.Access.Api.Features.MePermissions;

/// <summary>Does an If-None-Match header name the answer's tag? PHP's api_etag_matches, case for case (MePermissionsRouteTest).</summary>
public sealed class MePermissionsTests
{
    private const string Tag = "\"0123456789abcdef\"";

    [TestCase("\"0123456789abcdef\"")]
    [TestCase("W/\"0123456789abcdef\"")]
    [TestCase("\"stale\", \"0123456789abcdef\"")]
    [TestCase("\"stale\",W/\"0123456789abcdef\"")]
    [TestCase("  \"0123456789abcdef\"\t")]
    [TestCase("*")]
    [TestCase("\"stale\", *")]
    public void A_header_that_names_the_tag_matches(string sent)
    {
        Assert.That(MePermissionsEndpoint.EtagMatches(sent, Tag), Is.True);
    }

    [TestCase("\"fedcba9876543210\"")]
    [TestCase("0123456789abcdef")]
    [TestCase("")]
    [TestCase("\"\"")]
    [TestCase("w/\"0123456789abcdef\"")]
    [TestCase("W/W/\"0123456789abcdef\"")]
    [TestCase("\"0123456789ABCDEF\"")]
    public void A_header_that_does_not_name_the_tag_does_not_match(string sent)
    {
        Assert.That(MePermissionsEndpoint.EtagMatches(sent, Tag), Is.False);
    }
}
