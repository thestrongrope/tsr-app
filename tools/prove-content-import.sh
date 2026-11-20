#!/usr/bin/env bash
# Proves tools/content-import.sh on invented sources under a temporary directory (LIB-R29, LIB-R30). No stack, no Docker, no real content.
# Prints one line per case and exits 1 on the first failure.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMPORT="$ROOT/tools/content-import.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
SRC="$WORK/source"
DEST="$WORK/out/content"
OUT="$WORK/output.txt"

fail() { echo "FAIL: $1" >&2; exit 1; }

# article <name> <status line, may be empty>: one invented article file in the source.
article() {
  { printf -- '---\ntitle: T\nslug: %s\n' "$1"; [ -z "$2" ] || printf '%s\n' "$2"; printf -- '---\nBody.\n'; } > "$SRC/articles/$1.md"
}

# listing <dir>: the files under it, relative and sorted.
listing() { (cd "$1" && find . -type f | sort); }

# run <source> <destination>: the script's output goes to $OUT, its exit code is returned.
run() {
  if "$IMPORT" "$1" "$2" > "$OUT" 2>&1; then return 0; else return $?; fi
}

expect_listing() {
  actual="$(listing "$DEST")"
  [ "$actual" = "$1" ] || fail "$2: the destination holds
$actual
expected
$1"
}

mkdir -p "$SRC/articles" "$SRC/categories" "$SRC/pages" "$WORK/out/content"
article published-bare "status: publish"
article published-double "status: \"published\""
article published-single "status: 'publish'"
article draft-one "status: draft"
article capital-publish "status: Publish"
article no-status ""
printf -- '---\ntitle: C\n---\n' > "$SRC/categories/study-habits.md"
printf -- '---\ntitle: P\npublications: []\n---\n' > "$SRC/pages/tsr-publications.md"
printf -- '---\ntitle: Other\n---\n' > "$SRC/pages/other.md"
for retired in home account my-account register registration; do printf -- '---\ntitle: Retired\n---\n' > "$SRC/pages/$retired.md"; done
printf 'not an article\n' > "$SRC/articles/x.txt"
printf 'kept readme\n' > "$DEST/README.md"

# Case 1: only the published three, the category, the publications page and the other page (the five retired pages stay out); the line; the exit code; README stays.
run "$SRC" "$DEST" || fail "case 1: exit code $?"
expect_listing "./README.md
./articles/published-bare.md
./articles/published-double.md
./articles/published-single.md
./categories/study-habits.md
./pages/other.md
./pages/tsr-publications.md" "case 1"
[ "$(cat "$OUT")" = "copied 3 articles, 1 categories, 2 pages, 0 files; left out 3 articles" ] || fail "case 1: output was: $(cat "$OUT")"
echo "ok 1: three published articles copied, three left out, the line printed"

# Case 2: an article that became a draft at the source leaves the destination.
article published-double "status: draft"
run "$SRC" "$DEST" || fail "case 2: exit code $?"
expect_listing "./README.md
./articles/published-bare.md
./articles/published-single.md
./categories/study-habits.md
./pages/other.md
./pages/tsr-publications.md" "case 2"
echo "ok 2: an unpublished article is removed from the destination"

# Case 3: a source of drafts only leaves the destination as it was and exits 1.
DRAFTS="$WORK/drafts"
mkdir -p "$DRAFTS/articles"
printf -- '---\nstatus: draft\n---\n' > "$DRAFTS/articles/d.md"
before="$(listing "$DEST")"
status=0
run "$DRAFTS" "$DEST" || status=$?
[ "$status" = 1 ] || fail "case 3: exit code $status, expected 1"
expect_listing "$before" "case 3"
echo "ok 3: no published article, exit 1, destination unchanged"

# Case 4: a destination that is not named content is refused and nothing is written, in the repository and in the temporary directory alike.
for other in "$ROOT/proof-content-import-other" "$WORK/out/other" "$WORK/out/content/.."; do
  before="$(listing "$WORK/out")"
  status=0
  run "$SRC" "$other" || status=$?
  [ "$status" = 2 ] || fail "case 4: $other gave exit code $status, expected 2"
  [ ! -e "$ROOT/proof-content-import-other" ] || fail "case 4: the refused destination was written"
  [ "$(listing "$WORK/out")" = "$before" ] || fail "case 4: $other changed the temporary folder"
done
echo "ok 4: a destination not named content is refused and not written"

# Case 5: a missing source and a source without articles/ are refused.
for bad in "$WORK/missing" "$WORK/out"; do
  status=0
  run "$bad" "$WORK/out/content" || status=$?
  [ "$status" != 0 ] || fail "case 5: $bad was accepted"
done
echo "ok 5: a missing source and a source without articles are refused"

# Case 6: a file name with a space, a percent sign and 200 characters is copied whole.
LONG="long-$(printf 'x%.0s' $(seq 1 190))"
article "odd 100%-name" "status: publish"
article "$LONG" "status: publish"
run "$SRC" "$DEST" || fail "case 6: exit code $?"
[ -f "$DEST/articles/odd 100%-name.md" ] || fail "case 6: the odd file name was not copied"
[ -f "$DEST/articles/$LONG.md" ] || fail "case 6: the long file name was not copied"
echo "ok 6: file names with a space, a percent sign and 195 characters are copied"

