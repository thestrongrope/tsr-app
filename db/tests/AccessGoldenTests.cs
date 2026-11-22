using NUnit.Framework;

namespace Tsr.Db.Tests;

/// <summary>
/// Characterisation of the access domain (issue 99): every answer and every stored row is recorded on the code as it was, in db/tests/golden/access, so the
/// conversion off Entity Framework can be compared byte for byte. Nothing here asserts a value written by hand: a golden file is the expectation.
/// </summary>
public sealed class GoldenAccessTests
{
    public static IEnumerable<string> RouteScenarios => AccessGoldenScenarios.Routes.Keys;

    [TestCaseSource(nameof(RouteScenarios))]
    public async Task Every_access_route_answers_as_recorded(string scenario)
    {
        await using var run = await GoldenScenario.StartAsync(scenario);

        await AccessGoldenScenarios.Routes[scenario](run);

        GoldenScenario.Check(scenario, run.Transcript);
    }

    [TestCase("write-permission-grant-revoke")]
    [TestCase("write-rule-save-revoke")]
    [TestCase("write-rule-save-on-admins")]
    public async Task Each_write_stores_the_recorded_rows_and_events(string scenario)
    {
        await using var run = await GoldenScenario.StartAsync(scenario);

        await AccessGoldenScenarios.Writes[scenario](run);

        GoldenScenario.Check(scenario, run.Transcript);
    }

    [Test]
    public async Task A_rules_conditions_are_stored_deduplicated_in_natural_key_order()
    {
        const string scenario = "write-rule-condition-order";
        await using var run = await GoldenScenario.StartAsync(scenario);

        await AccessGoldenScenarios.Writes[scenario](run);

        var stored = await run.QueryAsync("select field || '=' || coalesce(value, level_id::text) from access.class_access_rule_conditions order by id");
        Assert.That(stored, Is.EqualTo(AccessGoldenScenarios.StoredConditionOrder));
        GoldenScenario.Check(scenario, run.Transcript);
    }
}
