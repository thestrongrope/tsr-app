# parity-php

The tsr-account PHP mobile API on SYNTHETIC data only, so one set of HTTP contract tests (Hurl) can run
against PHP and against the new API. Compose project `tsr-parity`, its own network, volumes and image.

**It never holds real data.** The database is built only from tsr-account's `tools/synthetic-data`
(emails end `.invalid`). Nothing here may point at, copy from or reuse tsr-account's own containers,
volumes or `.env`. `parity.env` holds local-only placeholders; put no real secret, key or URL in it.

Services: `db` (MariaDB 11.4), `firebase-emulator` (Auth emulator, so tokens need no Google call),
`api` (PHP, plain HTTP on 127.0.0.1:18091), `synth-build` (one-shot loader). Emulator on 127.0.0.1:19199.
The PHP source is `build/parity-php/src/`, a `git archive` of tsr-account `develop` (gitignored).

Run from the repo root, with `P` as in `docs/specs/initial-build/php-parity-feedback.md`
(`docker compose -p tsr-parity -f tools/parity-php/compose.parity.yml --env-file tools/parity-php/parity.env`):

- Start: `P up -d --wait db firebase-emulator`, then once `P --profile load run --rm synth-build`, then `P up -d --wait api`.
- Token: `tools/parity-php/mint-token.sh <synthetic .invalid email>` writes `build/parity-php/token.vars`.
  Emulator accounts live in memory: run it again after the emulator restarts.
- Stop (keeps the data): `P stop`.
- Reset (deletes the database): `P down -v`, then start and load again.
- Refresh the PHP source: delete `build/parity-php/src/`, re-run the `git archive` line in the doc, `P build api`.

Synthetic tokens here start at 1, not 900000 (the generator's choice); `token = 0` rows are guests.
