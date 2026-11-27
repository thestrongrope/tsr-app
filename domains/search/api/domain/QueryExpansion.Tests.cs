using NUnit.Framework;

namespace Tsr.Search.Api.Domain;

/// <summary>
/// TC-SRCH-R1-04: the query helpers of the article and lecture search equal tsr-web's. The expected values were computed once by running tsr-web's own
/// functions (<c>normalizeArabicTransliteration</c>, <c>extractSearchTerms</c> and the synonym expansion of <c>searchArticlesElasticsearch</c>,
/// <c>web/src/app/api/lib/search-service.ts</c> at commit 109927c) in node on each input, and are stored here as they came out.
/// </summary>
[TestFixture]
internal sealed class QueryExpansionTests
{
    private sealed record Case(string Input, string Normalized, string Expanded, string[] Terms, string[] TermQueries);

    private static readonly Case[] Cases =
    [
        new("7usain", "husain", "7usain husain hussain husayn hussein", ["7usain"], ["7usain "]),
        new("Fatimah", "fatima", "Fatimah fatima", ["fatimah"], ["fatimah "]),
        new("ameerul momineen tears", "amirul mominin tears", "ameerul momineen tears amirul mominin tears weep weeping crying cry imam ali ali ibn abi talib ali", ["imam ali", "tears"], ["imam ali ameerul momineen ali ibn abi talib amirul momineen", "tears weep weeping crying cry"]),
        new("Imam Husain", "imam husain", "Imam Husain imam husain imam hussain hussain husain aba abdillah hussain husayn hussein", ["imam husain"], ["imam husain imam hussain hussain husain aba abdillah"]),
        new("of the", "of se", "of the of se", [], []),
        new("  Hussein  ", "  husain  ", "  Hussein     husain   hussain husayn hussein", ["hussein"], ["hussein "]),
        new("fight", "figt", "fight figt war battle conflict combat", ["fight"], ["fight war battle conflict combat"]),
        new("Aba Abdillah qaim", "aba abdillah qaim", "Aba Abdillah qaim aba abdillah qaim imam mahdi hujjat sahib al-zaman", ["imam husain", "imam mahdi"], ["imam husain imam hussain hussain husain aba abdillah", "imam mahdi qaim hujjat sahib al-zaman imam zamana"]),
        new("3ali 5alid 6alib 8uran 9adiq", "ali kalid talib quran sadiq", "3ali 5alid 6alib 8uran 9adiq ali kalid talib quran sadiq sadeq sadek saadiq", ["3ali", "5alid", "6alib", "8uran", "9adiq"], ["3ali ", "5alid ", "6alib ", "8uran ", "9adiq "]),
        new("faatima", "fatima", "faatima fatima", ["faatima"], ["faatima "]),
        new("mooosa huusain aliiii", "musa husain ali", "mooosa huusain aliiii musa husain ali hussain husayn hussein", ["mooosa", "huusain", "aliiii"], ["mooosa ", "huusain ", "aliiii "]),
        new("dhahabi", "zahabi", "dhahabi zahabi zahabi dahabi thahabi dhahabi dahabi thahabi", ["dhahabi"], ["dhahabi zahabi dahabi thahabi"]),
        new("jafar", "jafar", "jafar jafar jaafar ja'far jaffar", ["jafar"], ["jafar jaafar ja'far jaffar"]),
        new("Sheikh Ghulam", "seik gulam", "Sheikh Ghulam seik gulam", ["sheikh", "ghulam"], ["sheikh ", "ghulam "]),
        new("fatemeh", "fatema", "fatemeh fatema", ["fatemeh"], ["fatemeh "]),
        new("aliy", "alii", "aliy alii", ["aliy"], ["aliy "]),
        new("husey", "husei", "husey husei", ["husey"], ["husey "]),
        new("Hussain\n", "husain\n", "Hussain\n husain\n hussain husayn hussein husain husayn hussein", ["hussain"], ["hussain husain husayn hussein"]),
        new("imam", "imam", "imam imam", ["imam"], ["imam "]),
        new("imam ali imam", "imam ali imam", "imam ali imam imam ali imam ameerul momineen ali ibn abi talib amirul momineen", ["imam ali", "imam"], ["imam ali ameerul momineen ali ibn abi talib amirul momineen", "imam "]),
        new("a.s. peace upon him", "a.s. peace upon him", "a.s. peace upon him a.s. peace upon him", [], []),
        new("sahib al-zaman amirul momineen amirul momineen", "sahib al-zaman amirul mominin amirul mominin", "sahib al-zaman amirul momineen amirul momineen sahib al-zaman amirul mominin amirul mominin", ["imam mahdi", "imam ali", "amirul", "momineen"], ["imam mahdi qaim hujjat sahib al-zaman imam zamana", "imam ali ameerul momineen ali ibn abi talib amirul momineen", "amirul ", "momineen "]),
        new("\u0639\u0644\u064a\u0651", "\u0639\u0644\u064a\u0651", "\u0639\u0644\u064a\u0651 \u0639\u0644\u064a\u0651", ["\u0639\u0644\u064a\u0651"], ["\u0639\u0644\u064a\u0651 "]),
        new("tears\u00a0weep", "tears\u00a0wi", "tears\u00a0weep tears\u00a0wi weep weeping crying cry tears weeping crying cry", ["tears", "weep"], ["tears weep weeping crying cry", "weep tears weeping crying cry"]),
        new("Imam Mahdi qaim qaim", "imam mahdi qaim qaim", "Imam Mahdi qaim qaim imam mahdi qaim qaim qaim hujjat sahib al-zaman imam zamana imam mahdi hujjat sahib al-zaman", ["imam mahdi", "imam mahdi", "qaim"], ["imam mahdi qaim hujjat sahib al-zaman imam zamana", "imam mahdi qaim hujjat sahib al-zaman imam zamana", "qaim imam mahdi hujjat sahib al-zaman"]),
        new("Lady Fatima and the Zahra", "lady fatima and se zahra", "Lady Fatima and the Zahra lady fatima and se zahra fatimah fatemah zahra hazrat fatima", ["lady", "fatima", "zahra"], ["lady ", "fatima ", "zahra "]),
        new("patience", "patience", "patience patience", ["patience"], ["patience "]),
        new("IMAM HUSSAIN karbala", "imam husain karbala", "IMAM HUSSAIN karbala imam husain karbala imam hussain hussain husain aba abdillah imam husain hussain husain aba abdillah hussain husayn hussein husain husayn hussein", ["imam hussain", "karbala"], ["imam hussain imam husain hussain husain aba abdillah", "karbala "]),
        new("sadiq ja'far", "sadiq ja'far", "sadiq ja'far sadiq ja'far sadeq sadek saadiq", ["sadiq", "ja'far"], ["sadiq sadeq sadek saadiq", "ja'far "]),
    ];

