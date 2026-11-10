using System.Text;
using Microsoft.Extensions.Logging.Abstractions;
using NUnit.Framework;
using Tsr.Platform.Api.Domain;

namespace Tsr.Platform.Api.Tests.Domain;

/// <summary>
/// The app-version catalog rules, one case per rule in tsr-account's routes/app_version.php
/// (docs/specs/initial-build/phase-3-platform-recon.md, 3.1 and 3.2). Expected strings are compact
/// JSON, so key order and [] versus {} are checked too.
/// </summary>
public sealed class AppCatalogTests
{
    private const string AndroidFallback =
        "{\"minimumBuild\":1,\"recommendedBuild\":1,\"storeUrl\":\"https://play.google.com/store/apps/details?id=com.thestrongrope\"}";

    private const string IosFallback =
        "{\"minimumBuild\":1,\"recommendedBuild\":1,\"storeUrl\":\"https://apps.apple.com/app/id6807232453\"}";

    private const string Fallback = "{\"android\":" + AndroidFallback + ",\"ios\":" + IosFallback + "}";

    private static string Version(string json) => Version(Encoding.UTF8.GetBytes(json));

    private static string Version(byte[] utf8)
    {
        using var catalog = AppCatalog.Decode(utf8, NullLogger.Instance);
        return AppCatalog.VersionPayload(catalog, NullLogger.Instance).ToJsonString(AppCatalogJson.Options);
    }

    private static string Releases(string json)
    {
        using var catalog = AppCatalog.Decode(Encoding.UTF8.GetBytes(json), NullLogger.Instance);
        return AppCatalog.Releases(catalog, NullLogger.Instance).ToJsonString(AppCatalogJson.Options);
    }

    private static string Platform(string json, string platform) =>
        System.Text.Json.Nodes.JsonNode.Parse(Version(json))![platform]!.ToJsonString(AppCatalogJson.Options);

    private static string Android(string entry) => "{\"android\":" + entry + "}";

    private static string Release(string release) => "{\"releases\":[" + release + "]}";

    // ---- the file as a whole -------------------------------------------------------------------

    [Test]
    public void A_missing_file_serves_the_fallback()
    {
        using var catalog = AppCatalog.Decode(ReadOnlySpan<byte>.Empty, NullLogger.Instance);
        Assert.That(catalog, Is.Null);
        Assert.That(AppCatalog.VersionPayload(null, NullLogger.Instance).ToJsonString(AppCatalogJson.Options), Is.EqualTo(Fallback));
        Assert.That(AppCatalog.Releases(null, NullLogger.Instance).ToJsonString(AppCatalogJson.Options), Is.EqualTo("[]"));
    }

    [TestCase("not json")]
    [TestCase("")]
    [TestCase("\"a string\"")]
    [TestCase("42")]
    [TestCase("null")]
    [TestCase("true")]
    [TestCase("{\"android\":")]
    [TestCase("{\"a\":1,}")]
    public void A_file_that_is_not_a_json_object_or_list_serves_the_fallback(string json)
    {
        Assert.That(Version(json), Is.EqualTo(Fallback));
        Assert.That(Releases(json), Is.EqualTo("[]"));
    }

    [Test]
    public void A_file_with_a_byte_order_mark_serves_the_fallback_like_php()
    {
        var bytes = new byte[] { 0xEF, 0xBB, 0xBF }.Concat(Encoding.UTF8.GetBytes("{\"android\":{\"minimumBuild\":9}}")).ToArray();

        Assert.That(Version(bytes), Is.EqualTo(Fallback));
    }

    [Test]
    public void A_file_with_invalid_utf8_serves_the_fallback()
    {
        Assert.That(Version([0x7B, 0x22, 0xFF, 0x22, 0x3A, 0x31, 0x7D]), Is.EqualTo(Fallback));
    }

    [TestCase("[]")]
    [TestCase("{}")]
    [TestCase("[1,2]")]
    public void An_empty_object_or_a_list_is_usable_and_gives_the_fallback_blocks(string json)
    {
        // PHP's is_array accepts both; every platform then falls back on its own.
        Assert.That(Version(json), Is.EqualTo(Fallback));
        Assert.That(Releases(json), Is.EqualTo("[]"));
    }

    [Test]
    public void Unknown_keys_are_ignored_and_the_last_duplicate_wins()
    {
        var json = "{\"_comment\":[\"x\"],\"android\":{\"minimumBuild\":3,\"minimumBuild\":4}}";

        Assert.That(Platform(json, "android"), Does.StartWith("{\"minimumBuild\":4,"));
    }

