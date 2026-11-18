using System.Text;
using System.Text.RegularExpressions;
using Tsr.Content.Site;
using NUnit.Framework;

namespace Tsr.Host.Site.Tests;

/// <summary>
/// TC-SITE-R11-01. The stylesheet is compiled by hand (tools/site-css.sh) and committed, so it can go stale: every class
/// the pages, the article body and the script use must have a rule in hosts/site/wwwroot/site.css.
/// </summary>
public sealed partial class StylesheetTests
{
    private static readonly string Root = RepoRoot();

    private static readonly string Css = File.ReadAllText(Path.Combine(Root, "hosts", "site", "wwwroot", "site.css"));

    [GeneratedRegex("class=\"(?<classes>[^\"]*)\"")]
    private static partial Regex ClassAttribute();

    [GeneratedRegex(@"classList\.(add|remove|toggle)\('(?<class>[^']+)'")]
    private static partial Regex ScriptClass();

    public static IEnumerable<string> UsedClasses()
    {
        var folders = new[] { Path.Combine(Root, "hosts", "site") }
            .Concat(Directory.EnumerateDirectories(Path.Combine(Root, "domains")).Select(d => Path.Combine(d, "site")))
            .Where(Directory.Exists);
        var inMarkup = folders
            .SelectMany(folder => Directory.EnumerateFiles(folder, "*.razor"))
            .SelectMany(file => ClassAttribute().Matches(File.ReadAllText(file)))
            .SelectMany(match => match.Groups["classes"].Value.Split(' ', StringSplitOptions.RemoveEmptyEntries))
            // A Razor expression inside a class attribute is not a class; what it writes comes from the lists below.
            .Where(name => !name.Contains('@', StringComparison.Ordinal) && !name.Contains('(', StringComparison.Ordinal));
        var inScript = ScriptClass().Matches(File.ReadAllText(Path.Combine(Root, "hosts", "site", "wwwroot", "site.js")))
            .Select(match => match.Groups["class"].Value);
        var inBody = ArticleBody.AllClasses.SelectMany(classes => classes.Split(' ', StringSplitOptions.RemoveEmptyEntries));
        return inMarkup.Concat(inScript).Concat(inBody).Distinct(StringComparer.Ordinal).Order(StringComparer.Ordinal);
    }

    [Test]
    public void The_pages_use_classes() =>
        Assert.That(UsedClasses().Count(), Is.GreaterThan(100));

    [TestCaseSource(nameof(UsedClasses))]
    public void A_class_the_site_uses_has_a_rule_in_the_committed_stylesheet(string name)
    {
        // "dark" is set on <html> by the script and only ever read inside other selectors; "group" likewise.
        var selector = new Regex(Regex.Escape("." + CssEscape(name)) + @"(?![\w\\-])");

        Assert.That(selector.IsMatch(Css), Is.True, $"no rule for '{name}' in hosts/site/wwwroot/site.css: run tools/site-css.sh");
    }

    /// <summary>A class name as a stylesheet writes it: every character that is not a letter, a digit, '-' or '_' takes a backslash.</summary>
    private static string CssEscape(string name)
    {
        var escaped = new StringBuilder();
        foreach (var c in name)
        {
            if (!char.IsAsciiLetterOrDigit(c) && c != '-' && c != '_')
            {
                escaped.Append('\\');
            }

            escaped.Append(c);
        }

        return escaped.ToString();
    }

    private static string RepoRoot()
    {
        var folder = new DirectoryInfo(AppContext.BaseDirectory);
        while (folder is not null && !File.Exists(Path.Combine(folder.FullName, "TsrApp.slnx")))
        {
            folder = folder.Parent;
        }

        return folder?.FullName ?? throw new InvalidOperationException("TsrApp.slnx was not found above " + AppContext.BaseDirectory);
    }
}
