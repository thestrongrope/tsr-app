# Independent challenge of cost-and-fit.md (Grok, 2026-11-10)

Grok (CLI, read-only) was given `cost-and-fit.md` and the headline counts of `workload-shape.md` and
asked for errors, omissions and a verdict. Its claims below were **not checked** against the official
pages by anyone else. Point 6 is not an error: the "190 API paths" figure came from the brief (the PHP
route table has 191 paths), not from the workload counts.

Outcome: both reports and this review agree. A document database does not reduce cost for this
workload; self-hosted PostgreSQL stays the choice.

## Grok's review, as returned

1. The Cosmos free-tier totals ($0, $0, $19) assume one 400 RU/s container. The floor is 400 RU/s per container. Shared throughput includes 25 containers, then +100 RU/s each. Sixty-eight containers floor near 4,700 RU/s, about $216/month after the 1,000 RU/s allowance, at every size. High confidence (Microsoft limits).

2. Firestore Enterprise pipelines group and join. Official docs (5 Nov 2026) show grouped count/sum/average and subquery joins across collections, plus string_contains and case-insensitive regex. The .NET client has exposed pipeline RPCs since Dec 2025. Caps: 60s and 128 MiB. "Neither product joins" describes Standard queries. High confidence.

3. The $36 report is Standard's per-document price. Enterprise, quoted in the note, bills 4 KiB read units at $0.05 per million. Google's scan example is about one unit per 4 KiB, so this report is a few dollars. Medium confidence on the amount.

4. One Cosmos RU is a point read of a 1 KB item by id and partition key. Microsoft's planner uses about 10 RU for an indexed query of up to 100 rows, 5 RU to insert 1 KB, and 10 RU to update. High confidence.

5. Ignore-case STRINGEQUALS is an expanded index scan. Advisor QA1003 recommends a lowercased field. The function page's "index seek" line is the case-sensitive form. High confidence.

6. "190 API paths" is not in the measurements (145 join queries, 27 files, about 120 report queries). Medium confidence.



Left out: The bill omits egress. The API sits off GCP, and Firestore charges $0.12/GiB after 10 GiB. A 120M × 1 KB report is about 112 GiB, about $12. Cosmos includes 5 GB of bandwidth, then bills. Standard documents cap at 1 MiB. A multi-table transaction fits Firestore (10 MiB, 20s lock). Cosmos transactions stay inside one partition key and 100 operations.



No. Postgres on the rented server stays about $0. The document bill is tens of dollars, or about $200 a month with one Cosmos container per table. Rebuilding about 145 joins and a 3,464-line report module costs more than that bill. Enterprise pipelines cover some grouping and lookups. A six-table report is still a new design under a 60-second cap. Keep Postgres.