    [Test]
    public void The_payload_keeps_the_order_android_ios_announcement()
    {
        var json = "{\"announcement\":{\"id\":\"a\",\"title\":\"t\"},\"ios\":{\"minimumBuild\":2},\"android\":{\"minimumBuild\":3}}";

        Assert.That(
            Version(json),
            Is.EqualTo(
                "{\"android\":{\"minimumBuild\":3,\"recommendedBuild\":3,\"storeUrl\":\"https://play.google.com/store/apps/details?id=com.thestrongrope\"},"
                + "\"ios\":{\"minimumBuild\":2,\"recommendedBuild\":2,\"storeUrl\":\"https://apps.apple.com/app/id6807232453\"},"
                + "\"announcement\":{\"id\":\"a\",\"title\":\"t\",\"body\":\"\"}}"));
    }

    // ---- a platform's block --------------------------------------------------------------------

    [TestCase("\"12\"")]
    [TestCase("12.0")]
    [TestCase("1e2")]
    [TestCase("12345678901234567890")]
    [TestCase("null")]
    [TestCase("true")]
    [TestCase("[12]")]
    public void A_minimumBuild_that_is_not_a_json_integer_gives_that_platform_the_fallback_block(string minimum)
    {
        var json = "{\"android\":{\"minimumBuild\":" + minimum + ",\"recommendedBuild\":20},\"ios\":{\"minimumBuild\":7}}";

        Assert.That(Platform(json, "android"), Is.EqualTo(AndroidFallback));
        Assert.That(Platform(json, "ios"), Does.StartWith("{\"minimumBuild\":7,"));
    }

    [TestCase("{}")]
    [TestCase("\"text\"")]
    [TestCase("5")]
    [TestCase("null")]
    [TestCase("[]")]
    public void A_platform_entry_without_a_minimumBuild_is_the_fallback_block(string entry)
    {
        Assert.That(Platform(Android(entry), "android"), Is.EqualTo(AndroidFallback));
    }

    [Test]
    public void A_missing_platform_is_the_fallback_block()
    {
        Assert.That(Platform("{\"ios\":{\"minimumBuild\":2}}", "android"), Is.EqualTo(AndroidFallback));
    }

    [TestCase("-0", 0)]
    [TestCase("0", 0)]
    [TestCase("-5", -5)]
    [TestCase("9223372036854775807", long.MaxValue)]
    public void Any_json_integer_that_fits_64_bits_is_accepted_as_minimumBuild(string minimum, long expected)
    {
        var block = Platform(Android("{\"minimumBuild\":" + minimum + "}"), "android");

        Assert.That(block, Does.StartWith("{\"minimumBuild\":" + expected + ",\"recommendedBuild\":" + expected + ","));
    }

    [TestCase("30")]
    public void A_recommendedBuild_that_is_an_integer_is_used(string recommended)
    {
        Assert.That(Platform(Android("{\"minimumBuild\":10,\"recommendedBuild\":" + recommended + "}"), "android"),
            Does.StartWith("{\"minimumBuild\":10,\"recommendedBuild\":30,"));
    }

    [TestCase("\"30\"")]
    [TestCase("30.0")]
    [TestCase("null")]
    [TestCase("true")]
    public void A_recommendedBuild_that_is_not_an_integer_becomes_the_minimumBuild(string recommended)
    {
        Assert.That(Platform(Android("{\"minimumBuild\":10,\"recommendedBuild\":" + recommended + "}"), "android"),
            Does.StartWith("{\"minimumBuild\":10,\"recommendedBuild\":10,"));
    }

    [Test]
    public void A_missing_recommendedBuild_becomes_the_minimumBuild()
    {
        Assert.That(Platform(Android("{\"minimumBuild\":10}"), "android"), Does.StartWith("{\"minimumBuild\":10,\"recommendedBuild\":10,"));
    }

    [Test]
    public void A_storeUrl_that_is_a_non_empty_string_is_used()
    {
        Assert.That(Platform(Android("{\"minimumBuild\":10,\"storeUrl\":\"https://example.invalid/a\"}"), "android"),
            Does.EndWith("\"storeUrl\":\"https://example.invalid/a\"}"));
    }

