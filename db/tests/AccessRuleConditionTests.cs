using NUnit.Framework;

namespace Tsr.Db.Tests;

/// <summary>Access (TC-ACC-R2-02): how the conditions of a saved rule are stored.</summary>
public sealed class AccessRuleConditionTests
{
    [Test]
    public async Task A_rules_conditions_are_stored_deduplicated_in_natural_key_order()
    {
        await using var run = await GoldenScenario.StartAsync("write-rule-condition-order");

        await AccessGoldenScenarios.Writes["write-rule-condition-order"](run);

        var stored = await run.QueryAsync("select field || '=' || coalesce(value, level_id::text) from access.class_access_rule_conditions order by id");
        Assert.That(stored, Is.EqualTo(AccessGoldenScenarios.StoredConditionOrder));
    }
}
