# content/

The published content the Library and the static site read: `articles/*.md`, `categories/*.md`, `lectures/lectures.ndjson` (the lecture library, tsr-web's full file: 13 keys per lecture, the transcript and the vector too, about 22.7 MB; the static site reads eight of the keys at build time and the search feed reads them all, `domains/content/capabilities/lectures.md`), `pages/*.md` (the publications page, which the API reads, and the fixed pages, which only the static site reads, at build time) and the publication files they link (`downloads/**/*.pdf`), in the layout of the website's
content files (`domains/content/api/domain/ContentFiles.cs`). The folder holds **published content only** (LIB-D19): a draft committed here is public for good.
Never edit these files by hand; copy them from the website repository with the script below.

## Where the files come from

The content folder of the website repository (`tsr-web`), taken from a clean checkout of its default branch; the commit message of an import names that commit.
The publication files come from the website's `public/downloads/` folder, which sits beside its `content/` folder. Nothing else of the source is copied: no draft, no PDF a page does not link, and not the five pages the old website redirects (`home`, `account`, `my-account`, `register`, `registration`; the list is `RETIRED_PAGES` in the script). A page is copied whatever its `status`, because the old website's page route does not look at it.

## Import

```
tools/content-import.sh <path to the website's content folder>
dotnet test domains/content/api/tests
git add content
```

The script copies an article only when its front matter has `status: publish` or `status: published`, copies each file the publications page links as `file: /downloads/...` and each `/downloads/...pdf` address a page writes (in its front matter or body) (a linked file the source lacks stops the import, naming it, with nothing changed), copies every line of `lectures/lectures.ndjson` whole except that `jq` replaces each phone-like run in a text key with `[number removed]` (LEC-R10: a run of 10 to 13 digits, and a run of 4 or more digits within 80 characters after whatsapp, phone, mobile or contact and then number or no, or after a mask (so the groups of a number said in pieces chain, at most 10 passes); the regexes are in the script header; a source without the file, a line that is not one complete JSON object, or an embedding that is not the last key stops the import with nothing changed; the vectors are copied byte for byte), replaces `articles/`, `categories/`, `pages/`, `downloads/` and `lectures/` here
(an article removed or unpublished at the source leaves; this README stays), and prints `copied <a> articles, <c> categories, <p> pages, <f> files, <l> lectures; left out <d> articles`.
It exits 1, changing nothing, when the source has no published article.
The text files are copied without carriage returns: some of the website's files have CRLF line endings and this repository stores LF, so a plain copy would show as modified with no change in it.

The test `RepositoryContentTests` is the guard: it reads this folder with the real content reader and fails when a key of `lectures/lectures.ndjson` is outside the thirteen (LEC-R9) or a text key holds a phone-like run (LEC-R10), the file is missing, a file is unexpected, an article is not published,
the set does not read whole, or an article names a category that has no file. It also fails when a page links a file this folder does not hold, when a PDF here is linked by no entry or page, and when anything below `downloads/` is not a folder or a `.pdf` file (LIB-R37; names are compared with their case, as the server does).

The files are plain git, about 210 MB (LIB-D10; the lecture file is 22.7 MB of it): every clone and worktree carries them. The site image copies the PDFs into the static site, and `pages/` and `lectures/` into its build stage; the API image carries the text folders and the lecture file, not the PDFs. This repository has no CI yet, so run it **before** `git add`, and add `content` by path,
never `git add -A`. A draft that was pushed is not removed by a revert: stop and tell the owner.

## Windows

The longest file name is 213 characters. Check out with `git config core.longpaths true`.

`tools/prove-content-import.sh` proves the script on invented sources.
