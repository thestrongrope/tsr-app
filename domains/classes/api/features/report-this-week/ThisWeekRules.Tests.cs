using NUnit.Framework;
using Tsr.Classes.Api.Domain;

namespace Tsr.Classes.Api.Features.ReportThisWeek;

[TestFixture]
internal sealed class ThisWeekRulesTests
{
    private static DateOnly D(string text) => DateOnly.ParseExact(text, "yyyy-MM-dd");

    // Nine Sundays ending 2025-11-09 (the week of the review is 2025-11-09 to 11-15 "last completed", the others before it).
    private static readonly DateOnly[] Starts = [.. Enumerable.Range(0, 9).Select(i => D("2025-09-21").AddDays(7 * i))];

    private static IReadOnlyDictionary<string, bool[]> NoSubjects => new Dictionary<string, bool[]>();

    private static ThisWeekRules.ClassInput Class(int id, string[] cells, string started = "2025-01-01", IReadOnlyDictionary<string, bool[]>? subjects = null, string? mobile = "+1") =>
        new(id, "C" + id, "MIQDAD", "T", 7, mobile, D(started), cells, subjects ?? NoSubjects);

    private static string[] Cells(string newest, params string[] before) => [.. Enumerable.Repeat("Yes", 9 - before.Length - 1), .. before, newest];

    [Test]
    public void A_streak_counts_the_newest_weeks_not_held_and_ends_at_the_first_other_cell()
    {
        Assert.That(ThisWeekRules.MissedStreak(["Yes", "No", "No"]), Is.EqualTo(2));
        Assert.That(ThisWeekRules.MissedStreak(["No", "NF", "No"]), Is.EqualTo(1));
        Assert.That(ThisWeekRules.MissedStreak(["No", "No", "Yes (2)"]), Is.EqualTo(0));
        Assert.That(ThisWeekRules.MissedStreak(["No", "No", "n/a"]), Is.EqualTo(0));
        Assert.That(ThisWeekRules.MissedStreak([]), Is.EqualTo(0));
    }

    [Test]
    public void A_quiet_streak_counts_the_newest_weeks_without_the_subject()
    {
        Assert.That(ThisWeekRules.QuietStreak([true, false, false]), Is.EqualTo(2));
        Assert.That(ThisWeekRules.QuietStreak([false, false, true]), Is.EqualTo(0));
        Assert.That(ThisWeekRules.QuietStreak([false, false]), Is.EqualTo(2));
    }

    [TestCase(0, null)]
    [TestCase(1, null)]
    [TestCase(2, "message")]
    [TestCase(3, "message")]
    [TestCase(4, "call")]
    [TestCase(9, "call")]
    public void A_streak_asks_for_nothing_a_message_or_a_call(int streak, string? expected) =>
        Assert.That(ThisWeekRules.ConductionAction(streak), Is.EqualTo(expected));

    [Test]
    public void The_recent_weeks_are_the_last_ones_over_with_their_position_among_all_the_weeks()
    {
        var months = WeeklyGrid.Months(D("2025-10-26"), D("2025-11-22"));
        var weeks = ThisWeekRules.RecentWeeks(months, D("2025-11-15"), 3);
        Assert.That(
            weeks.Select(w => (w.Start, w.End, w.Position)).ToArray(),
            Is.EqualTo((ValueTuple<DateOnly, DateOnly, int>[])[(D("2025-10-26"), D("2025-11-01"), 0), (D("2025-11-02"), D("2025-11-08"), 1), (D("2025-11-09"), D("2025-11-15"), 2)]));

        var few = ThisWeekRules.RecentWeeks(months, D("2025-11-08"), 9);
        Assert.That(few.Select(w => w.Position).ToArray(), Is.EqualTo((int[])[0, 1]));
    }

