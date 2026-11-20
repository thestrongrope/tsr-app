#!/usr/bin/env bash
# Copies the PUBLISHED content of the website repository into this repository's content/ folder (LIB-R29, LIB-R30, LIB-D19). Drafts never enter.
# Usage: tools/content-import.sh <source directory> [destination directory]
#   source        the website's content folder: it holds articles/, categories/, pages/ and lectures/
#   destination   default: content under the repository root; any other destination must be a folder named "content", and never the source, in it or round it
# Copies: articles/*.md whose front matter (between the first two "---" lines) has the line "status: publish" or "status: published" (the value bare, or in single or double quotes),
# every categories/*.md, every pages/*.md but five the old website redirects (RETIRED_PAGES; no status is read, as the old page route reads none), and each file the publications page links as "file: /downloads/..." or any page writes as "/downloads/...pdf", from <source>/../public/downloads/ (a missing one refuses, exit 2). The text files are taken from directly in their folders only; the linked files keep their folders below downloads/. The destination's articles, categories, pages and downloads are replaced
# (a file removed or unpublished at the source leaves); its README.md stays. No published article: nothing changes and the exit code is 1; a refusal exits 2.
# Lectures: <source>/lectures/lectures.ndjson, trimmed with jq to the eight keys the site shows (no transcript, no embedding, no chapter summary), into lectures/lectures.ndjson. A source without the file, or a file jq cannot read, refuses (exit 2).
# After it: run `dotnet test domains/content/api/tests` and only then `git add content` (see content/README.md).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export LC_ALL=C

refuse() { echo "content-import: $1" >&2; exit 2; }

[ "$#" -ge 1 ] && [ "$#" -le 2 ] || refuse "usage: tools/content-import.sh <source directory> [destination directory]"
SRC="$1"
DEST="${2:-$ROOT/content}"
[ -d "$SRC" ] || refuse "the source is not a directory"
[ -d "$SRC/articles" ] || refuse "the source has no articles folder"
[ -f "$SRC/lectures/lectures.ndjson" ] || refuse "the source has no lectures/lectures.ndjson"
command -v jq >/dev/null 2>&1 || refuse "jq is needed to trim the lectures and was not found"

DEST="${DEST%/}"
[ "$(basename "$DEST")" = "content" ] || refuse "the destination must be a folder named content"
DEST_PARENT="$(dirname "$DEST")"
[ -d "$DEST_PARENT" ] || refuse "the destination's parent folder does not exist"
DEST="$(cd "$DEST_PARENT" && pwd -P)/content"
SRC="$(cd "$SRC" && pwd -P)"
# The destination's folders are replaced, so it must never be the source, lie in it or hold it.
case "$DEST/" in "$SRC"/*) refuse "the destination is the source or lies inside it" ;; esac
case "$SRC/" in "$DEST"/*) refuse "the source lies inside the destination" ;; esac
DEST_PARENT="$(dirname "$DEST")"

QUOTE="'"
PUBLISHED="^status:[[:space:]]*(publish|published|\"publish\"|\"published\"|${QUOTE}publish${QUOTE}|${QUOTE}published${QUOTE})[[:space:]]*\$"

# is_published: reads one file on stdin; succeeds when its front matter has a published status line.
is_published() {
  awk -v re="$PUBLISHED" '
    { line = $0; sub(/\r$/, "", line) }
    line == "---" { fences++; if (fences == 2) exit }
    fences == 1 && line ~ re { found = 1 }
    END { exit(found ? 0 : 1) }
  '
}

STAGE="$(mktemp -d "$DEST_PARENT/.content-import.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/articles" "$STAGE/categories" "$STAGE/pages" "$STAGE/downloads" "$STAGE/lectures"

ARTICLES=0
LEFT_OUT=0
for file in "$SRC"/articles/*.md; do
  [ -f "$file" ] && [ ! -L "$file" ] || continue
  if is_published < "$file"; then
    cp "$file" "$STAGE/articles/"
    ARTICLES=$((ARTICLES + 1))
  else
    LEFT_OUT=$((LEFT_OUT + 1))
  fi
done

CATEGORIES=0
for file in "$SRC"/categories/*.md; do
  [ -f "$file" ] && [ ! -L "$file" ] || continue
  cp "$file" "$STAGE/categories/"
  CATEGORIES=$((CATEGORIES + 1))
done

# The fixed pages (the site shows each at /<name>/): every pages/*.md of the source except these five, which the old website redirects to its home page.
# The old website's page route does not look at "status", so neither does this.
RETIRED_PAGES="home account my-account register registration"
PAGES=0
for file in "$SRC"/pages/*.md; do
  [ -f "$file" ] && [ ! -L "$file" ] || continue
  case " $RETIRED_PAGES " in *" $(basename "$file" .md) "*) continue ;; esac
  cp "$file" "$STAGE/pages/"
  PAGES=$((PAGES + 1))
done

# The linked files: each "file: /downloads/..." line of the publications page and each "/downloads/...pdf" address written in any page name a file in the website's public/downloads, which sits beside its content folder.
# A linked file the source does not hold stops the import before anything is replaced. The guard (RepositoryContentTests) checks that this reading missed no link.
FILES=0
LINKS="$STAGE/links.txt"
: > "$LINKS"
if [ -f "$STAGE/pages/tsr-publications.md" ]; then
  sed -n -E 's/\r$//; s/^[[:space:]-]*file:[[:space:]]*//p' "$STAGE/pages/tsr-publications.md" | sed -E "s/^['\"]//; s/['\"][[:space:]]*$//" >> "$LINKS"
fi
if [ "$PAGES" -gt 0 ]; then
  grep -h -o -E "/downloads/[^[:space:])\"'<>?#]*\.pdf" "$STAGE"/pages/*.md >> "$LINKS" || true
fi
sort -u "$LINKS" -o "$LINKS"
while IFS= read -r link; do
  case "$link" in /downloads/*) ;; *) continue ;; esac
  case "/$link/" in */../*) refuse "a linked file name is not a plain path: $link" ;; esac
  from="$SRC/../public$link"
  [ -f "$from" ] && [ ! -L "$from" ] || refuse "the source does not hold the linked file: $link"
  mkdir -p "$STAGE$(dirname "$link")"
  cp "$from" "$STAGE$link"
  FILES=$((FILES + 1))
done < "$LINKS"
rm -f "$LINKS"

# The lectures: the eight keys of the site's lecture page and, of each chapter, its start and title.
jq -c '{slug, title, excerpt, tags, language, publishedDate, durationSec, chapters: [.chapters[] | {start_sec, title}]}' "$SRC/lectures/lectures.ndjson" > "$STAGE/lectures/lectures.ndjson" || refuse "jq could not read lectures/lectures.ndjson"
LECTURES=$(wc -l < "$STAGE/lectures/lectures.ndjson" | tr -d ' ')

if [ "$ARTICLES" -eq 0 ]; then
  echo "content-import: no published article in the source; nothing changed" >&2
  exit 1
fi

mkdir -p "$DEST"
for folder in articles categories pages downloads lectures; do
  rm -rf "${DEST:?}/$folder"
  mv "$STAGE/$folder" "$DEST/$folder"
done
echo "copied $ARTICLES articles, $CATEGORIES categories, $PAGES pages, $FILES files, $LECTURES lectures; left out $LEFT_OUT articles"