    public static IEnumerable<TestCaseData> Inputs => Cases.Select(c => new TestCaseData(c).SetArgDisplayNames(c.Input));

    [TestCaseSource(nameof(Inputs))]
    public void Normalize_equals_the_website(object testCase) => Assert.That(QueryExpansion.Normalize(((Case)testCase).Input), Is.EqualTo(((Case)testCase).Normalized));

    [TestCaseSource(nameof(Inputs))]
    public void Expand_equals_the_website(object testCase) => Assert.That(QueryExpansion.Expand(((Case)testCase).Input), Is.EqualTo(((Case)testCase).Expanded));

    [TestCaseSource(nameof(Inputs))]
    public void Terms_equal_the_website(object testCase) => Assert.That(QueryExpansion.ExtractTerms(((Case)testCase).Input), Is.EqualTo(((Case)testCase).Terms));

    [TestCaseSource(nameof(Inputs))]
    public void Term_queries_equal_the_website(object testCase) =>
        Assert.That(QueryExpansion.ExtractTerms(((Case)testCase).Input).Select(QueryExpansion.TermQuery), Is.EqualTo(((Case)testCase).TermQueries));

    [Test]
    public void A_line_break_after_the_last_letters_does_not_end_the_text_for_the_end_rules()
    {
        // JavaScript's $ (no m flag) matches only at the very end; the .NET $ would also match before a final line break.
        Assert.That(QueryExpansion.Normalize("fatimah\n"), Is.EqualTo("fatimah\n"));
    }

    [Test]
    public void A_term_named_like_an_object_member_has_no_synonyms()
    {
        Assert.That(QueryExpansion.TermQuery("constructor"), Is.EqualTo("constructor "));
    }
}
