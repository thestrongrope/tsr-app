# Website port: draft epic and first feature spec (13 Nov 2026)

**Status: draft for Asif to correct. Nothing is decided and nothing is filed.** Once agreed, the epic becomes the parent
GitHub issue, each feature its own issue (the spec), and this file is deleted. Facts about today's website are in
`recon.md` and `operations.csv` beside this file and are not repeated here.

## Part 1. Epic: one home for the website

### Hypothesis
For readers of thestrongrope.com and members using the app's Library, who need articles, lectures, publications and search
to keep working while the project moves to one codebase, the website port is a move of the public website and its search
into tsr-app that leaves every live address and every supported app build working. Unlike today, where the website is a
second repository with its own stack, its own search and hand-run steps after each deploy, a change to content or search
is then made, tested and released in one place.

### Outcome
- **Outcome:** on the local stack, each of the 59 catalogued surfaces is either answered by tsr-app or recorded as dropped
  with its reason, so that tsr-web is no longer needed to serve any of them, and a change to an article or to search is made,
  tested and released from this one repository with 0 steps run by hand afterwards (today: 2 reindex calls after each deploy).
- **Leading indicator:** the number of catalogued surfaces settled, meaning its contract tests pass against both today's
  website (run locally) and tsr-app, or it is recorded as dropped. It starts at 0 of 59 and moves with each feature.
- **Guard:** 0 addresses in the catalogue's address list that answer on today's website answer "not found" on tsr-app, other than those recorded as dropped.

### MVP boundary
The smallest scope that tests the hypothesis is **Feature 1 alone, released behind the live domain**: the app's Library
reads (articles, categories, tags, publications, latest videos) answered by tsr-app while tsr-web still answers everything
else. If supported app builds keep working on that, the approach holds for the rest.

### Features, in order
| # | Feature | Benefit hypothesis | Released |
|---|---|---|---|
| F1 | The app's Library reads | We believe answering the Library's reads from tsr-app will keep every supported app build working with no app release, measured as Feature 1's Outcome states | first; the live domain can hand over one address at a time |
| F2 | Article search, with its record of searches and clicks | We believe one public search index fed automatically will remove the hand-run reindex without changing results, measured by a fixed set of 50 queries returning the same first five results as today | alone, any time after F1 |
| F3 | Lecture search by words | We believe lecture search by words from tsr-app will match today's website with search by meaning switched off, measured by a fixed set of 50 queries returning the same first five lectures | alone, any time |
| F4 | The public pages that need no search (the articles page lists and filters here; its search box comes with F5) | We believe pages built ahead of time need no running web server and are no slower, measured by time to first byte no higher than today's on the same machine | alone, after F1 |
| F5 | Search on the articles page, and the lectures page | We believe the two search pages can call the search features directly, measured by the same 50 queries giving the same first five results on the page | after F2, F3 and F4 are released; nothing is released with it |
| F6 | Redirects, shared files and app-link files | We believe every live address can keep answering from tsr-app, measured by the guard above over the catalogue's address list | alone, one address at a time |
| F7 | Lecture search by meaning | We believe search by meaning finds lectures that words miss, measured by the same 50 queries returning the same first five lectures as today's website with it switched on. Built only if production uses it today (open question 1) | after F3 |

### Out of scope for the epic
- Any redesign of the pages, new content, or new search features.
- Changing the app (its fixed website address stays; a later app release may change it).
- The lecture pipeline that produces the lecture data (it stays where it is and hands over its output).
- The archived Payload stack, and the 548 unreviewed draft articles.
- The production cutover procedure itself (Dokploy, DNS, rollback): its own plan and Asif's approval, as for the API.

### Agreed answers (Asif, 13 Nov 2026)
| # | Decision | Agreed |
|---|---|---|
| 1 | Where articles are written | Files in git stay the source; tsr-app holds a copy made from them |
| 2 | Who answers the app's website addresses | The same addresses and the same answer shape, as a named exception to the `{"detail"}` rule |
| 3 | The 196 MB of PDFs | Kept at the same addresses, stored outside the monorepo's git |
| 4 | The 17 slugs that break today's slug rule | The rule widens; no live address changes |
| 5 | Known faults in today's answers (comma-joined filters, wrong totals, id 0) | Kept as they are in F1 to F3; each fix is its own later change |
| 6 | Drafts | Never copied; only published articles leave the files |
| 7 | Reindexing | Automatic; the hand-called admin addresses are dropped |
| 8 | Decap CMS and its sign-in | Dropped: confirmed unused (Asif, 14 Nov 2026) |
| 9 | Where the website's search lives | Blended into the app's API: the search features (F2, F3) are part of the one API, not a separate website API (Asif, 14 Nov 2026) |
| 10 | Article details as built in F1 | Accepted as they are. A push notification for new content (articles, videos) is a later feature, out of scope here (Asif, 14 Nov 2026) |