    [TestCase("\"\"")]
    [TestCase("null")]
    [TestCase("5")]
    [TestCase("[\"https://x\"]")]
    public void A_storeUrl_that_is_empty_or_not_a_string_is_the_fallback_url(string url)
    {
        Assert.That(Platform(Android("{\"minimumBuild\":10,\"storeUrl\":" + url + "}"), "android"),
            Does.EndWith("\"storeUrl\":\"https://play.google.com/store/apps/details?id=com.thestrongrope\"}"));
    }

    [Test]
    public void The_store_url_is_written_with_unescaped_slashes_and_unicode()
    {
        Assert.That(Platform(Android("{\"minimumBuild\":10,\"storeUrl\":\"https://x.invalid/é?a=1&b=2\"}"), "android"),
            Does.EndWith("\"storeUrl\":\"https://x.invalid/é?a=1&b=2\"}"));
    }

    // ---- latest --------------------------------------------------------------------------------

    private static string TwoReleases(string builds1, string builds2) =>
        "{\"android\":{\"minimumBuild\":10,\"recommendedBuild\":20},\"releases\":["
        + "{\"version\":\"1.2\",\"date\":\"2030-02-01\",\"notes\":[\"n2\"],\"builds\":" + builds1 + "},"
        + "{\"version\":\"1.1\",\"date\":\"2030-01-01\",\"notes\":[\"n1\"],\"builds\":" + builds2 + "}]}";

    [Test]
    public void Latest_is_the_first_release_in_file_order_whose_build_equals_the_recommendedBuild()
    {
        var json = TwoReleases("{\"android\":20}", "{\"android\":20}");

        Assert.That(Platform(json, "android"), Does.EndWith(",\"latest\":{\"version\":\"1.2\",\"notes\":[\"n2\"]}}"));
    }

    [Test]
    public void Latest_skips_releases_that_do_not_match_and_keeps_the_file_order()
    {
        var json = TwoReleases("{\"android\":21}", "{\"android\":20}");

        Assert.That(Platform(json, "android"), Does.EndWith(",\"latest\":{\"version\":\"1.1\",\"notes\":[\"n1\"]}}"));
    }

    [Test]
    public void Latest_is_absent_not_null_when_no_release_matches()
    {
        var block = Platform(TwoReleases("{\"android\":21}", "{\"android\":19}"), "android");

        Assert.That(block, Does.Not.Contain("latest"));
    }

    [Test]
    public void Latest_needs_an_integer_build_so_a_quoted_build_never_matches()
    {
        Assert.That(Platform(TwoReleases("{\"android\":\"20\"}", "{\"android\":20.0}"), "android"), Does.Not.Contain("latest"));
    }

    [Test]
    public void Latest_is_looked_up_per_platform()
    {
        var json = "{\"android\":{\"minimumBuild\":1,\"recommendedBuild\":5},\"ios\":{\"minimumBuild\":1,\"recommendedBuild\":6},"
            + "\"releases\":[{\"version\":\"A\",\"date\":\"2030-01-01\",\"builds\":{\"android\":5,\"ios\":6}},"
            + "{\"version\":\"B\",\"date\":\"2030-01-01\",\"builds\":{\"android\":6,\"ios\":5}}]}";

        Assert.That(Platform(json, "android"), Does.Contain("\"latest\":{\"version\":\"A\""));
        Assert.That(Platform(json, "ios"), Does.Contain("\"latest\":{\"version\":\"A\""));
    }

    [Test]
    public void A_platform_that_fell_back_never_gets_latest_even_when_a_release_has_build_1()
    {
        var json = "{\"android\":{\"minimumBuild\":\"12\"},\"releases\":[{\"version\":\"0.1\",\"date\":\"2030-01-01\",\"builds\":{\"android\":1}}]}";

        Assert.That(Platform(json, "android"), Is.EqualTo(AndroidFallback));
    }

    // ---- releases: one by one --------------------------------------------------------------------

    private const string Android20 = "{\"android\":{\"minimumBuild\":10,\"recommendedBuild\":20},\"releases\":";

    private static string Latest(string releases) => Platform(Android20 + releases + "}", "android");

    private static string ValidRelease(string version = "\"1.0\"", string date = "\"2030-01-01\"", string builds = "{\"android\":20}") =>
        "{\"version\":" + version + ",\"date\":" + date + ",\"notes\":[\"ok\"],\"builds\":" + builds + "}";

    [Test]
    public void A_valid_release_is_the_baseline_for_the_cases_below()
    {
        Assert.That(Latest("[" + ValidRelease() + "]"), Does.Contain("\"latest\":{\"version\":\"1.0\""));
    }

