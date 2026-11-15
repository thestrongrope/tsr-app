# Lane search: `GET /search` (build-out, 12 Nov 2026)

Built from PHP, not yet tested end to end. PHP paths are under `build/parity-php/src/web/`. Slice: `domains/search/api/features/search/Search.cs`;
contract: `domains/search/spec/api.yaml`; unit tests: `domains/search/api/domain/*.Tests.cs` (39).

## PHP, step by step

| Step | PHP | New code |
|---|---|---|
| Sign in with member creation | `routes/search.php:30` `api_authenticate(true)` | `RequireMember(createsMember: true)` (catalog auth `create`) |
| Gender must be numeric (400 "User gender not set; update profile first") | `search.php:32` `api_require_identity` (`routes/classes.php:124`, `functions.php:279`) | `SearchFacts.HasNumericGenderAsync` over `membership.v_members` |
| Permission `classes:read` (403) | `search.php:33` | `Permissions.CanAsync(.., AccessTarget.None)` |
| `q` trimmed, 2 to 100 characters (422) | `search.php:35-43` | `SearchRequestRules.Parse` |
| `kinds` comma list, all when blank, unknown is 422 | `search.php:45-52` | `SearchRequestRules.Parse` |
| Per kind: plan, query (100 hits), re-check, cap 50 | `models/search.php:47-85` (`CAP` :28, `FETCH` :30) | `SearchEngine.SearchAsync` |
| Reach per kind | `models/search.php:88-170` `plan()` | `SearchPlans.PlanFor` |
| Reach to filter | `models/searchfilter.php:48` `toEs`, `:24` `allows` | `SearchPlans.ClassPlan`, `SearchPlans.Allows` |
| The query | `models/search.php:173` `query()`; `searchindex.php:177` `searchRaw` | `ElasticSearchIndex.SearchAsync` |
| Reach inputs | `models/permissions.php:147` `searchReach`, `:124` `managedReach` | `Permissions.ReachAsync` (`Reach.Search`, `Reach.All/Gender/ClassIds`) |
| Teacher visibility | `models/teachers.php:776` `canView` | `SearchPlans.TeacherPlan` and `Search.cs` `AccessOfAsync` |
| Response | `search.php:56-67` | `Search.cs` `Body` (camelCase JSON, same keys) |

## The index (what the feeder worker must produce)

Index name `tsr-search` (no prefix setting), one index for every kind, document id `"<kind>:<id>"` (`searchindex.php:30`, `docId`). Mapping `searchindex.php:304`:
`kind` keyword, `id` long, `name` text (analyzer `name_prefix`: standard tokenizer, lowercase, asciifolding, arabic_normalization, edge_ngram 2 to 15;
search analyzer `name_search`: same without n-grams, truncate 15), `gender` integer, `level` keyword, `level_id` integer, `class_ids` long, `class_genders` integer,
`token` long. Every document has every field (empty or 0 where unused).

| Kind | `id` | `name` | other fields the query relies on |
|---|---|---|---|
| class | class id | class **code** (HTML entities decoded) | `class_ids=[id]`, `class_genders=[gender]`, `level` |
| teacher | member token (>0) | member name | `gender` (1, 2, or 0 unknown), `token` |
| guide | class level id | `"<level name> guide"` | `level`, `level_id` |
| student | member token (>0) | member name | `class_ids`, `class_genders` (their current active classes), `token`, `gender` |
| subscriber | member token (>0) | member name | `token`, `gender` |

A person with a current enrolment in an active class is a student, otherwise a subscriber (`searchsource.php:person`). Teacher: `teachers.status = 'A'`.
The query reads back `id` and `name` only (`_source` filter).

## Reach, exactly as built (filter is in the query; the re-check only narrows)

Inputs: `classes:read` reach (`All`, `Gender`, `ClassIds` = assigned classes, `Search` = assigned + own + taught + enrolled classes and `Self`), `teachers:lookup` search reach.

| Kind | Not queried (no group) when | Filter in the query | Re-check against the database |
|---|---|---|---|
| class | `Search` is empty | none for All; else should(`class_genders` = gender, `class_ids` in ids, `token` = self), min 1 | class active; `Allows(Search, [id], [gender], 0)`; title code, subtitle level name |
| guide | `Search` is empty | none (name only) | an active class of the level lies in `Search`; result id is that class's id (lowest id) |
| student | managed reach (`All`, `Gender`, `ClassIds`, no self) is empty | none for All; else should(`class_genders`, `class_ids`) | keeps the member's current active classes the managed reach covers; none left, dropped; subtitle their codes |
| teacher | `teachers:lookup` search reach is empty | none for All; else `gender` in the genders `canView` accepts (gender 1 if `can(gender 1)` or `can(teacher_gender 1)`; gender 2 if `can(gender 2)`); no gender, empty group without a query | member still exists; title is the fresh name |
| subscriber | the caller does not hold `classes:read` at scope all | none | member exists and has no current class |

