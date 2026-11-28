# Synthetic lecture fixture

Twelve INVENTED lectures (no real lecture text, speaker, title or video id; the "video ids" are `SYNTHLEC001` to `SYNTHLEC012`) in the layout of tsr-web's `content/lectures/lectures.ndjson`: the 12 content keys and, last, `embedding`.
The vectors are made by `tools/embed-lecture-fixture.sh` (the embedding container, passage mode, `BAAI/bge-small-en-v1.5`) and committed; the guard is `domains/search/api/domain/LectureFixture.Tests.cs`.
Languages: en 5, hi 5, ar 2. `SYNTHLEC009` has no vector on purpose.

Each case of `docs/specs/website-port/search-port-plan.md` section 5 is one lecture:

| Lecture | Case |
|---|---|
| `SYNTHLEC001` | TC-SRCH-R7-01: a chapter title phrase ("first hour of the morning") that is not in the title; the chapter comes back in `matchedChapters` |
| `SYNTHLEC002` | TC-SRCH-R7-03: a misspelt word ("quelmbry", asked as "quelmbri") held in one transcript |
| `SYNTHLEC003` | TC-SRCH-R7-02: a word only it holds ("zorvath"), so the strict query has fewer than 3 hits and the fuzzy query is sent |
| `SYNTHLEC004` | TC-SRCH-R10-01: a concept ("grief") that none of its keywords names: found by meaning only |
| `SYNTHLEC005`, `SYNTHLEC006` | the same date (browse order with equal dates), en and hi: TC-SRCH-R9-01 |
| `SYNTHLEC007`, `SYNTHLEC008`, `SYNTHLEC010` | hi lectures: the language filter, in the keyword and the meaning part |
| `SYNTHLEC009` | TC-SRCH-R10-03: no vector; indexed without error, found by keywords only |
| `SYNTHLEC011` | ar, the newest: first in browse (TC-SRCH-R8-01) |
| `SYNTHLEC012` | ar, the oldest-but-one: the end of the browse (TC-SRCH-R13-01, `limit=5&offset=10` gives 2) |
