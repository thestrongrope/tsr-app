using System.Net;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using Tsr.Content.Site;
using Tsr.Shared.Site;
using NUnit.Framework;

namespace Tsr.Host.Site.Tests;

/// <summary>
/// Issue 74, SITE-R60 to R69: the Self-reflection pages. What the build writes is tested here: the text of the three languages, the
/// markup the script hooks into, the language and direction, the entry page, the scripts. The scoring and the storage are the
/// script's own pure functions (hosts/site/tests/js/self-reflection.test.js). Clicking, typing and the live numbers are the script's
/// DOM part and are not tested: no browser runs in these tests.
/// </summary>
public sealed partial class SelfReflectionTests
{
    private static readonly string[] Languages = ["en", "ur", "gu"];

    [GeneratedRegex("<script")]
    private static partial Regex ScriptTag();

    [GeneratedRegex(@"<main\b[^>]*>")]
    private static partial Regex MainTag();

    [GeneratedRegex(@"<[a-z][^>]*\shidden(?:=""[^""]*"")?[^>]*>")]
    private static partial Regex HiddenElement();

    private static async Task<string> RenderAsync(string path)
    {
        var api = FakeApi.Healthy();
        var pages = await SiteBuilder.CollectAsync(SiteModules.All, api, CancellationToken.None);
        var menu = await ContentSite.MenuAsync(api, CancellationToken.None);
        return await SiteBuilder.RenderAsync(pages.Single(p => p.Path == path), menu);
    }

    private static string Decoded(string html) => WebUtility.HtmlDecode(html);

    private static string MainElement(string html) => html[html.IndexOf("<main", StringComparison.Ordinal)..(html.IndexOf("</main>", StringComparison.Ordinal) + 7)];

    private static JsonNode Source()
    {
        var folder = new DirectoryInfo(AppContext.BaseDirectory);
        while (folder is not null && !File.Exists(Path.Combine(folder.FullName, "TsrApp.slnx")))
        {
            folder = folder.Parent;
        }

        return JsonNode.Parse(File.ReadAllText(Path.Combine(folder!.FullName, "domains", "content", "site", "self-reflection.json")))!;
    }

    private static void Leaves(JsonNode? node, string path, List<(string Path, string Text)> into)
    {
        switch (node)
        {
            case JsonObject obj:
                foreach (var pair in obj)
                {
                    Leaves(pair.Value, path + "/" + pair.Key, into);
                }

                break;
            case JsonArray array:
                for (var i = 0; i < array.Count; i++)
                {
                    Leaves(array[i], path + "/" + i, into);
                }

                break;
            default:
                into.Add((path, node!.GetValue<string>()));
                break;
        }
    }

    private static List<(string Path, string Text)> LeavesOf(string language)
    {
        var into = new List<(string, string)>();
        Leaves(Source()[language], "", into);
        return into;
    }

    private static string Attribute(string html, string name)
    {
        var match = Regex.Match(html, name + @"=""(?<value>[^""]*)""");
        Assert.That(match.Success, Is.True, name);
        return WebUtility.HtmlDecode(match.Groups["value"].Value);
    }

    [Test]
    public void TC_SITE_R60_01_The_three_languages_hold_the_same_keys_the_same_list_lengths_and_no_empty_value()
    {
        var english = LeavesOf("en").Select(l => l.Path).ToList();

        Assert.Multiple(() =>
        {
            Assert.That(LeavesOf("ur").Select(l => l.Path), Is.EqualTo(english));
            Assert.That(LeavesOf("gu").Select(l => l.Path), Is.EqualTo(english));
            foreach (var language in Languages)
            {
                Assert.That(LeavesOf(language).Where(l => string.IsNullOrWhiteSpace(l.Text)), Is.Empty, language);
            }

            Assert.That(english, Has.Count.EqualTo(116));
        });
    }

    [Test]
    public async Task TC_SITE_R60_02_The_site_publishes_the_entry_and_one_page_per_language_with_the_present_site_s_title()
    {
        var pages = (await SiteBuilder.CollectAsync(SiteModules.All, FakeApi.Healthy(), CancellationToken.None))
            .Where(p => p.Path.StartsWith("/self-reflection/", StringComparison.Ordinal)).ToList();

        Assert.Multiple(() =>
        {
            Assert.That(pages.Select(p => p.Path), Is.EquivalentTo(new List<string> { "/self-reflection/", "/self-reflection/en/", "/self-reflection/ur/", "/self-reflection/gu/" }));
            Assert.That(pages.Select(p => p.Title), Has.All.EqualTo("The Strong Rope"));
        });
    }