    [TestCase("\"\"")]
    [TestCase("null")]
    [TestCase("1")]
    [TestCase("[\"1.0\"]")]
    public void A_release_without_a_non_empty_string_version_is_dropped(string version)
    {
        Assert.That(Latest("[" + ValidRelease(version: version) + "]"), Does.Not.Contain("latest"));
    }

    [TestCase("null")]
    [TestCase("20300101")]
    [TestCase("\"30-01-01\"")]
    [TestCase("\"2030-1-01\"")]
    [TestCase("\"2030-01-01x\"")]
    [TestCase("\" 2030-01-01\"")]
    [TestCase("\"2030-01-01\\n\\n\"")]
    [TestCase("\"\\u0662\\u0660\\u0663\\u0660-01-01\"")]
    public void A_release_whose_date_is_not_a_yyyy_mm_dd_string_is_dropped(string date)
    {
        Assert.That(Latest("[" + ValidRelease(date: date) + "]"), Does.Not.Contain("latest"));
    }

    [TestCase("\"2030-99-99\"")]
    [TestCase("\"0000-00-00\"")]
    [TestCase("\"2030-01-01\\n\"")]
    public void A_date_is_checked_for_its_shape_only_and_php_lets_one_final_newline_through(string date)
    {
        Assert.That(Latest("[" + ValidRelease(date: date) + "]"), Does.Contain("\"latest\""));
    }

    [TestCase("null")]
    [TestCase("\"x\"")]
    [TestCase("5")]
    public void A_release_without_a_builds_object_is_dropped(string builds)
    {
        Assert.That(Latest("[" + ValidRelease(builds: builds) + "]"), Does.Not.Contain("latest"));
    }

    [Test]
    public void A_release_that_is_not_an_object_is_dropped_and_the_next_one_is_still_used()
    {
        Assert.That(Latest("[\"text\",null,[1],5," + ValidRelease("\"2.0\"") + "]"), Does.Contain("\"version\":\"2.0\""));
    }

    [Test]
    public void A_malformed_release_never_drops_the_others()
    {
        Assert.That(Latest("[{\"version\":\"\"}," + ValidRelease("\"3.0\"") + "]"), Does.Contain("\"version\":\"3.0\""));
    }

    [TestCase("\"not a list\"")]
    [TestCase("5")]
    [TestCase("null")]
    [TestCase("true")]
    public void A_releases_value_that_is_not_a_list_is_ignored(string releases)
    {
        Assert.That(Latest(releases), Does.Not.Contain("latest"));
        Assert.That(Releases("{\"releases\":" + releases + "}"), Is.EqualTo("[]"));
    }

    [Test]
    public void A_releases_value_that_is_an_object_is_read_as_its_values_in_file_order_like_php()
    {
        var json = "{\"releases\":{\"x\":" + ValidRelease("\"1.0\"") + ",\"y\":" + ValidRelease("\"0.9\"") + "}}";

        Assert.That(Releases(json), Does.StartWith("[{\"version\":\"1.0\"").And.Contain("{\"version\":\"0.9\""));
    }

    // ---- notes and builds ------------------------------------------------------------------------

    [Test]
    public void Notes_keep_only_non_empty_strings_in_order()
    {
        var json = Release("{\"version\":\"1\",\"date\":\"2030-01-01\",\"notes\":[\"a\",\"\",5,null,[\"x\"],\"b\"],\"builds\":{}}");

        Assert.That(Releases(json), Is.EqualTo("[{\"version\":\"1\",\"date\":\"2030-01-01\",\"notes\":[\"a\",\"b\"],\"builds\":[]}]"));
    }

    [TestCase("\"text\"")]
    [TestCase("null")]
    [TestCase("5")]
    public void Notes_that_are_not_a_list_become_an_empty_list(string notes)
    {
        var json = Release("{\"version\":\"1\",\"date\":\"2030-01-01\",\"notes\":" + notes + ",\"builds\":{}}");

        Assert.That(Releases(json), Does.Contain("\"notes\":[]"));
    }

    [Test]
    public void Missing_notes_are_an_empty_list()
    {
        Assert.That(Releases(Release("{\"version\":\"1\",\"date\":\"2030-01-01\",\"builds\":{}}")), Does.Contain("\"notes\":[]"));
    }

    [Test]
    public void Notes_given_as_an_object_keep_their_values_like_php()
    {
        var json = Release("{\"version\":\"1\",\"date\":\"2030-01-01\",\"notes\":{\"a\":\"x\",\"b\":\"y\"},\"builds\":{}}");

        Assert.That(Releases(json), Does.Contain("\"notes\":[\"x\",\"y\"]"));
    }

