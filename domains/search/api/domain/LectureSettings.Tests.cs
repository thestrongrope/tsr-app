using NUnit.Framework;

namespace Tsr.Search.Api.Domain;

/// <summary>The lecture settings (plan 3.7): all optional, so the API starts without them (SRCH-Q6). The meaning layer is on only with a weight above 0 and a valid service address.</summary>
[TestFixture]
internal sealed class LectureSettingsTests
{
    [TestCase("http://embeddings:8000", "0.25", true, 0.25)]
    [TestCase("http://embeddings:8000", "1", true, 1.0)]
    [TestCase("http://embeddings:8000", "0", false, 0.0)]
    [TestCase("http://embeddings:8000", null, false, 0.0)]
    [TestCase("http://embeddings:8000", "", false, 0.0)]
    [TestCase("http://embeddings:8000", "abc", false, 0.0)]
    [TestCase("http://embeddings:8000", "-0.5", false, 0.0)]
    [TestCase("http://embeddings:8000", "NaN", false, 0.0)]
    [TestCase("http://embeddings:8000", "Infinity", false, 0.0)]
    [TestCase(null, "0.25", false, 0.25)]
    [TestCase("", "0.25", false, 0.25)]
    [TestCase("not a url", "0.25", false, 0.25)]
    [TestCase("ftp://embeddings", "0.25", false, 0.25)]
    public void The_meaning_layer_needs_a_weight_above_zero_and_a_valid_address(string? url, string? weight, bool enabled, double expectedWeight)
    {
        var settings = LectureSettings.From(url, weight, null);

        Assert.That(settings.SemanticEnabled, Is.EqualTo(enabled));
        Assert.That(settings.SemanticWeight, Is.EqualTo(expectedWeight));
    }

    [Test]
    public void The_file_is_kept_as_written_and_an_empty_one_is_none()
    {
        Assert.That(LectureSettings.From(null, null, "/var/tsr/lectures.ndjson").LecturesFile, Is.EqualTo("/var/tsr/lectures.ndjson"));
        Assert.That(LectureSettings.From(null, null, "  ").LecturesFile, Is.Null);
        Assert.That(LectureSettings.From(null, null, null).LecturesFile, Is.Null);
    }
}