    [TestCase("en")]
    [TestCase("ur")]
    [TestCase("gu")]
    public async Task TC_SITE_R60_03_Every_label_option_and_instruction_of_the_language_is_on_its_page_word_for_word(string language)
    {
        var html = Decoded(MainElement(await RenderAsync($"/self-reflection/{language}/")));
        // "loading" is the present page's text while it waits for the browser's storage; this page has no such wait. "dir" is an
        // attribute, tested below. An instruction with a bold word is written with that word in <strong>.
        var skipped = new List<string> { "/dir", "/loading" };
        var missing = new List<string>();
        foreach (var (path, text) in LeavesOf(language))
        {
            var shown = path.Contains("/instructions/items/", StringComparison.Ordinal) && path.EndsWith("/text", StringComparison.Ordinal) ? InstructionHtml(language, path, text) : text;
            if (!skipped.Contains(path) && !html.Contains(shown, StringComparison.Ordinal))
            {
                missing.Add(path + ": " + text);
            }
        }

        Assert.That(missing, Is.Empty);
    }

    private static string InstructionHtml(string language, string path, string text)
    {
        var index = int.Parse(path.Split('/')[3], System.Globalization.CultureInfo.InvariantCulture);
        var bold = Source()[language]!["instructions"]!["items"]![index]!["bold"]?.GetValue<string>();
        return bold is null ? text : text.Replace("{bold}", $"<strong>{bold}</strong>", StringComparison.Ordinal);
    }

    [Test]
    public async Task TC_SITE_R60_04_The_page_has_the_five_scored_and_unscored_sections_the_covenant_box_and_the_present_site_s_counts()
    {
        var html = MainElement(await RenderAsync("/self-reflection/en/"));

        Assert.Multiple(() =>
        {
            Assert.That(Regex.Count(html, @"data-sr-section=""\d"""), Is.EqualTo(6));
            Assert.That(Regex.Count(html, "data-sr-check=\""), Is.EqualTo(12));
            Assert.That(Regex.Count(html, "data-sr-option=\""), Is.EqualTo(12));
            Assert.That(Regex.Count(html, "data-sr-trait=\""), Is.EqualTo(15));
            Assert.That(Regex.Count(html, "data-sr-step=\""), Is.EqualTo(6));
            Assert.That(Regex.Count(html, "data-sr-field=\""), Is.EqualTo(10));
            Assert.That(html, Does.Match(@"<textarea[^>]*data-sr-field=""covenant""[^>]*placeholder=""Write your personal covenant here\.\.\."""));
            Assert.That(Regex.Count(html, "<input type=\"text\""), Is.EqualTo(5));
        });
    }

    [Test]
    public async Task TC_SITE_R61_01_The_urdu_page_is_right_to_left_and_states_its_language_on_its_main_element_and_the_others_left_to_right()
    {
        var expected = new Dictionary<string, string> { ["en"] = "ltr", ["ur"] = "rtl", ["gu"] = "ltr" };

        foreach (var (language, direction) in expected)
        {
            var main = MainTag().Match(await RenderAsync($"/self-reflection/{language}/")).Value;
            Assert.That(main, Does.Contain($"dir=\"{direction}\"").And.Contain($"lang=\"{language}\""), language);
        }
    }

    [Test]
    public async Task TC_SITE_R61_02_The_urdu_font_comes_from_the_stylesheet_s_lang_ur_rule_and_no_page_brings_a_font_file()
    {
        var css = await File.ReadAllTextAsync(Path.Combine(SiteBuilder.StaticFilesFolder, "site.css"));
        var fonts = Directory.GetFiles(Path.Combine(SiteBuilder.StaticFilesFolder, "fonts")).Select(Path.GetFileName).ToList();

        Assert.Multiple(() =>
        {
            Assert.That(css, Does.Match(@"\[lang=""ur""\]\s*\{\s*font-family:\s*var\(--font-gulzar\)"));
            // Gujarati has no rule and no font file here, as on the present site: the reader's system font is used.
            Assert.That(css, Does.Not.Contain("[lang=\"gu\"]"));
            Assert.That(fonts, Has.None.Contains("gujarati").IgnoreCase);
        });
    }

