using System.Text.RegularExpressions;
using Tsr.Content.Site;
using Tsr.Shared.Site;
using NUnit.Framework;

namespace Tsr.Host.Site.Tests;

/// <summary>
/// Issue 65, SITE-R20 to R22: the About and Donate pages. Their text is fixed in the components, as in the present website's code.
/// The bank values are not repeated here: each label must be followed by a value in its own row.
/// </summary>
public sealed partial class AboutDonateTests
{
    private const string QrImage = "/images/donate-qr.jpeg";

    /// <summary>One row of the bank details: the label's span, then the value's span, inside one div.</summary>
    [GeneratedRegex(@"<div class=""[^""]*border-l-4[^""]*"">\s*<span class=""[^""]*"">(?<label>[^<]+)</span>\s*<span class=""[^""]*"">(?<value>[^<]+)</span>\s*</div>")]
    private static partial Regex BankRow();

    private static readonly string[] Labels = ["Account Name", "Account Number", "IFSC Code", "Branch"];

    private static async Task<IReadOnlyList<SitePage>> PagesAsync() =>
        await SiteBuilder.CollectAsync(SiteModules.All, FakeApi.Healthy(), CancellationToken.None);

    private static async Task<string> RenderAsync(string path)
    {
        var api = FakeApi.Healthy();
        var pages = await SiteBuilder.CollectAsync(SiteModules.All, api, CancellationToken.None);
        var menu = await ContentSite.MenuAsync(api, CancellationToken.None);
        return await SiteBuilder.RenderAsync(pages.Single(p => p.Path == path), menu);
    }

    [Test]
    public async Task TC_SITE_R20_01_The_about_page_has_the_present_site_s_title_headings_and_text_in_the_frame()
    {
        var html = await RenderAsync("/about/");

        Assert.Multiple(() =>
        {
            Assert.That(html, Does.Contain("<title>About Us | The Strong Rope</title>"));
            Assert.That(html, Does.Contain("content=\"Learn about The Strong Rope - a cultural, religious, and social organization promoting the teachings of the Holy Quran and Ahlul Bait.\""));
            Assert.That(html, Does.Contain("<h1 class=\"text-4xl md:text-5xl font-bold text-gray-900 dark:text-gray-100 mb-4\">About Us</h1>"));
            Assert.That(html, Does.Match(@"<h2 class=""text-2xl font-bold text-white flex items-center gap-3"">\s*<svg[^>]*>\s*<path[^>]*>(</path>)?\s*</svg>\s*Who We Are\?\s*</h2>"));
            Assert.That(html, Does.Match(@"</svg>\s*What We Do\?\s*</h2>"));
            Assert.That(html, Does.Contain(">A cultural, religious, and social organization</p>"));
            Assert.That(html, Does.Contain(">Formed by like-minded individuals</p>"));
            Assert.That(html, Does.Contain(">Under the guidance of renowned religious scholars</p>"));
            Assert.That(html, Does.Contain(">Ensure to fasten to the teachings of the Holy Quran and immaculate Ahlul Bait (peace be on them)</p>"));
            Assert.That(html, Does.Contain(">Culturally promote and defend Shia Ithna Ashari Imamate faith</p>"));
            Assert.That(html, Does.Contain(">On all platforms including but not limited to Print Media, Audio-Visual Media, Social Media, etc.</p>"));
            Assert.That(html, Does.Contain(">Strive to develop a deeper understanding of different religious traditions to enhance communal harmony</p>"));
            Assert.That(html, Does.Contain(">Bring communities together and build a more compassionate and just world</p>"));
            Assert.That(html, Does.Contain(">Prepare for the early reappearance of the Twelfth Imam, Imam al-Mahdi (may Allah hasten his reappearance)</p>"));
            Assert.That(Regex.Count(html, "<li class=\"flex items-start gap-4\">"), Is.EqualTo(9));
            // The frame (SITE-R11): the header's menu button and the footer.
            Assert.That(html, Does.Contain("aria-label=\"Menu\""));
            Assert.That(html, Does.Contain("&#xA9; " + DateTime.UtcNow.Year + " The Strong Rope"));
        });
    }

    [Test]
    public async Task TC_SITE_R20_02_The_donate_page_has_the_present_site_s_title_headings_and_text_in_the_frame()
    {
        var html = await RenderAsync("/donate/");

        Assert.Multiple(() =>
        {
            Assert.That(html, Does.Contain("<title>Donate | The Strong Rope</title>"));
            Assert.That(html, Does.Contain("content=\"Donate to The Strong Rope. Scan the QR code, or use the bank details on this page for a direct transfer.\""));
            Assert.That(html, Does.Contain("<h1 class=\"text-4xl md:text-5xl font-bold bg-gradient-to-r from-purple-600 to-blue-600 dark:from-purple-400 dark:to-blue-400 bg-clip-text text-transparent\">Donate</h1>"));
            Assert.That(html, Does.Contain(">Bank Transfer Details</h2>"));
            Assert.That(html, Does.Contain(">Scan the QR code to donate</p>"));
            Assert.That(html, Does.Contain(">Or use the bank details below for a direct transfer.</p>"));
            Assert.That(html, Does.Contain("aria-label=\"Menu\""));
        });
    }

