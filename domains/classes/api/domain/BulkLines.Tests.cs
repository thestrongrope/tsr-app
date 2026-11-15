using NUnit.Framework;

namespace Tsr.Classes.Api.Domain;

[TestFixture]
internal sealed class BulkLinesTests
{
    private static readonly IReadOnlyDictionary<int, string> NoResolutions = new Dictionary<int, string>();
    private static readonly IReadOnlyDictionary<string, BulkLines.Member> NoMatches = new Dictionary<string, BulkLines.Member>();

    private static BulkLines.Result Run(
        string[] lines,
        IReadOnlyDictionary<int, string>? resolutions = null,
        IReadOnlyDictionary<string, BulkLines.Member>? matches = null,
        int[]? enrolled = null,
        string[]? names = null) =>
        BulkLines.Classify(lines, resolutions ?? NoResolutions, matches ?? NoMatches, (enrolled ?? []).ToHashSet(), (names ?? []).Select(BulkLines.NameKey).ToHashSet());

    [TestCase("Aslam Khan", "Aslam Khan", "", null)]
    [TestCase("  Aslam Khan  ,  +91 000-0001 234 ", "Aslam Khan", "+910000001234", null)]
    [TestCase("Aslam,", "Aslam", "", null)]
    [TestCase("Aslam, 12, 34", "Aslam", "", "The mobile number is not valid.")]
    [TestCase(", +910000001234", "", "", "The name is missing.")]
    [TestCase("Aslam, 123456", "Aslam", "", "The mobile number is not valid.")]
    [TestCase("Aslam, 1234567", "Aslam", "1234567", null)]
    [TestCase("Aslam, 1234567890123456", "Aslam", "", "The mobile number is not valid.")]
    [TestCase("Aslam, 12345x7890", "Aslam", "", "The mobile number is not valid.")]
    [TestCase("Aslam, 91+0000001234", "Aslam", "", "The mobile number is not valid.")]
    public void A_line_is_a_name_then_an_optional_mobile_split_at_the_first_comma(string line, string name, string mobile, string? error)
    {
        var parsed = BulkLines.Parse(line);

        Assert.That(parsed.Name, Is.EqualTo(name));
        Assert.That(parsed.Mobile, Is.EqualTo(mobile));
        Assert.That(parsed.Error, Is.EqualTo(error));
    }

    [Test]
    public void A_name_of_a_hundred_characters_is_kept_and_a_hundred_and_one_is_refused()
    {
        Assert.That(BulkLines.Parse(new string('a', 100)).Error, Is.Null);
        Assert.That(BulkLines.Parse(new string('a', 101)).Error, Is.EqualTo("The name is longer than 100 characters."));
    }

    [Test]
    public void The_name_length_counts_characters_not_bytes()
    {
        Assert.That(BulkLines.Parse(new string('é', 100)).Error, Is.Null);
    }

    [TestCase("  Aslam   KHAN ", "aslam khan")]
    [TestCase("Aslam\tKhan", "aslam khan")]
    public void The_name_key_ignores_case_and_runs_of_white_space(string name, string key) =>
        Assert.That(BulkLines.NameKey(name), Is.EqualTo(key));

    [TestCase("Aslam Khan", "Aslam K.")]
    [TestCase("Aslam", "Aslam")]
    [TestCase("  Aslam   Bin  khan ", "Aslam k.")]
    [TestCase("", "")]
    public void A_masked_name_is_the_first_name_and_the_last_initial(string name, string masked) =>
        Assert.That(BulkLines.MaskedName(name), Is.EqualTo(masked));

    [TestCase("+910000001234", "0000001234")]
    [TestCase("1234567", "1234567")]
    [TestCase("00 1234-5678901", "2345678901")]
    public void The_mobile_key_is_the_last_ten_digits(string mobile, string key) =>
        Assert.That(BulkLines.MobileKey(mobile), Is.EqualTo(key));

    [Test]
    public void Blank_lines_are_ignored_and_line_numbers_are_positions_from_one()
    {
        var result = Run(["", "Aslam Khan", "   ", "Bilal"]);

        Assert.That(result.Lines.Select(l => l.Number), Is.EqualTo(new List<int> { 2, 4 }));
        Assert.That(result.Status, Is.EqualTo("added"));
        Assert.That(result.Plan.Select(p => p.Line), Is.EqualTo(new List<int> { 2, 4 }));
        Assert.That(result.Lines.Select(l => l.Status), Is.All.EqualTo("ready"));
    }

    [Test]
    public void An_invalid_line_is_rejected_with_its_reason_and_the_others_still_go_ahead()
    {
        var result = Run(["Aslam, 12", "Bilal"]);

        Assert.That(result.Lines[0], Is.EqualTo(new BulkLines.Line(1, "Aslam", "rejected", "The mobile number is not valid.", null)));
        Assert.That(result.Plan.Select(p => p.Line), Is.EqualTo(new List<int> { 2 }));
    }

    [Test]
    public void Only_invalid_lines_leave_nothing_to_write()
    {
        var result = Run([", 123"]);

        Assert.That(result.Status, Is.EqualTo("none"));
        Assert.That(result.Plan, Is.Empty);
    }