    [Test]
    public async Task TC_SITE_R62_01_Section_badges_the_range_list_and_the_two_focus_places_are_written_for_the_script_to_fill_in()
    {
        var html = MainElement(await RenderAsync("/self-reflection/en/"));

        Assert.Multiple(() =>
        {
            Assert.That(Regex.Matches(html, @"data-sr-badge=""(\d)""[^>]*>[\s\S]*?<span>/ (\d)</span>").Select(m => m.Groups[1].Value + "/" + m.Groups[2].Value),
                Is.EqualTo(new List<string> { "0/6", "1/5", "2/5", "3/3" }));
            Assert.That(html, Does.Contain("/ 19</span>"));
            Assert.That(Regex.Count(html, "data-sr-range=\""), Is.EqualTo(4));
            Assert.That(Regex.Count(html, "data-sr-tier=\""), Is.EqualTo(4));
            Assert.That(Regex.Count(html, "data-sr-weakest=\""), Is.EqualTo(4));
            Assert.That(Regex.Count(html, "data-sr-focus=\""), Is.EqualTo(4));
            Assert.That(html, Does.Contain("data-sr-bar"));
        });
    }

    [Test]
    public async Task TC_SITE_R62_02_The_section_names_in_the_focus_places_are_the_titles_without_their_number_and_the_sticky_ones_are_cut_at_15()
    {
        var english = MainElement(await RenderAsync("/self-reflection/en/"));
        var urdu = MainElement(await RenderAsync("/self-reflection/ur/"));
        var gujarati = MainElement(await RenderAsync("/self-reflection/gu/"));

        Assert.Multiple(() =>
        {
            var full = Regex.Matches(english, @"data-sr-weakest=""\d""[^>]*>[\s\S]*?<strong[^>]*>([^<]*)</strong>").Select(m => m.Groups[1].Value);
            Assert.That(full, Is.EqualTo(new List<string> { "BRUTAL HONESTY CHECK", "WAITING OR WASTING?", "CHARACTER TEST", "ONE QUIET ACT OF SERVICE" }));
            var sticky = Regex.Matches(english, @"data-sr-focus=""\d""[^>]*>\s*([^<]*?)\s*</div>").Select(m => m.Groups[1].Value);
            Assert.That(sticky, Is.EqualTo(new List<string> { "BRUTAL HONESTY ...", "WAITING OR WAST...", "CHARACTER TEST", "ONE QUIET ACT O..." }));
            Assert.That(Decoded(urdu), Does.Contain(">سچائی کی جانچ</strong>").And.Contain(">کردار کا محاسبہ</strong>"));
            Assert.That(Decoded(gujarati), Does.Contain(">કડક પ્રામાણિકતા ચકાસણી</strong>"));
        });
    }

    [Test]
    public async Task TC_SITE_R63_01_Every_option_button_carries_its_position_and_the_three_languages_carry_the_same_ones()
    {
        var positions = new List<string>();
        foreach (var language in Languages)
        {
            var html = MainElement(await RenderAsync($"/self-reflection/{language}/"));
            positions.Add(string.Join(",", Regex.Matches(html, @"data-sr-option=""(\d)""[^>]*data-sr-position=""(\d)""").Select(m => m.Groups[1].Value + ":" + m.Groups[2].Value)));
        }

        Assert.Multiple(() =>
        {
            Assert.That(positions[0], Is.EqualTo("0:0,0:1,1:0,1:1,2:0,2:1,2:2,2:3,3:0,3:1,4:0,4:1"));
            Assert.That(positions[1], Is.EqualTo(positions[0]));
            Assert.That(positions[2], Is.EqualTo(positions[0]));
        });
    }

    [Test]
    public async Task TC_SITE_R64_01_The_page_hands_the_script_the_option_words_of_all_three_languages_so_saved_answers_load_in_any_of_them()
    {
        var html = MainElement(await RenderAsync("/self-reflection/ur/"));
        var lists = JsonNode.Parse(Attribute(html, "data-options-all"))!.AsArray();

        Assert.Multiple(() =>
        {
            Assert.That(Attribute(html, "data-options-current"), Is.EqualTo("1"));
            Assert.That(lists, Has.Count.EqualTo(3));
            for (var i = 0; i < 3; i++)
            {
                var expected = Source()[Languages[i]]!["section2"]!["questions"]!.AsArray().Select(q => string.Join("|", q!["options"]!.AsArray().Select(o => o!.GetValue<string>())));
                Assert.That(lists[i]!.AsArray().Select(q => string.Join("|", q!.AsArray().Select(o => o!.GetValue<string>()))), Is.EqualTo(expected), Languages[i]);
            }
        });
    }