    [Test]
    public void The_subjects_taught_are_flagged_per_week_and_a_class_with_no_session_is_absent()
    {
        var weeks = new[] { new ThisWeekRules.WeekRef(D("2025-11-02"), D("2025-11-08"), 0), new ThisWeekRules.WeekRef(D("2025-11-09"), D("2025-11-15"), 1) };
        var flags = ThisWeekRules.TaughtFlags(
            [(5, D("2025-11-10"), new HashSet<string> { "arabic", "ahkam" }), (5, D("2025-11-03"), new HashSet<string> { "aqaed" }), (6, D("2025-10-01"), new HashSet<string> { "arabic" })], weeks);
        Assert.That(flags.Keys, Is.EquivalentTo((int[])[5, 6]));
        Assert.That(flags[5]["arabic"], Is.EqualTo((bool[])[false, true]));
        Assert.That(flags[5]["aqaed"], Is.EqualTo((bool[])[true, false]));
        Assert.That(flags[5]["ahkam"], Is.EqualTo((bool[])[false, true]));
        Assert.That(flags[5]["akhlaq"], Is.EqualTo((bool[])[false, false]));
        Assert.That(flags[6]["arabic"], Is.EqualTo((bool[])[false, false]));
        Assert.That(flags.ContainsKey(7), Is.False);
    }

    [Test]
    public void A_class_that_filled_no_form_is_listed_for_the_form_and_not_counted_as_met_or_of()
    {
        var screen = ThisWeekRules.Assemble(Starts, [Class(1, Cells("NF"))], new Dictionary<int, double>());
        Assert.That(screen.Summary, Is.EqualTo(new ThisWeekRules.Summary(0, 0, 1, null, 1)));
        Assert.That(screen.Stages.Cform.Select(r => (r.ClassId, r.Detail, r.Action)).ToArray(), Is.EqualTo((ValueTuple<int, string, string?>[])[(1, "Form not submitted", "message")]));
        Assert.That(screen.Stages.Alignment.Select(r => r.ClassId).ToArray(), Is.EqualTo((int[])[1]));
        Assert.That(screen.Stages.Alignment[0].Teacher, Is.EqualTo("T"));
        Assert.That(screen.Stages.Alignment[0].TeacherMobile, Is.EqualTo("+1"));
        Assert.That(screen.Stages.Met, Is.Empty);
    }

    [Test]
    public void A_class_that_met_is_counted_listed_with_no_number_and_a_streak_of_missed_weeks_asks_for_a_message_or_a_call()
    {
        var screen = ThisWeekRules.Assemble(
            Starts,
            [Class(1, Cells("Yes (2)")), Class(2, Cells("No", "No")), Class(3, Cells("No", "No", "No", "No")), Class(4, Cells("No", "No", "No"))],
            new Dictionary<int, double>());
        Assert.That(screen.Summary.Met, Is.EqualTo(1));
        Assert.That(screen.Summary.Of, Is.EqualTo(4));
        Assert.That(screen.Summary.Flagged, Is.EqualTo(3));
        Assert.That(screen.Stages.Met.Select(r => (r.ClassId, r.Detail, r.TeacherMobile, r.Action)).ToArray(),
            Is.EqualTo((ValueTuple<int, string, string?, string?>[])[(1, "Met", null, null)]));
        Assert.That(screen.Stages.Conduction.Select(r => (r.ClassId, r.Detail, r.Action)).ToArray(),
            Is.EqualTo((ValueTuple<int, string, string?>[])[(3, "No class for 4 weeks", "call"), (4, "No class for 3 weeks", "message"), (2, "No class for 2 weeks", "message")]));
        Assert.That(screen.Stages.Conduction[0].TeacherMobile, Is.EqualTo("+1"));
    }

    [Test]
    public void Conduction_rows_with_the_same_streak_are_in_class_id_order()
    {
        var screen = ThisWeekRules.Assemble(Starts, [Class(9, Cells("No", "No")), Class(3, Cells("No", "No"))], new Dictionary<int, double>());
        Assert.That(screen.Stages.Conduction.Select(r => r.ClassId).ToArray(), Is.EqualTo((int[])[3, 9]));
    }