    [Test]
    public async Task TC_SITE_R20_03_The_frame_s_links_to_the_two_pages_are_addresses_the_site_publishes()
    {
        var paths = (await PagesAsync()).Select(p => p.Path).ToList();
        var html = await RenderAsync("/about/");

        Assert.Multiple(() =>
        {
            Assert.That(paths, Does.Contain("/about/"));
            Assert.That(paths, Does.Contain("/donate/"));
            // With the closing slash, as every link of the site, so the server answers the page and not a redirect.
            Assert.That(Regex.Count(html, "href=\"/about/\""), Is.EqualTo(1));
            Assert.That(Regex.Count(html, "href=\"/donate/\""), Is.EqualTo(2));
            Assert.That(html, Does.Not.Contain("href=\"/about\""));
            Assert.That(html, Does.Not.Contain("href=\"/donate\""));
        });
    }

    [Test]
    public async Task TC_SITE_R21_01_The_donate_page_shows_the_qr_image_and_each_bank_value_under_its_label()
    {
        var html = await RenderAsync("/donate/");
        var rows = BankRow().Matches(html);

        Assert.Multiple(() =>
        {
            Assert.That(html, Does.Contain("<img src=\"" + QrImage + "\" alt=\"QR code for donations to Strong Rope Foundation\" width=\"300\" height=\"370\""));
            Assert.That(rows.Select(row => row.Groups["label"].Value), Is.EqualTo(Labels));
            Assert.That(rows.Select(row => row.Groups["value"].Value.Trim()), Has.All.Not.Empty);
            // The image comes before the details, the details after their heading.
            Assert.That(html.IndexOf(QrImage, StringComparison.Ordinal), Is.LessThan(html.IndexOf("Bank Transfer Details", StringComparison.Ordinal)));
            Assert.That(html.IndexOf("Bank Transfer Details", StringComparison.Ordinal), Is.LessThan(rows[0].Index));
        });
    }

    [Test]
    public async Task TC_SITE_R22_01_The_donate_page_names_the_qr_image_as_a_file_it_needs_and_the_generator_ships_it()
    {
        var pages = await PagesAsync();

        Assert.Multiple(() =>
        {
            Assert.That(pages.Single(p => p.Path == "/donate/").Files, Is.EqualTo(new[] { QrImage }));
            Assert.That(new FileInfo(Path.Combine(SiteBuilder.StaticFilesFolder, "images", "donate-qr.jpeg")).Length, Is.GreaterThan(1000));
            Assert.DoesNotThrow(() => SiteBuilder.RequireFiles(pages, SiteBuilder.StaticFilesFolder));
        });
    }

    [Test]
    public async Task TC_SITE_R22_02_A_missing_qr_image_stops_the_build_and_names_the_file()
    {
        var pages = await PagesAsync();
        var empty = Directory.CreateTempSubdirectory("tsr-site-test-").FullName;

        var failure = Assert.Throws<SiteBuildException>(() => SiteBuilder.RequireFiles(pages, empty));

        Assert.That(failure!.Message, Does.Contain(QrImage).And.Contain("/donate/"));
        Directory.Delete(empty, recursive: true);
    }

    [TestCase("images/donate-qr.jpeg")]
    [TestCase("/../outside.jpeg")]
    [TestCase("/images/../../outside.jpeg")]
    public void TC_SITE_R22_03_A_needed_file_that_is_not_an_address_inside_the_static_folder_stops_the_build(string file)
    {
        var folder = Directory.CreateTempSubdirectory("tsr-site-test-").FullName;
        var inside = Directory.CreateDirectory(Path.Combine(folder, "static")).FullName;
        File.WriteAllText(Path.Combine(folder, "outside.jpeg"), "x");
        Directory.CreateDirectory(Path.Combine(inside, "images"));
        File.WriteAllText(Path.Combine(inside, "images", "donate-qr.jpeg"), "x");
        var page = new SitePage("/x/", "X", typeof(NotFoundPage), new Dictionary<string, object?>(), Files: [file]);

        Assert.Throws<SiteBuildException>(() => SiteBuilder.RequireFiles([page], inside));
        Directory.Delete(folder, recursive: true);
    }
}
