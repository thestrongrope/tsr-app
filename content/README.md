# content/

The published content the Library and the static site read: `articles/*.md`, `categories/*.md`, `pages/tsr-publications.md` and the publication files it links (`downloads/**/*.pdf`), in the layout of the website's
content files (`domains/content/api/domain/ContentFiles.cs`). The folder holds **published content only** (LIB-D19): a draft committed here is public for good.
Never edit these files by hand; copy them from the website repository with the script below.

## Where the files come from

The content folder of the website repository (`tsr-web`), taken from a clean checkout of its default branch; the commit message of an import names that commit.
The publication files come from the website's `public/downloads/` folder, which sits beside its `content/` folder. Nothing else of the source is copied: no draft, no page but the publications page, no PDF the page does not link.

## Import

```
tools/content-import.sh <path to the website's content folder>
dotnet test domains/content/api/tests
git add content
```

The script copies an article only when its front matter has `status: publish` or `status: published`, copies each file the publications page links as `file: /downloads/...` (a linked file the source lacks stops the import, naming it, with nothing changed), replaces `articles/`, `categories/`, `pages/` and `downloads/` here
(an article removed or unpublished at the source leaves; this README stays), and prints `copied <a> articles, <c> categories, <p> pages, <f> files; left out <d> articles`.
It exits 1, changing nothing, when the source has no published article.

The test `RepositoryContentTests` is the guard: it reads this folder with the real content reader and fails when a file is unexpected, an article is not published,
the set does not read whole, or an article names a category that has no file. It also fails when the page links a file this folder does not hold, when a PDF here is linked by no entry, and when anything below `downloads/` is not a folder or a `.pdf` file (LIB-R37; names are compared with their case, as the server does).

The files are plain git, about 187 MB (LIB-D10): every clone and worktree carries them. The site image copies them into the static site; the API image does not carry them. This repository has no CI yet, so run it **before** `git add`, and add `content` by path,
never `git add -A`. A draft that was pushed is not removed by a revert: stop and tell the owner.

## Windows

The longest file name is 213 characters. Check out with `git config core.longpaths true`.

`tools/prove-content-import.sh` proves the script on invented sources.
