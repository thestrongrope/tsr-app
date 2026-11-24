using NUnit.Framework;

namespace Tsr.Db.Tests;

/// <summary>
/// Characterisation of the identity domain (issue 102): every answer, every stored row, every event and every account-service call is recorded on the code as it was, in
/// db/tests/golden/identity, so the conversion off Entity Framework can be compared byte for byte. Nothing here asserts a value written by hand: a golden file is the expectation.
/// </summary>
public sealed class IdentityGoldenTests
{
    public static IEnumerable<string> RouteScenarios => IdentityGoldenScenarios.Routes.Keys;

    public static IEnumerable<string> WriteScenarios => IdentityGoldenScenarios.Writes.Keys;

    public static IEnumerable<string> SignInOutcomeScenarios => IdentityGoldenScenarios.SignInOutcomes.Keys;

    public static IEnumerable<string> SignInWriteScenarios => IdentityGoldenScenarios.SignInWrites.Keys;

    // TC-IDN-R1-01: the answers of the nine routes and their refusals. The answers of the writes are in the files of Each_deletion_write_stores_the_recorded_rows_and_events.
    [TestCaseSource(nameof(RouteScenarios))]
    public async Task Every_identity_route_answers_as_recorded(string scenario)
    {
        await using var run = await IdentityRun.StartAsync(scenario);

        await IdentityGoldenScenarios.Routes[scenario](run);

        GoldenScenario.Check(scenario, run.Transcript, IdentityGolden.Set);
    }

    // TC-IDN-R6-01
    [TestCaseSource(nameof(WriteScenarios))]
    public async Task Each_deletion_write_stores_the_recorded_rows_and_events(string scenario)
    {
        await using var run = await IdentityRun.StartAsync(scenario);

        await IdentityGoldenScenarios.Writes[scenario](run);

        GoldenScenario.Check(scenario, run.Transcript, IdentityGolden.Set);
    }

    // TC-IDN-R2-01
    [TestCaseSource(nameof(SignInOutcomeScenarios))]
    public async Task Every_sign_in_outcome_answers_as_recorded(string scenario)
    {
        await using var run = await IdentityRun.StartAsync(scenario);

        await IdentityGoldenScenarios.SignInOutcomes[scenario](run);

        GoldenScenario.Check(scenario, run.Transcript, IdentityGolden.Set);
    }

    // TC-IDN-R3-01
    [TestCaseSource(nameof(SignInWriteScenarios))]
    public async Task Each_sign_in_stores_the_recorded_rows(string scenario)
    {
        await using var run = await IdentityRun.StartAsync(scenario);

        await IdentityGoldenScenarios.SignInWrites[scenario](run);

        GoldenScenario.Check(scenario, run.Transcript, IdentityGolden.Set);
    }
}
