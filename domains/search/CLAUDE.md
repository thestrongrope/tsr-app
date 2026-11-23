# domains/search/

The read model behind `GET /search`, the domain's only operation. No tables. The index is Elasticsearch (index `tsr-search`,
official client `Elastic.Clients.Elasticsearch` 9.5.3).

## Status

Built. `GET /search` and the feed are proven end to end against a real Elasticsearch 9.2.3 (the image production uses) on the
default test stack. Production is not wired: until a worker container runs the feed there, PHP's `drain_search` and
`reindex_search` still feed the index; PHP's outbox rows for search are no longer needed by this worker.

## Dependencies

`access` (`Permissions`; `SearchModule.Dependencies`). Other domains are read through their published views in SQL:
`membership.v_members` (name, the caller's gender), `classes.v_classes`, `classes.v_enrolments`, `classes.v_teachers` (the teacher
re-check), `classes.v_guides` (the guide re-check: dropped when the guide is gone, titled from the database; only levels 2 to 5
have a page, as PHP's slugs).

## Settings

`TSR_ELASTICSEARCH_URL` and `TSR_ELASTICSEARCH_PASSWORD`, both optional: without a URL every kind answers as `unavailable`, and
`UnconfiguredSearchIndex` makes a feed tick a no-op.

## The feed: worker `search-feed`

`api/workers/SearchFeedWorker.cs`, run mode `--workers`, name in `TSR_WORKERS`.

- No per-change queue and no event consumer (owner decision): it does a FULL RECONCILE once at start and every 10 minutes (what
  PHP's `reindex_search` does nightly).
- `domain/SearchFeed.cs` is the algorithm: ensure the index, list the ids present, upsert the source in batches of 500, then bulk
  delete the ids present and not seen.
- The delete is decided per kind (the part of an index id before the colon): an id is deleted only when the source yielded at
  least one document of its kind, so one kind's read coming back empty never empties that kind. The ids kept are logged as a
  count; the last document of a kind therefore stays until the kind has a document again.
- An Elasticsearch failure ends the tick before any delete.
- Logs hold counts only. A failure line names the request and Elasticsearch's error type, never content.
- `domain/SearchDocumentSource.cs` reads the documents through the published views only (`classes.v_classes`, `v_enrolments`,
  `v_teachers`, `v_guides`, `membership.v_members`), 1000 rows a page.
- **Advisory lock key 8100001** (session lock, `pg_try_advisory_lock` on the run's own connection; a tick that finds it held is
  skipped); no other code uses it.
- Every request to Elasticsearch asks for plain JSON, so a body is sent as plain JSON too (`ElasticSearchIndex.Writer.cs`,
  `JsonType`): Elasticsearch refuses a request whose content type and Accept header disagree (400 `media_type_header_exception`).

## JSON and the native build

Nothing in `search` reads or writes JSON by reflection (`api/domain/SearchJson.cs`, a source-generated context):

- The answer: `Results.Json(new Body(...), SearchJson.Answers.Body)`. `Answers` uses the host's options (web defaults, relaxed encoder), so the bytes are as before.
- The index read: `ElasticSearchIndex` builds its client with a source serializer given `SearchJson.Default`, and `IndexedDocument` has explicit `JsonPropertyName`s. Without that, the client reads a found
  document by reflection; a native build cannot, and every kind would answer `unavailable`. No JIT test can show it (the client brings its own resolver), only a native run;
  `ConvertedJsonUseTests.Every_index_client_is_built_with_the_generated_document_reader` keeps it in place.
- A document the client cannot read makes its kind `unavailable` (the client's error is a transport error, which `SearchAsync` turns into `SearchUnavailableException`); never an empty group.
- The unit test project turns reflection serialization off, so a missing type in the context fails there. The project sets `IsAotCompatible` and the request delegate generator;
  it is in `AotAnalyzerTests`, `RunTimeEfUseTests` and `ConvertedJsonUseTests` (search owns no table, so it has no context row).

## Where things are

| Need | File |
|---|---|
| The slice | `api/features/search/Search.cs` |
| Reach to a filter in the query | `api/domain/SearchPlans.cs` |
| Query, re-check, cap | `api/domain/SearchEngine.cs` |
| `q`, `kinds` | `api/domain/SearchRequestRules.cs` |
| The one boundary, `ISearchIndex` | `api/domain/ElasticSearchIndex.cs` |
| The answer and the index document, without reflection | `api/domain/SearchJson.cs` |
| The re-check reads, `ISearchFacts` | `api/domain/SearchFacts.cs` |
| The write side, `ISearchIndexWriter`; the mapping (identical to PHP's) | `api/domain/ElasticSearchIndex.Writer.cs`, `SearchIndexMapping.cs` |
| Facts, flags, PHP references | `docs/specs/initial-build/lane-search-notes.md`, `test-edge-notes.md` |

## Checks

The default test stack runs Elasticsearch and the workers container with `search-feed` (`docker-compose.dev.yml` profile
`workers`, `docker-compose.test.yml`). `tools/contract-edge.sh test` loads its fixtures, restarts the workers container (the feed
rebuilds the index when it starts) and waits for the line "Search feed: upserted".

| File | Holds |
|---|---|
| `spec/tests/search-new-api.hurl` | `GET /search` end to end, with a real index |
| `spec/tests/search.hurl` | what is true with or without an index |
| `spec/tests/search-php-only.hurl` | the no-index answer (the PHP parity stack has none) |

The worker host must build with every worker named: `hosts/api/tests/WorkerModeTests.cs`
(`The_worker_host_builds_a_valid_container_with_every_worker_named`; services for that run mode are in `hosts/api/HostServices.cs`).
