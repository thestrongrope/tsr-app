# content/

The published content the Library and the static site read: `articles/*.md`, `categories/*.md` and `pages/tsr-publications.md`, in the layout of the website's
content files (`domains/content/api/domain/ContentFiles.cs`). The folder holds **published content only** (LIB-D19): a draft committed here is public for good.
Never edit these files by hand; copy them from the website repository with the script below.

## Where the files come from

The content folder of the website repository (`tsr-web`), taken from a clean checkout of its default branch; the commit message of an import names that commit.
Nothing else of the source is copied: no draft, no page but the publications page, no publication file (the PDFs are a later change).

## Import

```
tools/content-import.sh <path to the website's content folder>
dotnet test domains/content/api/tests
git add content
```

The script copies an article only when its front matter has `status: publish` or `status: published`, replaces `articles/`, `categories/` and `pages/` here
(an article removed or unpublished at the source leaves; this README stays), and prints `copied <a> articles, <c> categories, <p> pages; left out <d> articles`.
It exits 1, changing nothing, when the source has no published article.

The test `RepositoryContentTests` is the guard: it reads this folder with the real content reader and fails when a file is unexpected, an article is not published,
the set does not read whole, or an article names a category that has no file. This repository has no CI yet, so run it **before** `git add`, and add `content` by path,
never `git add -A`. A draft that was pushed is not removed by a revert: stop and tell the owner.

## Windows

The longest file name is 213 characters. Check out with `git config core.longpaths true`.

`tools/prove-content-import.sh` proves the script on invented sources.
