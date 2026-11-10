# Static site spike: domains composed into plain HTML (2026-11-10)

Question: can separate domains compose into the third deliverable, the static public site, the way
they already compose into the API (`hosts/api`) and the Flutter app (`hosts/app`)? Asif chose C#
Razor static rendering and two stub domains. Built in this repo, not in `~/Projects/tsr-spikes`,
because what it tests is this repo's composition.

**Answer: yes.** Each domain adds an optional `site/` project next to `api/` and `app/`;
`hosts/site` loads them from one list and writes plain HTML from the API at build time.

## What was built
| Part | Where | What |
|---|---|---|
| content domain (stub) | `domains/content/` | `articles` table (migration + 3 synthetic rows), `GET /articles` (public, published only), `api.yaml`, glossary, `CLAUDE.md`, 4 contract tests |
| Site plumbing | `shared/site/` | `SitePage` (path, title, component, parameters, nav title), `SiteApi` (reads the API, any non-2xx stops the build) |
| Domain site modules | `domains/content/site/`, `domains/platform/site/` | Razor components + `<Context>Site.PagesAsync`. content: article list and one page per article. platform: a status page from `GET /health` |
| Site host | `hosts/site/` | `SiteModules.cs` (the one list, like `hosts/api/Modules.cs`), layout, home page, `SiteBuilder` (collect, render with `HtmlRenderer`, write `<path>/index.html`) |
| Tests | `hosts/site/tests/` | 12: module boundary, each module builds alone, unique paths and nav, escaping, no `<script>`, API error stops the build, unsafe slug stops the build, no write outside the output folder |

Run: stack up, then `dotnet run --project hosts/site` (writes `build/site/`, gitignored).
`TSR_BASE_URL` picks the API.

## Results
- Generated 4 pages (`/`, `/status/`, `/articles/`, `/articles/synthetic-published-article/`)
  through the gateway. No `<script>` in any file; `<angle brackets>` in an article body come out
  as `&lt;…&gt;`; the draft and the 2099-scheduled article appear nowhere.
- Dead API (`TSR_BASE_URL=http://localhost:8099`): exit code 1, nothing written.
- Whole repo: `dotnet build` 0 warnings; unit 15, API boundary 12 (was 10: content added), site 12,
  platform contract 7, content contract 4; `flutter analyze` clean, Flutter 9.
- The content contract tests were written first and failed on the gateway's 404 before the slice
  existed. The site tests passed on their first run, so they were checked by breaking the code:
  accepting any slug fails the 3 unsafe-slug tests; content's site module calling platform's
  fails the boundary test.

## Findings
1. **Public reads change rule 4** of `domains/CLAUDE.md` (caller → access → validate). A public
   read has no caller; instead its query returns only public data. Written down in
   `domains/content/CLAUDE.md`; `domains/CLAUDE.md` rule 4 is not edited yet.
2. **DTOs are copied.** Each site module copies the response shapes it reads (`Article`, `Health`)
   from `api.yaml` instead of referencing the api project. That keeps the site an ordinary client
   of the published contract, but the copies can drift. Evidence for spike-learnings D2 (generate
   types, or check them against `api.yaml`).
3. **The boundary test sees use, not intent.** A project reference that is never used, or a bare
   `typeof`, leaves no assembly reference, so the test cannot see it. A real call is caught. Same
   limit as `hosts/api/tests`. A csproj-level check would close it.
4. **`/app-version` was not invented.** tsr-account already serves it with a shape the store app
   parses (rule 7), so platform's page uses `/health` only.
5. Razor class libraries built with warnings as errors and code-style enforcement on the first
   try; only the existing `CA1716` exemption for `Shared` was needed.

## Not done
- No real design, no Arabic/Urdu right-to-left check, no sitemap or search index, no deployment.
- `/articles` has no paging (bounded at 500).
- Adopted by Asif on 2026-11-10: `domains/CLAUDE.md` (anatomy, rules 4, 7 and 9), root
  `CLAUDE.md`, `README.md` and `repo-structure.md` now describe `site/` and `hosts/site`.
