using System.Text.RegularExpressions;
using NUnit.Framework;

namespace Tsr.Host.Api.Tests;

/// <summary>
/// The production stack (docker-compose.yml) must never carry what the dev and test stacks carry: synthetic members, the sign-in
/// emulator, a published port or a secret's value. These are text checks: a person can break each of them with one pasted line.
/// </summary>
public sealed partial class ProductionStackTests
{
    private static readonly string[] RequiredSettings =
        ["TSR_DB_OWNER_PASSWORD", "TSR_APP_DB_PASSWORD", "TSR_ELASTICSEARCH_PASSWORD", "TSR_FIREBASE_PROJECT_ID"];

    private static readonly string[] LongRunningServices = ["db", "gotenberg", "elasticsearch", "api", "workers"];

    /// <summary>The file without its comments: a comment may name what the stack must not contain.</summary>
    private static readonly string Stack = string.Join(
        '\n',
        File.ReadAllLines(Path.Combine(RouteCatalog.RepoRoot(), "docker-compose.yml")).Where(line => !line.TrimStart().StartsWith('#')));

    /// <summary>A YAML key that names a secret, at the start of its line (so the text of a "is not set" message is not read as a key).</summary>
    [GeneratedRegex(@"^\s*[A-Z0-9_]*(PASSWORD|_B64):\s+(?<value>.*)$", RegexOptions.Multiline)]
    private static partial Regex SecretSetting();

    [GeneratedRegex(@"Password=(?<value>[^;""]*)")]
    private static partial Regex ConnectionPassword();

    [GeneratedRegex(@"\$\{(?<name>[A-Z0-9_]+)(?<rest>[^}]*)\}")]
    private static partial Regex Reference();

    [TestCase("seed")]
    [TestCase("synthetic")]
    [TestCase("emulator")]
    [TestCase("Development")]
    public void No_synthetic_data_and_no_emulator(string forbidden) =>
        Assert.That(Stack, Does.Not.Contain(forbidden).IgnoreCase);

    [Test]
    public void No_secret_has_a_value()
    {
        var values = SecretSetting().Matches(Stack).Select(m => m.Groups["value"].Value.Trim().Trim('"'))
            .Concat(ConnectionPassword().Matches(Stack).Select(m => m.Groups["value"].Value))
            .ToList();

        Assert.Multiple(() =>
        {
            Assert.That(values, Is.Not.Empty);
            Assert.That(values, Has.All.Match(@"^\$\{[A-Z0-9_]+(:[?-][^}]*)?\}$"));
            Assert.That(Stack, Does.Not.Contain("local-only"));
        });
    }

    /// <summary>The server's proxy reaches the API itself; the nginx gateway of the dev and test stacks has no job in production.</summary>
    [Test]
    public void No_second_proxy() =>
        Assert.That(Stack, Does.Not.Match(@"(?m)^  gateway:").And.Not.Contain("nginx"));

    [Test]
    public void No_port_is_published() =>
        Assert.That(Stack, Does.Not.Match(@"(?m)^\s*ports\s*:"));

    [TestCaseSource(nameof(RequiredSettings))]
    public void Required_settings_fail_loudly(string name)
    {
        var uses = Reference().Matches(Stack).Where(m => m.Groups["name"].Value == name).Select(m => m.Groups["rest"].Value).ToList();

        Assert.Multiple(() =>
        {
            Assert.That(uses, Is.Not.Empty, name + " is not used");
            Assert.That(uses, Has.All.StartsWith(":?"), name + " must be written ${" + name + ":?...} everywhere");
        });
    }

    [TestCaseSource(nameof(LongRunningServices))]
    public void Long_running_services_start_again(string service)
    {
        var block = Regex.Match(Stack, @"(?ms)^  " + Regex.Escape(service) + @":\n(?<body>.*?)(?=^  \S|\z)");

        Assert.Multiple(() =>
        {
            Assert.That(block.Success, Is.True, "no service " + service);
            Assert.That(block.Groups["body"].Value, Does.Contain("restart: unless-stopped"));
        });
    }
}
