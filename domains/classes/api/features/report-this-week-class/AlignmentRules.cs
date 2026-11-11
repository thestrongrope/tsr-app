namespace Tsr.Classes.Api.Features.ReportThisWeekClass;

internal static class AlignmentRules
{
    internal readonly record struct Week(DateOnly Start, DateOnly End);

    internal sealed record Session(DateOnly ConductedOn, bool Held, IReadOnlyDictionary<string, string> Topics);

    internal sealed record WeekItem(string From, string To, string Status, IReadOnlyDictionary<string, string> Subjects);

    /// <summary>
    /// PHP <c>buildAlignment</c>: per week "taught" when a session was held, "no class" when sessions were filled and none held, "no form" when none; the topics of held sessions joined with "; " per subject. Newest week first.
    /// </summary>
    internal static IReadOnlyList<WeekItem> Build(IReadOnlyList<Session> sessions, IReadOnlyList<Week> weeksOldestFirst)
    {
        var items = new List<WeekItem>();
        foreach (var week in weeksOldestFirst)
        {
            var status = "no form";
            var topics = new Dictionary<string, List<string>>();
            foreach (var session in sessions.Where(s => s.ConductedOn >= week.Start && s.ConductedOn <= week.End))
            {
                if (!session.Held)
                {
                    status = status == "no form" ? "no class" : status;
                    continue;
                }

                status = "taught";
                foreach (var (subject, topic) in session.Topics)
                {
                    if (!topics.TryAdd(subject, [topic]))
                    {
                        topics[subject].Add(topic);
                    }
                }
            }

            items.Add(new WeekItem(Day(week.Start), Day(week.End), status, topics.ToDictionary(t => t.Key, t => string.Join("; ", t.Value))));
        }

        items.Reverse();
        return items;
    }

    private static string Day(DateOnly day) => day.ToString("yyyy-MM-dd", System.Globalization.CultureInfo.InvariantCulture);
}