    [Test]
    public async Task TC_SITE_R64_02_The_three_pages_load_the_page_script_after_the_site_script_and_every_other_page_does_not()
    {
        var pages = await SiteBuilder.CollectAsync(SiteModules.All, FakeApi.Healthy(), CancellationToken.None);

        Assert.Multiple(() =>
        {
            foreach (var language in Languages)
            {
                Assert.That(pages.Single(p => p.Path == $"/self-reflection/{language}/").Script, Is.EqualTo("/self-reflection.js"));
            }

            Assert.That(pages.Where(p => p.Script is not null).Count(), Is.EqualTo(3));
            Assert.That(new FileInfo(Path.Combine(SiteBuilder.StaticFilesFolder, "self-reflection.js")).Length, Is.GreaterThan(1000));
            Assert.DoesNotThrow(() => SiteBuilder.RequireFiles(pages, SiteBuilder.StaticFilesFolder));
        });
    }

    [Test]
    public async Task TC_SITE_R64_03_A_page_that_names_a_script_gets_it_after_site_js_and_the_other_pages_keep_their_two_scripts()
    {
        var reflection = await RenderAsync("/self-reflection/en/");
        var entry = await RenderAsync("/self-reflection/");
        var about = await RenderAsync("/about/");

        Assert.Multiple(() =>
        {
            Assert.That(ScriptTag().Count(reflection), Is.EqualTo(3));
            Assert.That(reflection.IndexOf("<script src=\"/site.js\" defer></script>", StringComparison.Ordinal),
                Is.LessThan(reflection.IndexOf("<script src=\"/self-reflection.js\" defer></script>", StringComparison.Ordinal)));
            Assert.That(ScriptTag().Count(entry), Is.EqualTo(2));
            Assert.That(ScriptTag().Count(about), Is.EqualTo(2));
            Assert.That(entry, Does.Not.Contain("self-reflection.js"));
        });
    }

    [Test]
    public void TC_SITE_R64_04_A_missing_page_script_stops_the_build_and_names_the_file_and_the_page()
    {
        var empty = Directory.CreateTempSubdirectory("tsr-site-test-").FullName;
        var page = new SitePage("/x/", "X", typeof(NotFoundPage), new Dictionary<string, object?>(), Script: "/missing.js");

        var failure = Assert.Throws<SiteBuildException>(() => SiteBuilder.RequireFiles([page], empty));

        Assert.That(failure!.Message, Does.Contain("/missing.js").And.Contain("/x/"));
        Directory.Delete(empty, recursive: true);
    }

    [TestCase("site.js")]
    [TestCase("/../outside.js")]
    public void TC_SITE_R64_05_A_page_script_that_is_not_an_address_inside_the_static_folder_stops_the_build(string script)
    {
        var folder = Directory.CreateTempSubdirectory("tsr-site-test-").FullName;
        var inside = Directory.CreateDirectory(Path.Combine(folder, "static")).FullName;
        File.WriteAllText(Path.Combine(folder, "outside.js"), "x");
        File.WriteAllText(Path.Combine(inside, "site.js"), "x");
        var page = new SitePage("/x/", "X", typeof(NotFoundPage), new Dictionary<string, object?>(), Script: script);

        Assert.Throws<SiteBuildException>(() => SiteBuilder.RequireFiles([page], inside));
        Directory.Delete(folder, recursive: true);
    }

    [TestCase("en")]
    [TestCase("ur")]
    [TestCase("gu")]
    public async Task TC_SITE_R65_01_Each_page_has_a_reset_button_and_the_present_site_s_confirmation_text(string language)
    {
        var html = MainElement(await RenderAsync($"/self-reflection/{language}/"));
        var reset = Source()[language]!["resetButton"]!.GetValue<string>();

        Assert.Multiple(() =>
        {
            Assert.That(Decoded(html), Does.Match(@"<button type=""button""[^>]*data-sr-reset[^>]*>" + Regex.Escape(reset) + "</button>"));
            // Copied from the present page's code, which asks in English on all three pages.
            Assert.That(Attribute(html, "data-confirm-reset"), Is.EqualTo("Are you sure you want to reset all your answers?"));
        });
    }