    [Test]
    public void A_name_already_on_the_roster_is_flagged_until_the_caller_chooses_add_or_skip()
    {
        var pending = Run(["aslam  KHAN"], names: ["Aslam Khan"]);
        Assert.That(pending.Status, Is.EqualTo("confirm"));
        Assert.That(pending.Lines[0].Status, Is.EqualTo("duplicate_name"));
        Assert.That(pending.Plan, Is.Empty);

        var add = Run(["aslam khan"], new Dictionary<int, string> { [1] = "add" }, names: ["Aslam Khan"]);
        Assert.That(add.Status, Is.EqualTo("added"));
        Assert.That(add.Plan.Single().Name, Is.EqualTo("aslam khan"));

        var skip = Run(["aslam khan"], new Dictionary<int, string> { [1] = "skip" }, names: ["Aslam Khan"]);
        Assert.That(skip.Status, Is.EqualTo("none"));
        Assert.That(skip.Lines[0], Is.EqualTo(new BulkLines.Line(1, "aslam khan", "rejected", "Skipped.", null)));
    }

    [Test]
    public void The_same_name_twice_in_one_paste_flags_the_second_line()
    {
        var result = Run(["Aslam Khan", "ASLAM KHAN"]);

        Assert.That(result.Status, Is.EqualTo("confirm"));
        Assert.That(result.Lines.Select(l => l.Status), Is.EqualTo(new List<string> { "ready", "duplicate_name" }));
    }

    [Test]
    public void A_duplicate_name_does_not_take_enrol_as_its_answer()
    {
        var result = Run(["Aslam Khan"], new Dictionary<int, string> { [1] = "enrol" }, names: ["Aslam Khan"]);

        Assert.That(result.Status, Is.EqualTo("confirm"));
        Assert.That(result.Lines[0].Status, Is.EqualTo("duplicate_name"));
    }

    private static readonly IReadOnlyDictionary<string, BulkLines.Member> Match = new Dictionary<string, BulkLines.Member>
    {
        ["0000001234"] = new(900701, "Gents Member"),
    };

    [Test]
    public void A_mobile_that_matches_a_member_is_flagged_with_the_masked_name_and_no_token()
    {
        var result = Run(["Somebody Else, +91 0000001234"], matches: Match);

        Assert.That(result.Status, Is.EqualTo("confirm"));
        Assert.That(result.Lines[0], Is.EqualTo(new BulkLines.Line(1, "Somebody Else", "mobile_match", null, "Gents M.")));
    }

    [TestCase("enrol")]
    [TestCase("add")]
    [TestCase("skip")]
    public void A_mobile_match_takes_enrol_add_or_skip(string choice)
    {
        var result = Run(["Somebody Else, +910000001234"], new Dictionary<int, string> { [1] = choice }, Match);

        Assert.That(result.Status, Is.EqualTo(choice == "skip" ? "none" : "added"));
        Assert.That(result.Plan.SingleOrDefault()?.EnrolToken, Is.EqualTo(choice == "enrol" ? 900701 : null));
    }

    [Test]
    public void An_enrolled_match_names_the_masked_member()
    {
        var result = Run(["Somebody Else, +910000001234"], new Dictionary<int, string> { [1] = "enrol" }, Match);

        Assert.That(result.Lines[0].MemberName, Is.EqualTo("Gents M."));
    }

    [Test]
    public void A_mobile_match_who_is_already_in_the_class_is_rejected_whatever_the_choice()
    {
        var result = Run(["Somebody Else, +910000001234"], new Dictionary<int, string> { [1] = "enrol" }, Match, enrolled: [900701]);

        Assert.That(result.Lines[0], Is.EqualTo(new BulkLines.Line(1, "Somebody Else", "rejected", "That member is already in this class.", null)));
        Assert.That(result.Status, Is.EqualTo("none"));
    }

    [Test]
    public void Enrolling_the_same_member_on_two_lines_rejects_the_second()
    {
        var all = new Dictionary<int, string> { [1] = "enrol", [2] = "enrol" };
        var result = Run(["One, +910000001234", "Two, 0000001234"], all, Match);

        Assert.That(result.Lines.Select(l => l.Status), Is.EqualTo(new List<string> { "ready", "rejected" }));
        Assert.That(result.Plan, Has.Count.EqualTo(1));
    }

    [Test]
    public void A_choice_for_a_line_that_is_not_flagged_is_ignored()
    {
        var result = Run(["Fresh Name"], new Dictionary<int, string> { [1] = "skip" });

        Assert.That(result.Plan, Has.Count.EqualTo(1));
    }

    [Test]
    public void A_flagged_line_holds_the_whole_batch_back_even_when_others_are_valid()
    {
        var result = Run(["Fresh Name", "Somebody, +910000001234"], matches: Match);

        Assert.That(result.Status, Is.EqualTo("confirm"));
        Assert.That(result.Plan, Is.Empty);
        Assert.That(result.Lines.Select(l => l.Status), Is.EqualTo(new List<string> { "ready", "mobile_match" }));
    }
}
