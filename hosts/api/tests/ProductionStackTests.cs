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

    private static readonly string[] LongRunningServices = ["db", "gotenberg", "elasticsearch", "embeddings", "api", "workers", "site"];

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

    /// <summary>
    /// The server's proxy reaches the API itself; the gateway of the dev and test stacks has no job in production. The site's server
    /// serves files and forwards nothing: it mounts no configuration, so it cannot be turned into a proxy from this file.
    /// </summary>
    [Test]
    public void No_second_proxy() =>
        Assert.That(Stack, Does.Not.Match(@"(?m)^  gateway:").And.Not.Contain("hosts/gateway").And.Not.Contain("conf.d"));

    /// <summary>
    /// TC-SITE-R15-01, the text half: the site's server is built from hosts/site/Dockerfile.server, whose one setting answers an
    /// unknown address with the site's own not-found page. The other half runs inside that file's "selftest" build stage.
    /// </summary>
    [Test]
    public void The_site_server_answers_an_unknown_address_with_the_site_s_own_page()
    {
        var site = Regex.Match(Stack, @"(?ms)^  site:\n(?<body>.*?)(?=^  \S|\z)").Groups["body"].Value;
        var dockerfile = File.ReadAllText(Path.Combine(RouteCatalog.RepoRoot(), "hosts", "site", "Dockerfile.server"));
        var config = SiteServerConfig();

        Assert.Multiple(() =>
        {
            Assert.That(site, Does.Contain("context: hosts/site").And.Contain("dockerfile: Dockerfile.server"));
            Assert.That(site, Does.Not.Contain("image:"));
            Assert.That(dockerfile, Does.Contain("COPY nginx.conf /etc/nginx/conf.d/default.conf"));
            Assert.That(dockerfile, Does.Contain("AS selftest").And.Contain("selftest.sh"));
            Assert.That(config, Does.Contain("error_page 404 /404.html;"));
            Assert.That(config, Does.Contain("listen 80;").And.Contain("root /usr/share/nginx/html;").And.Contain("index index.html;"));
            Assert.That(config, Does.Contain("absolute_redirect off;"));
        });
    }

    /// <summary>The site's server forwards nothing and names no host: every redirect is relative.</summary>
    [Test]
    public void The_site_server_configuration_forwards_nothing_and_names_no_host()
    {
        var config = SiteServerConfig();

        Assert.Multiple(() =>
        {
            Assert.That(config, Does.Not.Contain("proxy_pass"));
            Assert.That(config, Does.Not.Contain("fastcgi_pass"));
            Assert.That(config, Does.Not.Contain("upstream"));
            Assert.That(config, Does.Not.Contain("thestrongrope"));
        });
    }

    private static string SiteServerConfig() =>
        File.ReadAllText(Path.Combine(RouteCatalog.RepoRoot(), "hosts", "site", "nginx.conf"));

    [Test]
    public void The_site_tells_search_engines_not_to_crawl_it() =>
        Assert.That(Stack, Does.Contain("TSR_SITE_NO_CRAWL: \"true\""));

    /// <summary>TC-LIB-R32-02: the image holds the content, the API settings point at it, and a one-off job loads it after the migration.</summary>
    [Test]
    public void The_stack_loads_the_image_s_content_at_each_deploy()
    {
        var load = Service("content-load");
        var dockerfile = File.ReadAllText(Path.Combine(RouteCatalog.RepoRoot(), "hosts", "api", "Dockerfile"));

        Assert.Multiple(() =>
        {
            Assert.That(Stack, Does.Contain("TSR_CONTENT_DIR: /var/tsr/content"));
            foreach (var folder in (string[])["articles", "categories", "pages"])
            {
                Assert.That(dockerfile, Does.Match(@"(?m)^COPY content/" + folder + @"/ /var/tsr/content/" + folder + @"/\s*$"), folder);
            }

            Assert.That(load, Does.Contain("dockerfile: hosts/api/Dockerfile"));
            Assert.That(load, Does.Contain(@"command: [""--load-content""]"));
            Assert.That(load, Does.Contain("<<: *api-environment"));
            Assert.That(load, Does.Match(@"migrate:\s+condition: service_completed_successfully"));
        });
    }

    /// <summary>
    /// Issue 108: the API, the workers and the content load run the native image; only the migrate job, which needs Entity Framework, runs the JIT one.
    /// Both are targets of the one Dockerfile; the dev stack (and so the test stack and its lanes) builds the same targets as production.
    /// </summary>
    [TestCase("docker-compose.yml", "api", "native")]
    [TestCase("docker-compose.yml", "workers", "native")]
    [TestCase("docker-compose.yml", "content-load", "native")]
    [TestCase("docker-compose.yml", "migrate", "migrate")]
    [TestCase("docker-compose.dev.yml", "api", "native")]
    [TestCase("docker-compose.dev.yml", "workers", "native")]
    [TestCase("docker-compose.dev.yml", "migrate", "migrate")]
    public void Each_service_runs_its_build_of_the_api_image(string file, string service, string target)
    {
        var lines = File.ReadAllLines(Path.Combine(RouteCatalog.RepoRoot(), file)).Where(line => !line.TrimStart().StartsWith('#'));
        var block = ServiceIn(string.Join('\n', lines), service);

        Assert.Multiple(() =>
        {
            Assert.That(block, Does.Contain("dockerfile: hosts/api/Dockerfile"));
            Assert.That(block, Does.Match(@"(?m)^\s+target: " + target + @"\s*$"));
        });
    }

    /// <summary>Issue 108: the native target holds the one binary on the runtime dependencies image, no .NET runtime; the migrate target is the JIT build on the ASP.NET image.</summary>
    [Test]
    public void The_native_image_carries_no_dotnet_runtime_and_the_migrate_image_is_the_jit_build()
    {
        var dockerfile = File.ReadAllText(Path.Combine(RouteCatalog.RepoRoot(), "hosts", "api", "Dockerfile"));
        var native = Stage(dockerfile, "native");
        var migrate = Stage(dockerfile, "migrate");

        Assert.Multiple(() =>
        {
            Assert.That(native, Does.StartWith("FROM mcr.microsoft.com/dotnet/runtime-deps:"));
            Assert.That(native, Does.Match(@"(?m)^ENTRYPOINT \[""/app/Tsr\.Host\.Api""\]\s*$"));
            Assert.That(native, Does.Not.Contain("dotnet\""));
            Assert.That(migrate, Does.StartWith("FROM mcr.microsoft.com/dotnet/aspnet:"));
            Assert.That(migrate, Does.Match(@"(?m)^ENTRYPOINT \[""dotnet"", ""Tsr\.Host\.Api\.dll""\]\s*$"));
            Assert.That(dockerfile, Does.Contain("-p:PublishAot=false"));
            Assert.That(dockerfile.TrimEnd(), Does.EndWith(native.TrimEnd()), "the native target is the last stage, so a build without a target gets it");
        });
    }

    // One stage of a Dockerfile: from its "FROM ... AS name" line to the next FROM.
    private static string Stage(string dockerfile, string name)
    {
        var stage = Regex.Match(dockerfile, @"(?ms)^FROM [^\n]* AS " + Regex.Escape(name) + @"\s*$.*?(?=^FROM |\z)");
        Assert.That(stage.Success, Is.True, "no stage " + name);
        return stage.Value;
    }

    /// <summary>TC-LIB-D10-01: the API image holds the three text folders and never the publication files (187 MB the API does not read).</summary>
    [Test]
    public void The_api_image_carries_the_text_content_and_not_the_files()
    {
        var copies = File.ReadAllLines(Path.Combine(RouteCatalog.RepoRoot(), "hosts", "api", "Dockerfile"))
            .Where(line => line.StartsWith("COPY content", StringComparison.Ordinal))
            .ToList();

        Assert.Multiple(() =>
        {
            Assert.That(copies, Has.Count.EqualTo(3));
            Assert.That(copies, Has.None.Match(@"^COPY content/? "), "the whole content folder");
            Assert.That(copies, Has.None.Contain("downloads"));
        });
    }

    /// <summary>TC-LIB-R36-01: the site image copies the publication files into the program's static files folder, which the build copies to /site/downloads/.</summary>
    [Test]
    public void The_site_image_carries_the_publication_files()
    {
        var dockerfile = File.ReadAllText(Path.Combine(RouteCatalog.RepoRoot(), "hosts", "site", "Dockerfile"));
        var finalStage = dockerfile[dockerfile.LastIndexOf("FROM ", StringComparison.Ordinal)..];

        Assert.Multiple(() =>
        {
            Assert.That(finalStage, Does.Match(@"(?m)^COPY content/downloads/ \./wwwroot/downloads/\s*$"));
            Assert.That(finalStage, Does.Match(@"(?m)^WORKDIR /app\s*$"));
        });
    }

    /// <summary>TC-LIB-R33-01: the site is built only from the content the job has loaded.</summary>
    [Test]
    public void The_site_is_built_only_after_the_content_is_loaded() =>
        Assert.That(Service("site-build"), Does.Match(@"content-load:\s+condition: service_completed_successfully"));

    /// <summary>TC-VIDEOS-01: an empty channel setting would switch the Home videos off; unset, the API reads the channel in the code.</summary>
    [Test]
    public void The_stack_does_not_switch_the_videos_off() =>
        Assert.That(Stack, Does.Not.Contain("TSR_YOUTUBE_CHANNEL_ID"));

    /// <summary>The test stack and the lanes mount their synthetic folder over the image's content, so they never read the real set.</summary>
    [Test]
    public void The_test_stack_mounts_its_own_content_over_the_image_s()
    {
        var dev = File.ReadAllText(Path.Combine(RouteCatalog.RepoRoot(), "docker-compose.dev.yml"));

        Assert.That(dev, Does.Contain(":/var/tsr/content:ro"));
    }

    /// <summary>TC-SRCH-Q5-01 (the text half): the embedding service is built from hosts/embeddings, is reached only by the other services (no port, no profile, no setting that holds a secret) and may not take more than 1 GB.</summary>
    [Test]
    public void The_embedding_service_is_internal_limited_to_one_gigabyte_and_built_from_its_folder()
    {
        var embeddings = Service("embeddings");

        Assert.Multiple(() =>
        {
            Assert.That(embeddings, Does.Contain("context: hosts/embeddings"));
            Assert.That(embeddings, Does.Not.Contain("image:"));
            Assert.That(embeddings, Does.Match(@"(?ms)deploy:\s+resources:\s+limits:\s+memory: 1G"));
            Assert.That(embeddings, Does.Not.Match(@"(?m)^\s*(ports|profiles|environment)\s*:"));
        });
    }

    /// <summary>The dev stack (and so the test stack and its lanes) has the same service under the profile "workers": the default test stack runs it, a lane does not unless it asks (tools/test-stack.sh).</summary>
    [Test]
    public void The_dev_stack_has_the_embedding_service_under_the_workers_profile()
    {
        var lines = File.ReadAllLines(Path.Combine(RouteCatalog.RepoRoot(), "docker-compose.dev.yml")).Where(line => !line.TrimStart().StartsWith('#'));
        var embeddings = ServiceIn(string.Join('\n', lines), "embeddings");

        Assert.Multiple(() =>
        {
            Assert.That(embeddings, Does.Contain("context: hosts/embeddings"));
            Assert.That(embeddings, Does.Contain("profiles: [\"workers\"]"));
            Assert.That(embeddings, Does.Not.Match(@"(?m)^\s*ports\s*:"));
        });
    }

    /// <summary>The image pins what makes a vector: an exact fastembed in the project file and a lock the build may not change.</summary>
    [Test]
    public void The_embedding_image_builds_from_the_lock_with_an_exact_fastembed()
    {
        var folder = Path.Combine(RouteCatalog.RepoRoot(), "hosts", "embeddings");
        var dockerfile = File.ReadAllText(Path.Combine(folder, "Dockerfile"));

        Assert.Multiple(() =>
        {
            Assert.That(File.ReadAllText(Path.Combine(folder, "pyproject.toml")), Does.Match(@"""fastembed==\d+\.\d+\.\d+"""));
            Assert.That(File.Exists(Path.Combine(folder, "uv.lock")), Is.True);
            Assert.That(dockerfile, Does.Contain("uv sync --frozen"));
            Assert.That(dockerfile, Does.Contain("EMBEDDING_MODEL=BAAI/bge-small-en-v1.5"));
            Assert.That(dockerfile, Does.Not.Contain("pip install"));
            Assert.That(dockerfile, Does.Contain("HEALTHCHECK").And.Contain("python -c"));
        });
    }

    private static string Service(string name) => ServiceIn(Stack, name);

    private static string ServiceIn(string stack, string name)
    {
        var block = Regex.Match(stack, @"(?ms)^  " + Regex.Escape(name) + @":\n(?<body>.*?)(?=^  \S|\z)");
        Assert.That(block.Success, Is.True, "no service " + name);
        return block.Groups["body"].Value;
    }

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