# Case 7: the source may not be the destination, nor lie inside it, nor hold it: a draft at the source must survive.
SITE="$WORK/site/content"
mkdir -p "$SITE/articles" "$SITE/content"
printf -- '---\nstatus: publish\n---\n' > "$SITE/articles/p.md"
printf -- '---\nstatus: draft\n---\n' > "$SITE/articles/d.md"
mkdir -p "$WORK/site/articles"
printf -- '---\nstatus: publish\n---\n' > "$WORK/site/articles/p.md"
for pair in "$SITE|$SITE" "$SITE|$SITE/content" "$WORK/site|$SITE"; do
  status=0
  run "${pair%%|*}" "${pair##*|}" || status=$?
  [ "$status" = 2 ] || fail "case 7: ${pair} gave exit code $status, expected 2"
  [ -f "$SITE/articles/d.md" ] || fail "case 7: the draft at the source was deleted"
done
echo "ok 7: a source that is, holds or lies in the destination is refused"

# Cases 8 and 9: the files the publications page links come from <source>/../public/downloads (the website keeps web/content and web/public side by side).
W="$WORK/web"
mkdir -p "$W/content/articles" "$W/content/pages" "$W/public/downloads/books" "$W/public/downloads/tsr-publications" "$WORK/out8/content"
printf -- '---\nstatus: publish\n---\n' > "$W/content/articles/p.md"
printf -- '---\ntitle: P\npublications:\n- title: One\n  file: /downloads/books/One.pdf\n- title: Two\n  file: "/downloads/tsr-publications/two.pdf"\n- title: Three\n  file: '"'"'/downloads/books/three.pdf'"'"'\n- title: Online\n  readOnlineUrl: https://example.invalid/read\n---\n' > "$W/content/pages/tsr-publications.md"
printf 'one' > "$W/public/downloads/books/One.pdf"
printf 'two' > "$W/public/downloads/tsr-publications/two.pdf"
printf 'unlinked' > "$W/public/downloads/books/unlinked.pdf"

# Case 8: a missing linked file refuses with exit 2, names the link, and leaves the destination as it was.
printf 'kept readme\n' > "$WORK/out8/content/README.md"
mkdir -p "$WORK/out8/content/downloads"
printf 'old' > "$WORK/out8/content/downloads/old.pdf"
before="$(listing "$WORK/out8")"
status=0
run "$W/content" "$WORK/out8/content" || status=$?
[ "$status" = 2 ] || fail "case 8: exit code $status, expected 2"
grep -q "/downloads/books/three.pdf" "$OUT" || fail "case 8: the output does not name the missing file: $(cat "$OUT")"
[ "$(listing "$WORK/out8")" = "$before" ] || fail "case 8: the destination changed"
echo "ok 8: a missing linked file refuses, names it, destination unchanged"

# Case 9: the linked files arrive in their folders, the unlinked one and the old one do not, and the line counts them.
printf 'three' > "$W/public/downloads/books/three.pdf"
run "$W/content" "$WORK/out8/content" || fail "case 9: exit code $?"
[ "$(listing "$WORK/out8/content")" = "./README.md
./articles/p.md
./downloads/books/One.pdf
./downloads/books/three.pdf
./downloads/tsr-publications/two.pdf
./pages/tsr-publications.md" ] || fail "case 9: the destination holds $(listing "$WORK/out8/content")"
[ "$(cat "$WORK/out8/content/downloads/books/One.pdf")" = "one" ] || fail "case 9: the file's bytes differ"
[ "$(cat "$OUT")" = "copied 1 articles, 0 categories, 1 pages, 3 files; left out 0 articles" ] || fail "case 9: output was: $(cat "$OUT")"
echo "ok 9: the three linked files arrive, the unlinked file stays out"

# Case 10: a link that climbs out of public/downloads is refused, and the destination stays as it was.
printf 'outside' > "$W/outside.pdf"
printf -- '---\ntitle: P\npublications:\n- title: Out\n  file: /downloads/../../outside.pdf\n---\n' > "$W/content/pages/tsr-publications.md"
before="$(listing "$WORK/out8")"
status=0
run "$W/content" "$WORK/out8/content" || status=$?
[ "$status" = 2 ] || fail "case 10: exit code $status, expected 2"
grep -q "not a plain path" "$OUT" || fail "case 10: the output does not say why: $(cat "$OUT")"
[ "$(listing "$WORK/out8")" = "$before" ] || fail "case 10: the destination changed"
echo "ok 10: a link that climbs out of the downloads folder is refused"
# Case 11: a PDF that a page body links is copied (front matter or body), a PDF that only a retired page links is not required, a missing one refuses.
printf -- '---\ntitle: P\npublications: []\n---\n' > "$W/content/pages/tsr-publications.md"
printf -- '---\ntitle: Book\n---\nRead [the book](/downloads/books/body.pdf) or <a href="/downloads/books/html.pdf">this</a>.\n' > "$W/content/pages/book.md"
printf -- '---\ntitle: Old\n---\n[x](/downloads/books/retired-only.pdf)\n' > "$W/content/pages/home.md"
printf 'body' > "$W/public/downloads/books/body.pdf"
status=0
run "$W/content" "$WORK/out8/content" || status=$?
[ "$status" = 2 ] || fail "case 11: exit code $status, expected 2 for a missing page link"
grep -q "/downloads/books/html.pdf" "$OUT" || fail "case 11: the output does not name the missing file: $(cat "$OUT")"
printf 'html' > "$W/public/downloads/books/html.pdf"
run "$W/content" "$WORK/out8/content" || fail "case 11: exit code $?"
[ "$(listing "$WORK/out8/content")" = "./README.md
./articles/p.md
./downloads/books/body.pdf
./downloads/books/html.pdf
./pages/book.md
./pages/tsr-publications.md" ] || fail "case 11: the destination holds $(listing "$WORK/out8/content")"
[ "$(cat "$OUT")" = "copied 1 articles, 0 categories, 2 pages, 2 files; left out 0 articles" ] || fail "case 11: output was: $(cat "$OUT")"
echo "ok 11: the PDFs a page links arrive, a retired page's link is not needed, a missing one refuses"
echo "content import proven: 11 cases"
