namespace Tsr.Access.Api.Domain;

/// <summary>One condition of a class access rule: <c>field IN value</c>, or NOT IN when negated. Field: city, country, level, tag.</summary>
internal sealed record RuleCondition(string Field, bool Negate, string? Value, int? LevelId);

/// <summary>One live class access rule: a member's reach over classes, optionally of one gender, narrowed by conditions.</summary>
internal sealed record AccessRule(int? Gender, IReadOnlyList<RuleCondition> Conditions);

/// <summary>
/// Which active classes a rule reaches, as PHP's class_access_from_rules view decides. Values of one field are
/// ORed, different fields ANDed, negations exclude, and a missing city, country or level fails a negation too.
/// Text is compared ignoring case (PHP: lcase).
/// </summary>
internal static class RuleMatcher
{
    public static bool Matches(AccessRule rule, ClassFacts facts)
    {
        if (rule.Gender is int gender && gender != facts.Gender)
        {
            return false;
        }

        return PositivesHold(rule.Conditions, facts) && !rule.Conditions.Any(c => c.Negate && Excludes(c, facts));
    }

    /// <summary>
    /// The classes the rules reach, one entry per (rule, class) as PHP's view has one row each: a class two rules
    /// reach is listed twice (a quirk kept for parity), in the order the classes are given.
    /// </summary>
    public static IReadOnlyList<ClassFacts> Assigned(IReadOnlyList<AccessRule> rules, IReadOnlyList<ClassFacts> classes) =>
        classes.SelectMany(c => rules.Where(r => Matches(r, c)).Select(_ => c)).ToList();

    private static bool PositivesHold(IReadOnlyList<RuleCondition> conditions, ClassFacts facts) =>
        conditions
            .Where(c => !c.Negate)
            .GroupBy(c => c.Field)
            .All(group => group.Any(c => Equals(c, facts)));

    // A negated condition excludes a class that matches it, or that has no value to compare (tags: carries none).
    private static bool Excludes(RuleCondition condition, ClassFacts facts) => condition.Field switch
    {
        "city" => facts.City is null || Same(facts.City, condition.Value),
        "country" => facts.Country is null || Same(facts.Country, condition.Value),
        "level" => facts.LevelId is null || facts.LevelId == condition.LevelId,
        "tag" => HasTag(facts, condition.Value),
        _ => false,
    };

    private static bool Equals(RuleCondition condition, ClassFacts facts) => condition.Field switch
    {
        "city" => Same(facts.City, condition.Value),
        "country" => Same(facts.Country, condition.Value),
        "level" => facts.LevelId is not null && facts.LevelId == condition.LevelId,
        "tag" => HasTag(facts, condition.Value),
        _ => false,
    };

    private static bool Same(string? left, string? right) =>
        left is not null && right is not null && string.Equals(left, right, StringComparison.OrdinalIgnoreCase);

    private static bool HasTag(ClassFacts facts, string? tag) => facts.Tags.Any(t => Same(t, tag));
}
