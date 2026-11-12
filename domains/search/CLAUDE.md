# domains/search/

The read model behind `GET /search`, the domain's only operation. **Status: built, not yet tested end to end (2026-11-12, build-out).**
No tables. The index is Elasticsearch (index `tsr-search`, official client `Elastic.Clients.Elasticsearch` 9.5.3), settings `TSR_ELASTICSEARCH_URL`
and `TSR_ELASTICSEARCH_PASSWORD` (both optional: without a URL every kind answers as `unavailable`). The slice is `api/features/search/Search.cs`;
the rules are in `api/domain/`: `SearchPlans` (reach to a filter in the query), `SearchEngine` (query, re-check, cap), `SearchRequestRules`
(`q`, `kinds`), `ElasticSearchIndex` (the one boundary, `ISearchIndex`), `SearchFacts` (the re-check reads, `ISearchFacts`).

- Dependencies: `access` (`Permissions`; `SearchModule.Dependencies`). Other domains are read through their published views in SQL:
  `membership.v_members` (name, the caller's gender), `classes.v_classes`, `classes.v_enrolments`.
- **Missing: the worker that feeds the index** from outbox events. Until it exists the index is fed by PHP's `drain_search` and `reindex_search`.
- Facts, flags, PHP references and the checklist for the test phase: `docs/specs/initial-build/lane-search-notes.md`.