### Open questions (epic)
1. Does production use lecture search by meaning today? It decides whether F7 exists.
2. Which of the small pages (self-reflection, donate, docs, pages) are kept in F4?
3. Answered 14 Nov 2026: Decap CMS is unused (answer 8).

## Part 2. Feature 1 spec: the app's Library reads

Capability document to create: `domains/content/capabilities/library-reads.md` (IDs `LIB-`).

### Problem / need
Members and guests open the app's Library to read articles, browse by category and tag, see publications and the latest
videos. Every one of those reads goes to the website, which is a separate system from the one this project now builds.
Store-live app builds have the website's address and answer shape built in, so the reads must keep answering exactly as
today while their home changes. Today an unpublished article can also be fetched by anyone who knows its address; only the
fact that drafts are kept off the server hides them.

### Outcome
- Every Library read a supported app build makes gets from tsr-app the answer it gets today (measured: LIB-Q1). The
  app's own Library journeys can only run once the live address points at tsr-app, so they belong to the cutover rehearsal.
- An unpublished article cannot be read by any address (measured: a test per read).
- A published change to an article reaches readers within 10 minutes with no manual step (number to confirm, open question 2).

### Stories
Every story is tested on content loaded for the test, so stories 1 to 10 do not wait for story 11, and stories 12 to 14 do not wait for one another.

1. As a reader, I can list published articles newest first and page through them, so that I can browse the Library.
2. As a reader, I can narrow the article list to one category, so that I see one subject.
3. As a reader, I can narrow the article list to one tag, so that I see one theme.
4. As a reader, I can narrow the article list by a word, so that I find an article I half remember.
5. As a reader, I can choose the order of the article list, so that I can read oldest first or by title.
6. As a reader, I can open one article with its text and related articles, so that I can read it and continue.
7. As a reader, I can see the categories as a tree with the number of articles in each, so that I can choose one.
8. As a reader, I can see the tags by how much they are used, so that I can choose one.
9. As a reader, I can see the publications with their download and read-online links, so that I can open a book.
10. As a reader, I can see the channel's latest videos, so that I can watch a recent lecture.
11. As an editor, I can publish an article in the content files and readers get it, so that I run no step by hand.
12. As an editor, I can change a published article and readers get the change, so that corrections reach them.
13. As an editor, I can withdraw an article and readers stop getting it, so that a mistake does not stay public.
14. As the operator, I can see that a refresh of the content failed, so that I can act before readers notice.

### Requirements
"Supported app build" means every store build at or above the minimum build the app-version catalogue names (17 today).
The exact field names, value kinds and answer shape those builds read are recorded once, in section 2 of `recon.md`; the
capability document takes them over when it is written. "Published" means the article's status in the content files is
one of the two published values in use today; its publish date is not checked, as today (open question 6).