Differences from PHP, all stricter or equal in what is shown: PHP does not filter teachers in the query (every active teacher is fetched, then `canView` filters); here the genders are in
the query, so the 100 fetched hits are not wasted on unreachable teachers. `canView`'s "gents who actually teach" check is not re-run (the index holds active teachers only, see assumption 3).
The student/subscriber/class re-checks are batched (one read per kind), not one read per hit.

## Settings

`TSR_ELASTICSEARCH_URL` (PHP `ELASTICSEARCH_URL`), `TSR_ELASTICSEARCH_PASSWORD` (PHP `ELASTICSEARCH_PASSWORD`, basic auth, user `elastic`, never logged). Both optional. Without a valid http(s)
URL the API starts and every requested kind is in `unavailable` (PHP: "Elasticsearch is not configured"). Request timeout 5 seconds (PHP 5, connect 2: the client has no separate connect timeout set here).
Hits per kind: 100 fetched, 50 kept (`capped` when 50 passed).

## Package

`Elastic.Clients.Elasticsearch` 9.5.3 (central version in `Directory.Packages.props`, referenced only by `domains/search/api`). Transitive: `Elastic.Transport` 1.1.0, `Elastic.Esql` 0.11.0.
NuGet audit: no warning, build at 0 warnings. The dev compose of the PHP stack runs Elasticsearch 9.2.3, same major. The typed query objects express PHP's query completely, so no low-level JSON is sent.

## Assumptions

1. The query text is the value of a `match` clause on `name` with operator `and` (as PHP); no query-string syntax exists, so `*`, `:` and quotes are plain text.
2. A NUL inside `q` is a 422 (stricter than PHP); leading and trailing NULs are trimmed as PHP `trim` does. Length counts code points as `mb_strlen`.
3. The re-check cannot read `teachers` (no published view) or the guide text and slug rules (`GuideSlugs` is classes' internal): a teacher is kept if the member exists, a guide if the level has a reachable class. The feeder owns teacher and guide freshness.
4. Student titles and class subtitles come from the database through `v_members`, `v_classes`, `v_enrolments`; the index `name` is used for guide titles only. `v_members` may hold several rows per token; the first by `user_id` is used (PHP: first row of `users`, order unspecified).
5. A group with `capped: true` has exactly 50 results, as PHP (`count >= CAP`).
6. The 400 gender check runs before the 403, as PHP; it reads the caller's gender through `membership.v_members` with its own short-lived connection (a 15 second timeout), because search has no database context.
7. `kinds=0` or `kinds=,` yields an empty answer (PHP `array_filter` drops them), not a 422.

## Missing worker

Nothing writes to the index in the new API. PHP's `cli/drain_search.php` (outbox to index, `searchoutbox.php`) and `cli/reindex_search.php` (nightly reconcile) feed it today. The new worker must write the documents above under `tsr-search`; until it exists search shows what PHP indexed.

## Looks like a security or privacy hole in PHP (copied, flagged)

- The query `q` is unbounded in word count (only 100 characters): a request with 50 two-letter words makes a heavy `and` query; copied (bound by the 100 characters and the 5 second timeout).
- PHP's students filter lets a gender admin find students of any class of their gender including classes the member left in the same index document set; the re-check against `class_students` is what removes stale ones. Here too: a stale index can hide, and the re-check removes the rest, but only through classes.
- The index holds the names of every member with a token (subscribers included) in one index; the only barrier is the query filter plus the re-check. The test phase should treat the index credentials as sensitive.
- The password is sent in basic auth over whatever scheme `TSR_ELASTICSEARCH_URL` has; nothing enforces https.
- Students' subtitle lists class codes of the classes the caller manages only (not all of theirs): kept, it is the right behaviour.

## Test phase must prove

For every kind, with a real index and the synthetic fixtures:
- [ ] A caller never gets a hit outside their reach: class (all, gender, assigned, own, taught, enrolled, self), guide (only through a reachable class), student (only through a managed class; a student cannot find classmates), teacher (per gender rule, gents who teach for a ladies manager), subscriber (scope all only).
- [ ] A caller with no reach for a kind gets no group for it and no query is sent (check the index request log).
- [ ] A stale index document (member removed from a class, class deactivated, member now enrolled) is dropped by the re-check.
- [ ] The reach filter is in the request body sent to Elasticsearch (not applied afterwards): capture the request.
- [ ] `q` with `*`, `?`, `:`, `"`, `\`, `OR`, `AND`, brackets and 100 characters is matched as plain words and never causes a 500; NUL inside is 422; 1 or 101 characters is 422; unknown `kind` is 422; `kinds=0`, `kinds=,` empty answer.
- [ ] Order of guards: 401, 400 (non-numeric gender), 403 (no `classes:read`), 422.
- [ ] Elasticsearch down, unconfigured, slow (over 5 seconds), a 4xx or 5xx: the kind is in `unavailable`, the others still answer, status 200.
- [ ] The cap: 50 per kind, `capped` true only at 50.
- [ ] Parity with PHP on the same index: the same groups, ids, titles and subtitles (known difference: teachers are filtered in the query; the same visible set).
- [ ] No query text or member data in logs; the password never appears.
- [ ] Hurl: `hosts/api/spec/planned-surface.hurl` no longer has a search 501 (removed); its 401 and 405 checks for `/search` still hold.
