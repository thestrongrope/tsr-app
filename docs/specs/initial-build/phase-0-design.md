# Phase 0a design: MariaDB to PostgreSQL, EF Core 10 + Npgsql

"Doc" = decided by documents. "Mine" = my choice, for Asif to confirm.

| # | Question | Choice | Status |
|---|---|---|---|
| 1 | Database and stack | PostgreSQL 18 (`postgres:18`, pulled), EF Core 10.0.14, Npgsql provider 10.0.3 | Doc |
| 2 | DbContext | One per domain, internal, in `domains/<d>/api/<D>Context.cs`, deriving shared `TsrDbContext` | Doc |
| 3 | Schemas | `identity` (users), `access` (permissions, role_permissions, user_permissions), `platform` (feedback, outbox), `content` (articles) | Doc for one schema per domain |
| 4 | Where platform tables (outbox) live | In schema `platform`, mapped by `PlatformContext`; not a separate infra schema | Mine |
| 5 | Where migrations live | `domains/<d>/api/Migrations/`, with the context (open point in repo-structure.md section 6); left as EF generates them: `PublicSurfaceTests` skips EF migration and snapshot classes by base type (the script was dropped: no Bash on Windows) | Mine |
| 6 | Feedback permission rows | In access's first migration (access owns the catalog), explicit `InsertData`, not `HasData` | Mine |
| 7 | Cross-domain foreign keys (to `identity.users`) | Kept, added by hand (platform's two were dropped in phase 3a by its DropIdentityForeignKeys migration; access's had gone earlier) with `migrationBuilder.Sql` in platform and access migrations; migration order is registration order: identity, access, platform, content | Mine |
| 8 | Slice queries | LINQ with `AsNoTracking` (all today's queries are simple); `SqlQuery<T>`/`FromSql` only when LINQ is worse; commands use the context | Doc, LINQ here is mine |
| 9 | Outbox in the same transaction | The slice starts a transaction on its own context, saves the change, `Outbox.WriteAsync(context, ...)` runs `ExecuteSql` on that context (same connection and transaction), then commits. It throws without a transaction | Mine |
| 10 | citext | `TsrConvention` (model finalizing, shared): every string column without an explicit type is `citext`; `HasMaxLength(n)` also adds `CHECK (char_length(col) <= n)`; names are snake_case. The extension is created by each context's first migration (`HasPostgresExtension`) | Doc for the rule, mechanism mine |
| 11 | Case-sensitive columns | None. Allow-list in `db/tests/SchemaGuardTests.cs` is empty (it reads the catalog); `jsonb` is not text. EF's own `__ef_migrations_history` ids are varchar and not in the model | Doc |
| 12 | Apply migrations in dev | One-off compose service `migrate` = the API image run with `--migrate` (every context, registration order); production runs the same as a Dokploy job. Docs say "migration bundle"; this is the simplest equivalent for four contexts | Mine |
| 13 | Synthetic seed | `db/synthetic/seed.sql` (idempotent), compose service `seed` runs psql after migrate. Not in migrations, so production never gets it | Mine (dotnet-stack.md lists synthetic data under migrations) |
| 14 | Tooling | `dotnet-ef` 10.0.14 as a local tool (`dotnet-tools.json`); `Microsoft.EntityFrameworkCore.Design` in hosts/api, never shipped | Mine |
| 15 | Generated code | `.editorconfig` section turns analyzers off for `**/Migrations/*.cs` only | Mine |
| 16 | Types | Keep `int` keys (API contract: ids are ints); `timestamptz` via `DateTimeOffset`; connection and command timeout 5 s (migrations 300 s) | Mine |
| 17 | Retries | No `EnableRetryOnFailure` (would need an execution strategy around the transaction); the code did not retry before | Deferred |
| 18 | Contract test added | Replay with an upper-case `clientId` returns the same id (was true on MariaDB, `_ci`); platform contract count is now 8 | Mine |
