# domains/search/

The read model behind `GET /search`. **Status: routes only (2026-11-10).** No tables, no public interface, no dependencies yet.
`GET /search` is a 501 placeholder in `api/Planned.cs` (sign-in first, then 501); building the slice deletes that line and flips its
state in `docs/specs/initial-build/operations.csv`. It will read other domains only through their listed public interfaces, never their tables
(`domains/CLAUDE.md` rule 7).
