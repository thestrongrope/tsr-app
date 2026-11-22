# Issue 100: each converted read of `content` and the test in which it returns a row

TC-CON-R1-03 (inspection). `DbRow` checks a row's shape on the first row, so a read that never returns a row in a test checks nothing (#96).
Counted by reading every `ListAsync` and `ScalarAsync` in `domains/content/api` (not `Migrations/`, not tests): **8 reads**
(the plan counted 8). No `ScalarAsync` is used. The copy's inserts, updates and deletes run through `ExecuteAsync` and are writes, not reads.
The `GET /api/v1/youtube` route reads a public feed, not the database.
Golden scenarios are in `db/tests/ContentGoldenScenarios.cs` and `ContentGoldenTests.cs`, their answers in `db/tests/golden/content/`. Made by opening each golden file, not by its name.

| # | Read | File:line | Returns a row in |
|---|---|---|---|
| 1 | the article list page and its count | `features/v1-articles/V1Articles.cs:102` | golden `lib-articles-sorts`, `lib-articles-filters`, `lib-articles-paging` (`GET /api/v1/articles` answers `data` with articles) |
| 2 | one article by slug, with five related | `features/v1-article/V1Article.cs:70` | golden `lib-article` (`GET /api/v1/articles/a-first-look-at-margin-notes` answers the article and its related list) |
| 3 | the category tree with counts | `features/v1-categories/V1Categories.cs:48` | golden `lib-categories` (`foundations` and the other categories, with counts) |
| 4 | the tags by use | `features/v1-tags/V1Tags.cs:45` | golden `lib-tags` (`Study Skills` with 7 articles first) |
| 5 | the publications | `features/v1-publications/V1Publications.cs:41` | golden `lib-publications` (`A Pocket Guide to Margin Notes` first; `?language=English` filters) |
| 6 | the surahs | `features/holy-quran/HolyQuran.cs:33` | golden `holy-quran` (`GET /holy-quran` as 900001 lists 3 surahs) |
| 7 | the stub article list | `features/list-published-articles/ListPublishedArticles.cs:38` | golden `old-article-list` (`GET /articles` lists `stub-twin` and `stub-old`) |
| 8 | the copy's state row | `domain/ContentRefresh.cs:89` | golden `copy-stores-rows` (copy 2 reads the row copy 1 wrote) and `copy-keep-paths` (steps 2 to 7 read the row step 1 inserted) |

All 8 return a row in a deterministic test.