    [TestCase("en")]
    [TestCase("ur")]
    [TestCase("gu")]
    public async Task TC_SITE_R66_01_The_page_sends_nothing_anywhere_no_form_no_button_that_submits_no_address_and_no_outside_script(string language)
    {
        var html = await RenderAsync($"/self-reflection/{language}/");
        var main = MainElement(html);
        var script = await File.ReadAllTextAsync(Path.Combine(SiteBuilder.StaticFilesFolder, "self-reflection.js"));

        Assert.Multiple(() =>
        {
            Assert.That(main, Does.Not.Contain("<form"));
            Assert.That(main, Does.Not.Contain("action="));
            Assert.That(main, Does.Not.Contain("http://").And.Not.Contain("https://"));
            Assert.That(main, Does.Not.Contain("<iframe").And.Not.Contain("<img").And.Not.Contain("<script"));
            Assert.That(Regex.Matches(main, @"<button\b[^>]*>").Where(b => !b.Value.Contains("type=\"button\"", StringComparison.Ordinal)), Is.Empty);
            Assert.That(Regex.Matches(html, @"<script[^>]*\ssrc=""([^""]*)""").Select(m => m.Groups[1].Value), Is.EqualTo(new List<string> { "/site.js", "/self-reflection.js" }));
            Assert.That(Regex.Matches(main, @"href=""([^""]*)""").Select(m => m.Groups[1].Value), Has.All.StartWith("/self-reflection/"));
            foreach (var word in new List<string> { "fetch", "XMLHttpRequest", "sendBeacon", "WebSocket", "EventSource", "document.cookie", ".submit(" })
            {
                Assert.That(script, Does.Not.Contain(word), word);
            }
        });
    }

    [Test]
    public async Task TC_SITE_R67_01_The_entry_page_sends_the_reader_to_the_english_page_with_a_refresh_and_a_visible_link()
    {
        var html = await RenderAsync("/self-reflection/");
        var about = await RenderAsync("/about/");

        Assert.Multiple(() =>
        {
            Assert.That(html.IndexOf("<meta http-equiv=\"refresh\" content=\"0; url=/self-reflection/en/\" />", StringComparison.Ordinal),
                Is.InRange(0, html.IndexOf("</head>", StringComparison.Ordinal)));
            Assert.That(html, Does.Match(@"<a href=""/self-reflection/en/""[^>]*>[^<]+</a>"));
            Assert.That(about, Does.Not.Contain("http-equiv"));
        });
    }

    [Test]
    public async Task TC_SITE_R67_02_The_language_links_lead_to_the_three_pages_and_mark_the_current_one()
    {
        var html = MainElement(await RenderAsync("/self-reflection/ur/"));

        Assert.Multiple(() =>
        {
            Assert.That(Regex.Matches(html, @"<a href=""(/self-reflection/\w+/)""[^>]*>([^<]*)</a>").Select(m => m.Groups[1].Value + " " + m.Groups[2].Value),
                Is.EqualTo(new List<string> { "/self-reflection/en/ English", "/self-reflection/ur/ اردو", "/self-reflection/gu/ ગુજરાતી" }));
            Assert.That(Regex.Match(html, @"<a href=""/self-reflection/ur/""[^>]*>").Value, Does.Contain("aria-current=\"page\"").And.Contain("bg-emerald-700 text-white"));
            Assert.That(Regex.Match(html, @"<a href=""/self-reflection/en/""[^>]*>").Value, Does.Not.Contain("aria-current"));
        });
    }

    [TestCase("en")]
    [TestCase("ur")]
    [TestCase("gu")]
    public async Task TC_SITE_R69_01_With_scripts_off_the_whole_form_shows_and_a_noscript_line_says_the_scores_need_scripts(string language)
    {
        var main = MainElement(await RenderAsync($"/self-reflection/{language}/"));
        var hidden = HiddenElement().Matches(main).Select(m => m.Value).ToList();

        Assert.Multiple(() =>
        {
            Assert.That(main, Does.Match(@"<noscript>[\s\S]*?scores[\s\S]*?scripts[\s\S]*?</noscript>"));
            // Only what shows a number, or what the script switches between, is written hidden; no question, option or field is.
            Assert.That(hidden, Is.Not.Empty);
            Assert.That(hidden.Where(h => !Regex.IsMatch(h, "data-sr-(needs-script|dot|tier|weakest|focus)")), Is.Empty);
            Assert.That(Regex.IsMatch(main, @"<(section|button|input|textarea)[^>]*\shidden"), Is.False);
        });
    }

    [Test]
    public void TC_SITE_R11_01_The_classes_that_depend_on_the_direction_are_listed_for_the_stylesheet_test()
    {
        Assert.That(SelfReflection.AllClasses.SelectMany(c => c.Split(' ', StringSplitOptions.RemoveEmptyEntries)),
            Is.SupersetOf(new List<string> { "flex-row-reverse", "pr-5", "pl-5", "right-0", "left-0", "text-right", "text-left" }));
    }
}
