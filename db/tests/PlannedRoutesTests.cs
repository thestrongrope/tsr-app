using System.Net;
using NUnit.Framework;
using Tsr.Host.Api.Tests;

namespace Tsr.Db.Tests;

/// <summary>
/// The 501 placeholders against a real database: signed in as a member they answer 501, and they change nothing but the
/// sign-in record every member route writes. Where PHP's route would create a member, the placeholder looks one up instead.
/// The no-token answers are in hosts/api/tests/RouteSurfaceTests.cs.
/// </summary>
public sealed class PlannedRoutesTests
{
    private const int Token = 900001;

    private static readonly IReadOnlyList<CatalogRoute> Planned = RouteCatalog.Load().Where(r => r is { IsBuilt: false } and not { Auth: "public" }).ToList();

    private MembershipTestKit kit = null!;

    public static IEnumerable<TestCaseData> PlannedMemberRoutes() =>
        Planned.Select(r => new TestCaseData(r.Method, r.Concrete).SetName(r.Method + " " + r.Path));

    [SetUp]
    public async Task StartAsync()
    {
        await MembershipTestKit.ResetAsync();
        kit = new MembershipTestKit();
    }

    [TearDown]
    public void Stop() => kit.Dispose();

    [Test]
    public async Task Every_planned_member_route_answers_501_to_a_signed_in_member_and_creates_no_member()
    {
        await MembershipTestKit.AddMemberAsync(Token);
        var wrong = new List<string>();

        foreach (var route in Planned)
        {
            var reply = await kit.SendAsync(Token, new HttpMethod(route.Method), route.Concrete);
            if (reply.Status != HttpStatusCode.NotImplemented || reply.Body != """{"detail":"Not implemented"}""")
            {
                wrong.Add(route.Method + " " + route.Path + " gave " + (int)reply.Status + " " + reply.Body);
            }
        }

        Assert.That(wrong, Is.Empty);
        Assert.That(await MembershipTestKit.CountAsync("identity.users"), Is.EqualTo(1));
    }

    // "A planned route PHP creates a member on does not create one" had two cases (GET /search, POST /notifications/send). Both routes are built
    // since the build-out of 12 Nov 2026 and no planned route of that kind is left, so the test went with them.
}
