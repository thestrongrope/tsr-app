# content: glossary

Use these words in code, tests, screens and messages. If a word is missing, add it here first.

| Term | Meaning | In code |
|---|---|---|
| **Article** | A piece of writing TSR publishes on the site. | table `articles`; `ArticleResponse` |
| **Slug** | The article's address on the site: `/articles/<slug>/`. Unique, never reused. | `slug` |
| **Body** | The article's text: plain text, paragraphs separated by a blank line. Never HTML. | `body` |
| **Published** | An article whose `published_at` is set and not in the future. Only published articles are public. | `published_at <= now` |
| **Draft** | An article with no `published_at`. Never public. | `published_at IS NULL` |
| **Scheduled** | An article whose `published_at` is in the future. Not public until then. | `published_at > now` |

The six rows above are the stub's (`GET /articles`, table `articles`). The Library reads (`/api/v1/`) use the words below; where a word is in both lists, the row below is its meaning there.

| Term | Meaning | In code |
|---|---|---|
| **Library reads** | The six public `/api/v1/` routes the app's Library calls. | `features/v1-*`; `capabilities/library-reads.md` |
| **Content files** | The Markdown files in git that are the source of the Library: articles, categories and the publications page. | `ContentFiles`; setting `TSR_CONTENT_DIR` |
| **Front matter** | The YAML block at the top of a content file that holds its fields. | `FrontMatter` |
| **Published article** | An article whose content file has `status` `publish` or `published`. Its date is not checked. | table `published_articles`; `PublishedArticle` |
| **Draft** (content file) | A content file with any other `status`. Never copied into the database. | not stored |
| **Slug** (Library) | The article's `slug` as its file writes it, which may be percent-encoded. | `slug` |
| **Decoded slug** | The slug after percent-decoding: what a request's address is matched against. | `slug_decoded` |
| **Excerpt** | The article's short summary, shown in lists. | `excerpt` |
| **Reading time** | Minutes to read an article: its words over 200, rounded up, at least 1. | `reading_minutes`; `readingTime` |
| **Related articles** | The five other published articles that share most categories and tags with one article. | `relatedArticles` |
| **Category** | A subject an article is filed under, named by its slug (its file name). A child category names its parent. | table `categories`; `Category` |
| **Tag** | A theme an article carries, named by its exact text. Its slug is made from the name on each answer. | `tags` |
| **Publication** | One entry of the publications page: a book or booklet with a download link, a read-online link, or both. | table `publications`; `Publication` |
| **Latest videos** | The newest videos of the channel's public feed, at most 50, kept in memory. | `LatestVideos`; `GET /api/v1/youtube` |
| **Feed** | The channel's public list of videos, read over HTTP. | `IVideoFeed`, `YouTubeFeed` |
| **Refresh** | One copy of the published content files into the Library tables, replacing them whole. | `ContentRefresh`; worker `content-refresh` |
| **Last complete set** | What the last successful refresh copied; kept when a refresh fails. | `refresh_state` |
| **Kept list** | The last list of videos a read of the feed gave, served when a later read fails. | `LatestVideos` |

## Words we do not use

- "Post" or "blog": it is an **article**.
