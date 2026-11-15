# .NET Conf 2026: what is useful to tsr-app (Community Day only)

Written 13 Nov 2026. **Covers Day 3 only** (the Community Day stream, 9 h 22 min, stamps [00:10] to [09:21]).
Days 1 and 2 are not covered here: Asif had already used them in the build-out.

**Source.** YouTube had no captions for Day 3, so the audio was transcribed locally with Whisper. Names and
product terms can be misheard; "(as heard)" marks doubt. The transcript, the audio and four reader digests are in
the session group's notes folder, under `dotnet-conf-2026/` (`day3-transcript.txt`, `day3-digest-a.md` to `-d.md`).

**How to read the marks.**
- **checked**: I read the wording in the transcript at that stamp myself.
- **from the digest, not checked**: taken from a reader's digest only.
- **Announced / Demonstrated**: a feature the speaker says shipped, or showed running.
- **Recommended**: the speaker's advice or opinion, nothing more.
- Nothing here is a claim about our code. Where a point depends on the repo, it says "would need checking in the repo".

Day 3 is community talks. It had **no** session on EF Core, PostgreSQL, minimal APIs, OpenAPI, validation, the
Microsoft Testing Platform, NativeAOT for servers, caching or `Microsoft.Extensions.AI`. Most of what is useful
is practice for agent-built code, plus a few .NET 11 facts said in passing.

## Top points, most valuable first (all checked against the transcript)

1. **Make the checks the reviewer, not the person** (Palermo [07:28], [07:31], [07:39]; recommended). A fast build plus architecture tests decide whether a bot's change is safe; the person only asks "do I want this change".
2. **Idempotency by a persisted operation ID** (Paul [08:59] to [09:00]; recommended). The client makes a stable ID before the first send; the server keeps durable duplicate handling and returns the existing result. Would need checking in the repo for our POST routes.
3. **Skills plus CLIs over MCP servers for agents** (Juergen [02:46] to [02:47]; recommended). Cheaper, "a smaller context", and safer. Tell the agent something twice, then make it a skill.
4. **Store the trace ID beside the business row** (Shweta [00:19]; demonstrated). `Activity.Current` trace ID is logged and saved in the database as "a durable correlation value". Keep telemetry and business audit as separate stores ([00:30] to [00:32]; recommended).
5. **The modular monolith is confirmed as the default, with one main rule** (Steve Smith [06:33], [06:38]; recommended). Modules own their data, never reach into each other's tables, and depend only on another module's contracts. This is the design we already have.
6. **C# 15 unions and closed hierarchies** (Hawker [07:52] to [07:55]; announced as shipped with .NET 11). A union fits "an error or the thing"; a closed hierarchy lets a `switch` drop its default case. A candidate for our `Result<T>`; would need checking in the repo.
7. **.NET 11 "runtime async"** (Ian [04:31] to [04:32]; announced). The runtime builds the async state machine. One library went from "just under four megabytes" to "1.8 megabytes" for the same code.
8. **A second model finds bugs the first one left** (Ian [04:33]; reported from his project). He intervened "at least 80 times" and other models "found further bugs".
9. **Have the agent run the real app, not only the tests** (Washington [08:39] to [08:41]; recommended). Green unit tests alone are "worthless to me". A security pass against the running app gave "19 findings. Two were high, six were medium".
10. **Keep instruction files short** (Sam [05:54]; recommended). "This should not be a 3,000-line long file."

## Verification as the gate for agent work

**Jeffrey Palermo (ClearMeasure), "AI architecture and DevOps", Day 3 [07:14] to [07:47].**
- Recommended, checked [07:28]: the integration build is the foundation. His has many parallel jobs "and it still
  takes 13 minutes. This has to be fast."
- Recommended, checked [07:31]: a person reviewing "100 pull requests" at "45 seconds per pull request" is not a
  review. The environment's checks must do the rigorous part.
- Demonstrated, checked [07:37] to [07:38]: architecture tests written in NUnit (heard as "inUnit") that test
  patterns, not behaviour. Example: the UI must never use `HttpClient` or the data context. He has "40 different
  architecture tests".
- Recommended, checked [07:32]: add the "CRAP score" to the build: test coverage combined with cyclomatic
  complexity. He expands it as "Change-Resistant Anti-Patterns" (as heard).
- Recommended, from the digest, not checked [07:25] to [07:27]: split work that needs only programming from work
  that needs engineering, and give the first kind to bots.