    [Test]
    public void Builds_keep_only_integer_values_and_are_written_android_then_ios()
    {
        var json = Release("{\"version\":\"1\",\"date\":\"2030-01-01\",\"builds\":{\"ios\":4,\"android\":3,\"web\":9}}");

        Assert.That(Releases(json), Does.Contain("\"builds\":{\"android\":3,\"ios\":4}"));
    }

    [Test]
    public void A_build_that_is_not_an_integer_drops_that_platform_from_the_release_only()
    {
        var json = Release("{\"version\":\"1\",\"date\":\"2030-01-01\",\"builds\":{\"android\":\"3\",\"ios\":4}}");

        Assert.That(Releases(json), Does.Contain("\"builds\":{\"ios\":4}"));
    }

    [TestCase("{}")]
    [TestCase("[]")]
    [TestCase("[1,2]")]
    [TestCase("{\"android\":\"3\",\"ios\":null}")]
    public void Builds_with_no_integer_are_written_as_an_empty_list_not_an_object(string builds)
    {
        var json = Release("{\"version\":\"1\",\"date\":\"2030-01-01\",\"builds\":" + builds + "}");

        Assert.That(Releases(json), Does.Contain("\"builds\":[]"));
    }

    [Test]
    public void The_release_list_keeps_the_file_order_and_is_not_sorted()
    {
        var json = "{\"releases\":[" + ValidRelease("\"1.0\"", "\"2030-01-01\"") + "," + ValidRelease("\"2.0\"", "\"2031-01-01\"") + "]}";

        Assert.That(Releases(json), Does.StartWith("[{\"version\":\"1.0\"").And.Contain("{\"version\":\"2.0\""));
    }

    [Test]
    public void A_catalog_without_releases_gives_an_empty_list()
    {
        Assert.That(Releases("{\"android\":{\"minimumBuild\":1}}"), Is.EqualTo("[]"));
    }

    // ---- announcement ----------------------------------------------------------------------------

    private static string Announcement(string value) => Version("{\"announcement\":" + value + "}");

    [Test]
    public void A_valid_announcement_is_added_after_the_platforms()
    {
        Assert.That(Announcement("{\"id\":\"a1\",\"title\":\"T\",\"body\":\"B\"}"), Does.EndWith(",\"announcement\":{\"id\":\"a1\",\"title\":\"T\",\"body\":\"B\"}}"));
    }

    [TestCase("null")]
    [TestCase("\"text\"")]
    [TestCase("5")]
    [TestCase("[]")]
    [TestCase("{}")]
    [TestCase("{\"id\":\"a\"}")]
    [TestCase("{\"title\":\"t\"}")]
    [TestCase("{\"id\":\"\",\"title\":\"t\"}")]
    [TestCase("{\"id\":\"a\",\"title\":\"\"}")]
    [TestCase("{\"id\":1,\"title\":\"t\"}")]
    [TestCase("{\"id\":\"a\",\"title\":5}")]
    public void A_missing_or_malformed_announcement_is_left_out_not_null(string value)
    {
        Assert.That(Announcement(value), Is.EqualTo(Fallback));
    }

    [TestCase("5")]
    [TestCase("null")]
    [TestCase("[\"b\"]")]
    public void An_announcement_body_that_is_not_a_string_becomes_empty(string body)
    {
        Assert.That(Announcement("{\"id\":\"a\",\"title\":\"t\",\"body\":" + body + "}"), Does.EndWith("\"body\":\"\"}}"));
    }

    [Test]
    public void An_announcement_without_a_body_has_an_empty_body()
    {
        Assert.That(Announcement("{\"id\":\"a\",\"title\":\"t\"}"), Does.EndWith("\"body\":\"\"}}"));
    }

    [TestCase("{\"unused\":\"\\ud800\",\"android\":{\"minimumBuild\":5}}")]
    [TestCase("{\"android\":{\"minimumBuild\":5},\"releases\":[{\"version\":\"\\ud800\",\"date\":\"2026-01-01\",\"builds\":{}}]}")]
    [TestCase("{\"\\udc00\":1,\"android\":{\"minimumBuild\":5}}")]
    public void A_lone_surrogate_escape_anywhere_makes_the_whole_file_invalid_as_in_php(string json)
    {
        Assert.That(Version(json), Is.EqualTo(Fallback));
        Assert.That(Releases(json), Is.EqualTo("[]"));
    }
}
