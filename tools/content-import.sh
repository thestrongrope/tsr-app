#!/usr/bin/env bash
# Copies the PUBLISHED content of the website repository into this repository's content/ folder (LIB-R29, LIB-R30, LIB-D19). Drafts never enter.
# Usage: tools/content-import.sh <source directory> [destination directory]
#   source        the website's content folder: it holds articles/, categories/ and pages/
#   destination   default: content under the repository root; any other destination must be a folder named "content", and never the source, in it or round it
# Copies: articles/*.md whose front matter (between the first two "---" lines) has the line "status: publish" or "status: published" (the value bare, or in single or double quotes),
# every categories/*.md, and pages/tsr-publications.md. Files directly in those folders only. The destination's articles, categories and pages are replaced
# (a file removed or unpublished at the source leaves); its README.md stays. No published article: nothing changes and the exit code is 1; a refusal exits 2.
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
mkdir -p "$STAGE/articles" "$STAGE/categories" "$STAGE/pages"

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

PAGES=0
PAGE="$SRC/pages/tsr-publications.md"
if [ -f "$PAGE" ] && [ ! -L "$PAGE" ]; then
  cp "$PAGE" "$STAGE/pages/"
  PAGES=1
fi

if [ "$ARTICLES" -eq 0 ]; then
  echo "content-import: no published article in the source; nothing changed" >&2
  exit 1
fi

mkdir -p "$DEST"
for folder in articles categories pages; do
  rm -rf "${DEST:?}/$folder"
  mv "$STAGE/$folder" "$DEST/$folder"
done
echo "copied $ARTICLES articles, $CATEGORIES categories, $PAGES pages; left out $LEFT_OUT articles"