- Demonstrated, from the digest, not checked [07:41]: a bot attaches a video of the Playwright test as evidence.
- **Why it matters to us.** This is the north star's "verifiable output" stated by someone running it. We already
  gate on NUnit boundary tests and Hurl. The two ideas that may be new are a complexity-with-coverage score in the
  build and the 13-minute warning: a slow gate raises the cost of every verified change.

**Ian (Rx.NET maintainer; surname not said), AsyncRx.NET, Day 3 [04:09] to [04:39].**
- Reported, checked [04:27] to [04:28]: one shared test suite runs against two implementations, so the tests
  describe behaviour and cannot drift. An AI assistant built spikes of "eight or nine" designs, then converted
  the suite in "about a month and a half".
- Demonstrated, checked [04:28]: the tests run on virtual time, not real time, because real time "tends to make
  them unrepeatable". "About 23,000 tests" [04:29].
- Reported, checked [04:33]: "at least 80" interventions; "You do have to watch these things like a hawk";
  other models reviewing the result "found further bugs".
- **Why it matters to us.** One suite over two implementations is what our Hurl files do for PHP and the new API,
  so the approach has outside support. Virtual time is the pattern for testing timed workers without waiting;
  whether our worker tests need it would need checking in the repo. The second-model finding supports the
  cross-model review we already have a skill for.

**Michael Washington, "What Not to AI", Day 3 [08:14] to [08:45].**
- Recommended, checked [08:39]: "have AI launch the real app and click every button, go through every feature,
  and test everything every time".
- Recommended, checked [08:40]: never give the AI passwords. It stops at a login and the person signs in.
- Reported, checked [08:41]: a security review of the running app: "19 findings. Two were high, six were medium",
  three days to work through. Runs can last "six hours" and use many tokens.
- Recommended, checked [08:20]: the key line in his prompt template tells the agent "to ask questions" before it
  writes the plan.
