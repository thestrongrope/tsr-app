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

## Words we do not use

- "Post" or "blog": it is an **article**.