| ID | New / changed / retired | Requirement (EARS) | Rationale | Priority |
|---|---|---|---|---|
| LIB-R1 | new | The system SHALL answer every Library read without asking the caller to sign in. | Guests use the Library; the app sends no sign-in on these reads | Must |
| LIB-R2 | new | WHEN a reader asks for the article list THEN the system SHALL return published articles newest first, 20 to a page unless the reader asks for another size from 1 to 100, starting at the position the reader asks (0 when the reader gives none, a negative one or one that is not a number), together with the total number that match and whether more remain. | Story 1 | Must |
| LIB-R3 | new | WHEN a reader gives one category THEN the system SHALL return only the articles filed under exactly that category. | Story 2 | Must |
| LIB-R4 | new | WHEN a reader gives one tag THEN the system SHALL return only the articles carrying exactly that tag. | Story 3 | Must |
| LIB-R5 | new | WHEN a reader gives a word THEN the system SHALL return only the articles whose title, summary or tags contain it. | Story 4 | Must |
| LIB-R6 | new | WHEN a reader asks for an order THEN the system SHALL order the list by publish date or by title, ascending or descending, as asked. | Story 5 | Must |
| LIB-R7 | new | IF a reader asks for an order other than those four THEN the system SHALL refuse the request with an error answer that names the fault, in the shape supported app builds read. | Today's behaviour; builds parse it | Must |
| LIB-R8 | new | IF a reader asks for a page size below 1 or above 100, or one that is not a number, THEN the system SHALL use the nearest allowed size, or 20 when it is not a number, and SHALL NOT refuse. | What today's website does (read from its code, not run); a refusal would break a build that sends one | Must |
| LIB-R9 | new | IF a request carries an option the system does not use THEN the system SHALL ignore the option and answer as if it were absent. | Supported builds send options today's website accepts and ignores | Must |
| LIB-R10 | new | WHEN a reader asks for a published article by its slug THEN the system SHALL return it with its text as HTML and up to five related articles, ordered by a score of two for each category and one for each tag they share with it, highest first. | Story 6; the app displays HTML | Must |
| LIB-R11 | new | IF a reader asks for an article that does not exist or is not published THEN the system SHALL answer "not found" and reveal nothing about it. | Closes today's hole | Must |
| LIB-R12 | new | The system SHALL never include an unpublished article in any list, count, related list or answer. | A filter fault must not leak a draft | Must |
| LIB-R13 | new | WHEN a reader asks for the categories THEN the system SHALL return them as a tree, each with its number of published articles. | Story 7 | Must |
| LIB-R14 | new | WHEN a reader asks for the tags THEN the system SHALL return each tag with its number of published articles, most used first. | Story 8 | Must |
| LIB-R15 | new | WHEN a reader asks for the publications THEN the system SHALL return each with its title, summary, kind, size, language, date of last update, and its download and read-online links as addresses relative to the website. | Story 9; the app joins them to its fixed website address | Must |
| LIB-R16 | new | WHEN a reader asks for the latest videos THEN the system SHALL return the channel's most recent videos newest first, 10 to a page unless the reader asks for another size from 1 to 50, starting where the reader asks. | Story 10 | Must |
| LIB-R17 | new | IF the video channel cannot be reached and a list was read earlier THEN the system SHALL return that list and SHALL NOT fail. | Today's behaviour; the home screen must not break | Must |
| LIB-R18 | new | IF the video channel cannot be reached and no list was ever read THEN the system SHALL return an empty list and SHALL NOT fail. | The first read after a start must not break the home screen | Must |
| LIB-R19 | new | WHEN a supported app build sends a Library request THEN the system SHALL answer with every field that build reads, under the same name, of the same kind, in the same answer shape. | No app release can be required | Must |
| LIB-R20 | new | WHEN an article is published in the content files THEN the system SHALL include it in every read within 10 minutes of the change reaching the content source the system reads, without a manual step. | Story 11 | Must |
| LIB-R21 | new | WHEN a published article is changed in the content files THEN the system SHALL return the changed article within 10 minutes of the change reaching that source, without a manual step. | Story 12 | Must |
| LIB-R22 | new | WHEN an article is withdrawn in the content files THEN the system SHALL stop returning it within 10 minutes of the change reaching that source, without a manual step. | Story 13 | Must |
| LIB-R23 | new | WHILE a refresh of the content is running, the system SHALL keep answering from the last complete set. | A half-loaded Library is worse than a stale one | Must |
| LIB-R24 | new | IF a refresh of the content fails, or finds no articles, or finds fewer than half the articles of the last complete set, THEN the system SHALL keep the last complete set and write the failure, with its time and cause, to the operator's log. | Story 14; a refresh that "succeeds" empty must not empty the Library | Must |
| LIB-R26 | new | WHEN a reader gives one language THEN the system SHALL return only the articles written in exactly that language. | Today's website does; every article is in one language today | Must |
| LIB-R25 | new | WHERE a caller says which version of an answer it already holds, the system SHALL answer "not changed" when that version is current. | Today's website does; saves data on phones | Should |

### Quality requirements
| ID | Characteristic | Requirement | Priority |
|---|---|---|---|
| LIB-Q1 | Compatibility | The same Library requests give the same answers from today's website run locally and from tsr-app, apart from a written list of differences. That list holds the unpublished-article cases of LIB-R11 and LIB-R12, which today's website fails. | Must |
| LIB-Q2 | Performance | On the local stack, 95 of 100 list or article reads answer within 300 ms (number to confirm, open question 3). | Should |
| LIB-Q3 | Security | No unpublished article is copied out of the content files into the system. | Must |

### Out of scope
- Search of articles and lectures (F2, F3). The word filter of LIB-R5 is the list's own simple filter, not search.
- The public pages (F4, F5), and redirects, files and app-link files (F6).
- Fixing known faults in today's answers (assumed answer 5), including the multi-select filter that returns nothing.
- The address that lists a category's articles: no app build calls it. It moves with F4 if the pages need it.

### Open questions (Feature 1)
1. Do the assumed answers 1, 2, 5 and 6 stand? They shape every requirement above.
2. Is 10 minutes the right delay for LIB-R20 to R22, or must a published article appear sooner?
3. Is 300 ms the right target for LIB-Q2? No measurement of today's website was taken.
4. Is "fewer than half" the right alarm for LIB-R24?
5. Is build 17 the right floor for "supported app build", or are older builds still in use?
6. Should an article whose publish date is in the future stay visible, as today, or wait for its date?