- Recommended, checked [08:33]: he says the method "only works with models like Claude Opus 5.5 or above".
- From the digest, not checked [08:24] to [08:34]: his plans are large Markdown files (a master file of "1,700
  lines"), and he regenerates code from them.
- **Why it matters to us.** The first three match what we do with Patrol journeys, Hurl and the security agent.
  His very long plan files work against our "light context" value; we should not copy that part.

## How to drive coding agents

**Juergen (surname not said), an agent-built penetration tester, Day 3 [02:40] to [03:09].**
- Recommended, checked [02:46]: "Agents love Markdown and CLI." He prefers skills with CLIs over MCP servers:
  faster, "cheaper", "a smaller context", and "more secure". He cites an OWASP conference on how to hack MCPs.
- Recommended, checked [02:47]: "whenever i need to tell the agent anything twice or more then i create a skill".
  He had the agent write a skill from a CLI's own help output.
- Recommended, checked [02:51]: "llms shouldn't know any credentials". At a login the agent stops and opens an
  interactive browser.
- From the digest, not checked [02:51] to [02:53]: test cases kept as Markdown files that a regression skill
  replays; each failure opens a GitHub issue.
- From the digest, not checked [03:03], [03:09]: fetched content enters the context "and could become an
  instruction"; read a foreign skill before using it.
- **Why it matters to us.** It supports the way the repo already works: `tools/*.sh` scripts and skills, not MCP
  servers, which keeps agent context light. It is one practitioner's opinion, not a measurement.

**Sam (Uno Platform; surname not said), developer workflows with AI, Day 3 [05:40] to [06:11].**
- Recommended, checked [05:54]: the instructions file "should not be a 3,000-line long file. Keep it short".
- Recommended, checked [05:45]: "Context window really matters", and it is a cost. Agents should be "grounded
  and validating what they're doing".
- Announced, checked [05:46]: "MCP 2.0 specs are out and the .NET SDKs are following along."
- From the digest, not checked [05:56] to [05:58]: an MCP server in C# with a tool behind an auth policy; OAuth
  2.1 is part of the MCP 2.0 specification.
- **Why it matters to us.** Our root `CLAUDE.md` is long and still growing. His advice and our "light context"
  value point the same way: keep rules there and move history into the domain files.

**Ed Charbonneau (Deepgram), a voice agent on a microcontroller, Day 3 [05:11] to [05:40].** From the digest, not
checked. An agent repeatedly reported "It works" when the device then failed under real load [05:37]. What fixed
his first failure was giving the agent a known-working sample to build from [05:19]. Why it matters: the same
lesson as "evidence before claims"; an agent's report is not a check.

## Architecture

**Steve Smith (NimblePros), "Clean architecture and more with ASP.NET Core", Day 3 [06:12] to [06:41].** All
recommended; nothing new was announced except templates.
- Checked [06:33]: his default "for systems that are complex enough to warrant it is a modular monolithic
  approach". Each module "owns its own data. They don't reach into one another's tables"; calls are in process.
- Checked [06:38]: "none of the modules ever directly depend on one another. They always depend on another
  module's contracts. That's the main important rule".
- Checked [06:25]: organise by domain so a change "is mostly all in one place".
- Checked [06:24]: integration and end-to-end tests are "often what many developers say you should write first,
  have a real database, run it in a container"; keep unit tests where they make sense.
- Checked [06:26]: the cost of clean-architecture ceremony: "interfaces that have only one implementation just
  because you wanted to be able to test it".
- Checked [06:27]: boundaries can be enforced without extra projects: NsDepCop (heard as "NSDepcop") gives
  "compile time checks" of namespace dependencies; architecture tests are the other route.
- From the digest, not checked [06:35]: his `dotnet new` templates are updated to .NET 11. [06:40]: wrong
  boundaries are much cheaper to fix in a monolith than in microservices.
- **Why it matters to us.** It confirms the domain-first design, the views-and-commands rule between domains and
  the test mix (Testcontainers and Hurl first). One thing to weigh: a compile-time namespace check fails in the
  build, earlier than a boundary test. Whether that would shorten our loop would need checking in the repo.

**Sean Wiltermuth (as heard), simple services against microservices, Day 3 [01:11] to [01:41].** From the digest,
not checked. Recommended: match the architecture to the real team and load; start at the simplest hosting that
meets the need. Why it matters: agrees with Compose on Dokploy and no Kubernetes. Nothing to act on.

## .NET 11 SDK, runtime and C# 15

- **Runtime async.** Ian, Day 3. Announced, checked [04:31] to [04:32]: "one of the main advances in the .NET 11
  runtime". The .NET Standard build of his library is "just under four megabytes"; the .NET 11 build of "the exact
  same code" is "1.8 megabytes". From the digest, not checked [04:37]: async overhead falls but is not zero. Why
  it matters: async code on the `dotnet-11` branch may get smaller binaries and less overhead with no code
  change. The size figure is one library's; ours would need measuring.
- **C# 15 with .NET 11.** Michael A. Hawker (JetBrains), "Godot plus C-sharp and you", Day 3 [07:47] to [08:14].
  Checked [07:52]: ".NET 10 is C Sharp 14" and ".NET 11, which just released, is C Sharp 15". Checked [07:54]:
  the main features are unions, closed type hierarchies, extension indexers, collection arguments, and labeled
  break and continue. Checked [07:55]: unions suit returns that are "an error or the thing"; closed hierarchies
  mean a `switch` needs no default case.
  - Demonstrated, checked [08:02] to [08:05]: a gotcha. A plain object from outside does not match a union
    ("an expression of node can't be handled by target"), because a union "compiles down to basically a structure
    that becomes like a box". He wrote a helper to convert.
  - Why it matters: a union is the language's own form of our `Result<T>`, and a closed hierarchy makes the
    compiler check that every case is handled, which is verification for free. Whether to change `Result<T>`
    would need checking in the repo, and the boxing gotcha matters wherever JSON or EF hands us a plain object.
- **File-based apps: the include directive.** Mattias Karlsson (Cake), Day 3 [03:09] to [03:39]. Announced,
  checked [03:32] to [03:34]: sharing files between file-based apps "wasn't possible in .NET 10. But in .NET 11,
  they added the include", and it supports globs and MSBuild properties. Why it matters: our `tools/` scripts are
  shell, and the repo is meant to work on Windows and Mac. C# single-file scripts with shared includes are now an
  option. Whether that lowers cost would need checking in the repo; it is not a recommendation.
- **Container publishing.** Same talk. Announced, checked [03:26]: .NET 11 container publishing also supports
  WSL containers (heard as "VSLC") and "the new apple container", besides Docker and Podman. Low value to us: we
  build with Dockerfiles under OrbStack.

## Data integrity

**Paul (surname not said), a MAUI field app, Day 3 [08:45] to [09:17].** All recommended.
- Checked [08:59]: "before the first send, we create a stable operation ID and we persist it"; on retry "we reuse
  that ID"; on the server "durable duplicate handling recognizes the operation and returns its existing result".
- Checked [09:00]: the same ID with a different payload "shouldn't silently produce an unexpected result".
  Disabling a save button helps, "But the server needs some protection too".
- From the digest, not checked [08:51] to [08:55]: a singleton connection shared by two async operations can mix
  up a transaction; gate it with one `SemaphoreSlim`. [09:02]: test by killing the process before and after the
  commit.
- **Why it matters to us.** A phone on a poor connection can send the same request twice, and rule 1 says a rule
  only in the app is not enforced. Whether our POST routes are safe to replay would need checking in the repo.

## Observability

**Shweta (Microsoft), "tracing with AI agents using Aspire", Day 3 [00:10] to [00:39].**
- Demonstrated, checked [00:19]: `Activity.Current`'s trace ID is logged and persisted "in my database to have a
  durable correlation value". The instrumented HTTP client carries the trace to the next service.
- Recommended, checked [00:30] to [00:32]: telemetry answers where the time went; business audit stores "what the
  application recorded as the outcome". They hold different data and need different protection.
- From the digest, not checked [00:28]: all writes of one request go in one transaction, so a failure leaves no
  half-written rows. [00:32]: make completion explicit, success or failure.
- **Why it matters to us.** Our telemetry goes to files that agents query. A trace ID on the outbox row or the
  outbound message would let an agent go from a database row to its trace in one step, which shortens diagnosis.
  Whether we already store one would need checking in the repo. The Aspire parts do not apply.

## Security

- **Device Bound Session Credentials.** Wesley (surname not said), Day 3 [03:39] to [04:09]. From the digest, not
  checked. Experimental ASP.NET Core support was built during .NET 11, then moved to .NET 12; a community package
  exists. It binds a cookie session to a device key. It hardens cookies only, and we use bearer tokens, so there
  is nothing to act on. DPoP was named as the equivalent for APIs [04:06], with no detail.
- **Credentials and agents.** Two speakers gave the same rule independently: the model never sees a password
  (Juergen [02:51], Washington [08:40]; both checked).

## File-based apps (all days)

Added 13 Nov 2026 at Asif's request. Source: the Day 1 and Day 2 caption transcripts and the Day 3 Whisper
transcript, searched for every mention and read at each one. **Every point below is checked** (I read it in the
transcript at the stamp). Stamps are stream time. The captions never show the directive spellings: the speaker
says "hash colon" then a keyword, so `#:include`, `#:package`, `#:sdk`, `#:ref`, `#:project` and `#:property`
below are my spelling of what was said, and the exact syntax should be looked up. Nothing here was compared
with our code: whether any of it suits the domain split **would need checking in the repo**.

### Sessions that cover it

| Day, stamp | Session (agenda title) | Speaker | Video |
|---|---|---|---|
| Day 2, [07:40] to [08:11] | **C# File-based apps turned up to 11!** (the main session) | Damian Edwards | <https://www.youtube.com/watch?v=2UpjQ01cBGE&t=27600s> |
| Day 1, [00:23] to [00:25] | Keynote, .NET CLI segment | Chet Husk | <https://www.youtube.com/watch?v=SIBdHRrk8os&t=1380s> |
| Day 1, [00:56] | Keynote, agent segment (one sentence) | Wendy Breiding | same video, `&t=3360s` |
| Day 1, [02:15] | Moving `dotnet` Ahead (of Time)! | Chet Husk | same video, `&t=8100s` |
| Day 1, [05:21] to [05:31] | What's New in Aspire for .NET Developers | Maddy Montaquila, Damian Edwards | same video, `&t=19260s` |
| Day 1, [07:12] | How Aspire uses .NET to build an agent-first toolchain (one sentence, history only) | Maddy Montaquila, Jose Perez Rodriguez | same video, `&t=25920s` |
| Day 2, [06:11] | No XAML Required: Native Windows Apps in Pure C# | Alexandre Zollinger Chohfi | Day 2 video, `&t=22260s` |
| Day 2, [09:02] | EF Core 11 (one sentence) | Jiri Cincura | Day 2 video, `&t=32520s` |
| Day 3, [03:13] to [03:34] | Taking Cake 7 to Eleven | Mattias Karlsson | <https://www.youtube.com/watch?v=TF6qzdKwl84&t=11580s> |

"What's new in C#" (Day 1) and the C# Dev Kit and MSBuild talks do not mention file-based apps in the transcript.

### What is new in .NET 11 (Damian Edwards, Day 2, unless another name is given)

- **Include other files** (demonstrated, [07:50]; also Chet Husk, Day 1 [00:24]). A `#:include` line pulls another
  `.cs` file in. Includes are transitive: an included file can include more files. Globs are allowed, with a
  cost (see limits). Karlsson, Day 3 [03:32]: this "wasn't possible in .NET 10".
- **Directives in the included files** (demonstrated, [07:51]). An included file can carry its own `#:package`
  line, so "I can actually keep the package references on the files that require them".
- **Package versions** (demonstrated, [07:51] to [07:52]). `#:package Name@version`; the version may float (`*`,
  or a partial like `2.14.*`), or be left out so that central package management (`Directory.Packages.props`)
  decides, "like normal for a traditional project".
- **Metadata on directives** (demonstrated, [07:53]). New in 11: for example private assets "all" on a package
  line. Before 11 some packages could not be used correctly from a file-based app for lack of this.
- **App-to-app reference** (demonstrated, [07:58] to [07:59]). New in 11: `#:ref other.cs` references another
  file-based app, and "everything inside plan.cs will be brought in and available to me". The same idea as one
  console project referencing another.
- **Reference a normal project** (demonstrated, [07:59]). `#:project path/to/x.csproj` brings a class library
  into the file-based app. Not stated whether this is new in 11 or came in a .NET 10 update.
- **SDK directive** (demonstrated, [07:57] to [07:58]). `#:sdk Microsoft.NET.Sdk.Web` makes the file a web app;
  an SDK can also come from NuGet (the Cake SDK), and you can write your own.
- **Web apps and settings files** (demonstrated, [07:54] to [07:57]). `web.cs` runs an ASP.NET Core app. Beside
  it, `web.settings.json` is read like `appsettings.json` and `web.run.json` is the launch settings, both named
  after the app file.
- **More CLI commands understand them** (demonstrated, [08:00] to [08:03]; announced by Chet Husk, Day 1 [00:24]).
  In .NET 10 only build, restore, run and publish did. Shown in 11: `dotnet format`, `dotnet package list` with
  `--outdated` and `--vulnerable`. Announced: `dotnet package add` and `dotnet reference add`. Some commands take
  the file as the first argument, some need `--file` ([08:09]). EF Core 11's `dotnet ef` supports them too
  (Cincura, Day 2 [09:02], announced, no demo).
- **Build cache and launch speed** (demonstrated with timings, [07:46] to [07:50]). The cache key is a hash of the
  entry file's path plus the SDK version and "a few other things". Four cases on his machine: no cache or a changed
  directive goes through MSBuild, "about a second"; a file with no directives skips MSBuild and runs only the
  compiler; a source-only change recompiles only; no change runs the last assembly, "like a 100 millisecond".
  `--no-cache` turns it off. Chet Husk, Day 1 [02:15]: that cached path now runs inside the native AOT CLI.
- **Ambient files are honoured** ([08:08] to [08:10], said in the Q&A). `Directory.Build.props`,
  `Directory.Build.targets` and `nuget.config` in the file's folder scope apply and are part of the cache check.
  Output goes to a temp folder named by the hash, or to the artifacts folder if artifacts output is set.
- **Ways to run** (demonstrated, [07:41] to [07:44]). `dotnet run hello.cs`, `dotnet hello.cs`, the explicit
  `dotnet run --file hello.cs -- args` for scripts, and code piped to `dotnet run -`.
- **Shebang and extensionless files** (demonstrated, [08:03] to [08:07]). A `#!/usr/bin/env` line plus the execute
  bit runs the file directly. New: a file with no `.cs` extension runs if it starts with a shebang. The symlink
  on the PATH demo failed live ("that one's not going to work today").
- **Editor support** (demonstrated, [07:44], [07:52]). C# Dev Kit in VS Code gives IntelliSense and completion of
  file paths inside directives. "This is C#. It's not a different dialect": only the project is virtual.
- **Publish as a container** (Karlsson, Day 3 [03:24], demonstrated). `dotnet publish` on the file with a
  container target built an image from a single-file Cake script.
- **Native AOT** (Aspire talk, Day 1 [05:26], shown in passing). A single-file terminal app "compiles down with
  native AOT". No session explained how.
- **More to come** ([08:07]). Updates ship in SDK feature bands; "look for 11.0.200 to come out early next year".

### Limits and caveats, in the speakers' words

- Globs in an include: "it will disable the build caching" ([07:52] to [07:53]).
- Code piped on standard input is "fully isolated": no `nuget.config`, no `Directory.Build.props`. "It's really
  not suitable for cases where you still need to be able to control things through those ... ambient files" ([08:08]).
- Shebang: "only support on POSIX platforms like Mac and Linux" (Karlsson, Day 3 [03:34]).
- SDK directives: "they do come with some caveats as well. And if you don't need to use one, you shouldn't"
  (Aspire talk, Day 1 [05:30]; the caveats were not listed).
- Visual Studio (as heard, the sentence is garbled): it "doesn't support file-based apps" yet, so Karlsson
  converts to a project to use it (Day 3 [03:23]).
- Moving the file to another folder breaks the cache, because the key includes the path ([07:47]).

### Structuring a larger codebase with them

- **Many files and folders, no project file** (Damian Edwards, Day 2 [08:00]): "I can now express and organize my
  files in any way that I really choose. And then I can reference them across different folders. I can create
  isolated spaces for them. Or I can even reference kind of the traditional world by referencing full CS projects."
- **A real example** (Aspire talk, Day 1 [05:21] to [05:22], demonstrated). An app host that "used to be like 400
  lines" in one file now includes other files kept in a folder. The stated benefit is placement: the file "can
  live in the logical place that it rightfully owns in this repo", above the projects it orchestrates, not as a
  sibling project.
- **Sharing code** was shown three ways: include a file, reference another app's file, reference a class library
  project. Shared build settings go in `Directory.Build.props`, shared versions in `Directory.Packages.props`.
- **When a project file is still right.** No speaker gave a rule. What was said: "you could use a traditional CS
  project for this ... It's personal choice" (Aspire talk, Day 1 [05:22]); and "you can start very small and then
  you can graduate your project" by converting it when "something becomes more complex and you want a full Visual
  Studio solution" (Karlsson, Day 3 [03:23], recommended; the command name was garbled, heard as "dotnet convert").
- **Use by agents** (Day 2 [08:11], recommended in the closing chat): the host tells Copilot to write helper
  scripts as file-based apps, not PowerShell, because he can read them; Edwards had Copilot write his timing script.

### Not said in any session I could read

- **Tests** for or inside a file-based app: nothing.
- **Debugging**: only Karlsson's F5 breakpoint on a Cake file in VS Code (Day 3 [03:21]); nothing from Microsoft.
- **Publishing and native AOT** beyond the two passing mentions above.
- **Any size limit**, or any statement that a large API or a modular monolith should be built this way. Every
  demo was a script, a tool, a small web app or an app host.

## Looked at and judged not relevant

- Aspire app host, dashboard, terminal attach and Aspire skills (several talks): we do not use Aspire.
- Telerik UI for Blazor, its MCP server, WebMCP and generative UI (Maya, [00:39]).
- Azure App Service, Functions, Service Bus, Bicep, managed identity (Wiltermuth, [01:11]).
- Terminal user interfaces with Spectre.Console (Isaac Levin, [01:41]).
- Blazor WebAssembly migration from Web Forms, Wasm AOT and SIMD builds; OpenIddict with YARP turning tokens into cookies (James Hutchinson, [02:06]).
- Cake 7 as a build tool, beyond the .NET 11 facts above (Karlsson, [03:09]): our builds are plain `dotnet` and shell.
- Rx.NET and AsyncRx.NET as libraries (Ian, [04:09]): we do not use reactive streams.
- OpenFeature and flagd feature flags (Andre Silva, [04:39]): the stack doc already settles on built-in configuration first.
- Deepgram voice agents and ESP32 firmware (Charbonneau, [05:11]).
- Uno Platform Studio and Uno Platform 7.0; Copilot Fusion (Sam, [05:49] to [06:10]).
- How large language models work, a general explainer (Otto, [06:41]).
- Godot game engine details and Rider features (Hawker, [07:57] onward).
- Azure cost dashboards, Octopus Deploy, DORA scorecards, C4 diagrams from code (Palermo, [07:19] to [07:35]).
- MAUI on CoreCLR in .NET 11, camera, location and PDF handling on phones (Paul, [09:01] to [09:12]).

## Not covered

- **Days 1 and 2**: left out on purpose, except for file-based apps (section above). Their caption transcripts
  sit in the notes folder if they are ever wanted.
- **Day 4 (13 Nov) and the Day 2 after-hours premieres**: no transcript fetched, so not searched for file-based
  apps. None of their agenda titles names the topic. The agenda text is saved as `agenda.txt` in the notes folder.
- **Words the transcript got wrong.** A local Whisper run mishears names. Product and package names marked
  "(as heard)" should be looked up before anyone relies on the spelling.