    [Test]
    public void Weeks_over_before_the_class_started_are_not_missed_weeks()
    {
        // The first seven weeks ended before 2025-11-09: a class that started that day has only the last two weeks, and the earlier cells (whatever they say) are n/a.
        string[] cells = [.. Enumerable.Repeat("No", 7), "Yes", "Yes"];
        var screen = ThisWeekRules.Assemble(Starts, [Class(1, cells, started: "2025-11-09")], new Dictionary<int, double>());
        Assert.That(screen.Stages.Conduction, Is.Empty);
        Assert.That(screen.Summary.Of, Is.EqualTo(1));

        var notBegun = ThisWeekRules.Assemble(Starts, [Class(2, cells, started: "2026-01-01")], new Dictionary<int, double>());
        Assert.That(notBegun.Summary, Is.EqualTo(new ThisWeekRules.Summary(0, 0, 0, null, 0)));
        Assert.That(notBegun.Stages.Alignment.Select(r => r.ClassId).ToArray(), Is.EqualTo((int[])[2]));
    }

    [Test]
    public void A_class_that_met_but_left_a_subject_out_for_two_weeks_is_listed_with_the_quiet_subject_and_a_message()
    {
        var subjects = new Dictionary<string, bool[]>
        {
            ["arabic"] = [true, true, true, true, true, true, true, false, false],
            ["aqaed"] = [true, true, true, true, true, true, true, true, false],
            ["ahkam"] = [false, false, false, false, false, false, false, false, false],
            ["akhlaq"] = [true, true, true, true, true, true, true, true, true],
        };
        var screen = ThisWeekRules.Assemble(Starts, [Class(1, Cells("Yes"), subjects: subjects)], new Dictionary<int, double>());
        var row = screen.Stages.Conduction.Single();
        Assert.That(row.Detail, Is.EqualTo(string.Empty));
        Assert.That(row.Action, Is.EqualTo("message"));
        Assert.That(row.Quiet.Select(q => (q.Subject, q.Weeks)).ToArray(), Is.EqualTo((ValueTuple<string, int>[])[("arabic", 2), ("ahkam", 9)]));
        Assert.That(screen.Summary.Flagged, Is.EqualTo(1));
    }

    [Test]
    public void Weeks_before_the_class_started_are_left_out_of_a_quiet_streak_and_a_class_that_did_not_meet_has_no_quiet_list()
    {
        var subjects = new Dictionary<string, bool[]> { ["arabic"] = new bool[9] };
        var late = ThisWeekRules.Assemble(Starts, [Class(1, Cells("Yes"), started: "2025-11-16", subjects: subjects)], new Dictionary<int, double>());
        Assert.That(late.Stages.Conduction, Is.Empty);

        var noMeeting = ThisWeekRules.Assemble(Starts, [Class(2, Cells("No"), subjects: new Dictionary<string, bool[]> { ["arabic"] = new bool[9] })], new Dictionary<int, double>());
        Assert.That(noMeeting.Stages.Conduction, Is.Empty);
    }

    [Test]
    public void Attendance_is_listed_as_a_rounded_percent_flagged_below_half_and_averaged_to_two_places()
    {
        var screen = ThisWeekRules.Assemble(
            Starts, [Class(1, Cells("Yes")), Class(2, Cells("Yes")), Class(3, Cells("Yes"))], new Dictionary<int, double> { [1] = 1.0, [2] = 0.49, [3] = 2.0 / 3.0 });
        Assert.That(screen.Stages.Attended.Select(r => r.Detail).ToArray(), Is.EqualTo((string[])["Attendance 100%", "Attendance 49%", "Attendance 67%"]));
        Assert.That(screen.Stages.Attendance.Select(r => (r.ClassId, r.Detail, r.Action)).ToArray(), Is.EqualTo((ValueTuple<int, string, string?>[])[(2, "Attendance 49%", "message")]));
        Assert.That(screen.Summary.Attendance!.Value.Value, Is.EqualTo(0.72));
        Assert.That(screen.Summary.Flagged, Is.EqualTo(1));
    }

    [Test]
    public void No_week_and_no_class_give_an_empty_screen()
    {
        var screen = ThisWeekRules.Assemble([], [Class(1, [])], new Dictionary<int, double>());
        Assert.That(screen.Summary, Is.EqualTo(new ThisWeekRules.Summary(0, 0, 0, null, 0)));
        Assert.That(screen.Stages.Alignment, Has.Count.EqualTo(1));
    }
}
