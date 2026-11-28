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

# lectures <file>: an invented lecture file of two lines in the full form of the website's file: 13 keys (the second line has no embedding, as 19 real lectures have none),
# chapters of start_sec, title, summary and url, and a vector with an E exponent, which a JSON tool would print as e.
lectures() {
  mkdir -p "$(dirname "$1")"
  {
    printf '%s\n' '{"slug":"abcdefghijk","title":"First","url":"https://example.invalid/a","excerpt":"E","content":"words","search_phrases":["p"],"key_points":["k"],"tags":["t"],"language":"en","publishedDate":"2026-01-02T03:04:05Z","durationSec":78,"chapters":[{"start_sec":3,"title":"C","summary":"S","url":"https://example.invalid/c"}],"embedding":[0.1,1.5E-05,-0.25]}'
    printf '%s\n' '{"slug":"bcdefghijkl","title":"Second","url":"https://example.invalid/b","excerpt":"","content":"words","search_phrases":[],"key_points":[],"tags":[],"language":"hi","publishedDate":"2025-01-02T03:04:05Z","durationSec":0,"chapters":[]}'
  } > "$1"
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
lectures "$SRC/lectures/lectures.ndjson"
printf 'kept readme\n' > "$DEST/README.md"

# Case 1: only the published three, the category, the publications page and the other page (the five retired pages stay out); the line; the exit code; README stays.
run "$SRC" "$DEST" || fail "case 1: exit code $?"
expect_listing "./README.md
./articles/published-bare.md
./articles/published-double.md
./articles/published-single.md
./categories/study-habits.md
./lectures/lectures.ndjson
./pages/other.md
./pages/tsr-publications.md" "case 1"
[ "$(cat "$OUT")" = "copied 3 articles, 1 categories, 2 pages, 0 files, 2 lectures; left out 3 articles" ] || fail "case 1: output was: $(cat "$OUT")"
echo "ok 1: three published articles copied, three left out, the line printed"

# Case 2: an article that became a draft at the source leaves the destination.
article published-double "status: draft"
run "$SRC" "$DEST" || fail "case 2: exit code $?"
expect_listing "./README.md
./articles/published-bare.md
./articles/published-single.md
./categories/study-habits.md
./lectures/lectures.ndjson
./pages/other.md
./pages/tsr-publications.md" "case 2"
echo "ok 2: an unpublished article is removed from the destination"

# Case 3: a source of drafts only leaves the destination as it was and exits 1.
DRAFTS="$WORK/drafts"
mkdir -p "$DRAFTS/articles"
lectures "$DRAFTS/lectures/lectures.ndjson"
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
lectures "$SITE/lectures/lectures.ndjson"
lectures "$WORK/site/lectures/lectures.ndjson"
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
lectures "$W/content/lectures/lectures.ndjson"

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
./lectures/lectures.ndjson
./pages/tsr-publications.md" ] || fail "case 9: the destination holds $(listing "$WORK/out8/content")"
[ "$(cat "$WORK/out8/content/downloads/books/One.pdf")" = "one" ] || fail "case 9: the file's bytes differ"
[ "$(cat "$OUT")" = "copied 1 articles, 0 categories, 1 pages, 3 files, 2 lectures; left out 0 articles" ] || fail "case 9: output was: $(cat "$OUT")"
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
./lectures/lectures.ndjson
./pages/book.md
./pages/tsr-publications.md" ] || fail "case 11: the destination holds $(listing "$WORK/out8/content")"
[ "$(cat "$OUT")" = "copied 1 articles, 0 categories, 2 pages, 2 files, 2 lectures; left out 0 articles" ] || fail "case 11: output was: $(cat "$OUT")"
echo "ok 11: the PDFs a page links arrive, a retired page's link is not needed, a missing one refuses"
# Case 12: the lectures file arrives whole, every line byte for byte (13 keys, the E exponent, a chapter's summary and url); a source without it is refused, so is one that is not JSON, and the destination stays as it was.
LEC="$DEST/lectures/lectures.ndjson"
run "$SRC" "$DEST" || fail "case 12: exit code $?"
[ "$(wc -l < "$LEC" | tr -d ' ')" = 2 ] || fail "case 12: the copied file does not have two lines"
cmp -s "$SRC/lectures/lectures.ndjson" "$LEC" || fail "case 12: the copied file is not the source file byte for byte"
NOLEC="$WORK/nolec"
cp -R "$SRC" "$NOLEC"
rm "$NOLEC/lectures/lectures.ndjson"
before="$(listing "$DEST")"
status=0
run "$NOLEC" "$DEST" || status=$?
[ "$status" = 2 ] || fail "case 12: a source without the file gave exit code $status, expected 2"
grep -q "the source has no lectures/lectures.ndjson" "$OUT" || fail "case 12: the output does not say why: $(cat "$OUT")"
[ "$(listing "$DEST")" = "$before" ] || fail "case 12: the destination changed"
printf 'not json\n' > "$NOLEC/lectures/lectures.ndjson"
status=0
run "$NOLEC" "$DEST" || status=$?
[ "$status" = 2 ] || fail "case 12: a file that is not JSON gave exit code $status, expected 2"
[ "$(listing "$DEST")" = "$before" ] || fail "case 12: the destination changed after a bad file"
echo "ok 12: the lectures arrive whole, a missing or broken file is refused, destination unchanged"
# Case 13: a text file written with CRLF line endings arrives with LF only (the repository stores LF, so a CRLF copy would show as modified with no change in it); a file with LF arrives byte for byte.
CRLF="$WORK/crlf"
cp -R "$SRC" "$CRLF"
printf -- '---\r\ntitle: T\r\nslug: windows\r\nstatus: publish\r\n---\r\nBody.\r\n' > "$CRLF/articles/windows.md"
printf -- '---\r\ntitle: C\r\n---\r\n' > "$CRLF/categories/windows.md"
printf -- '---\r\ntitle: W\r\n---\r\nLine one.\r\nLine two.\r\n' > "$CRLF/pages/windows.md"
run "$CRLF" "$DEST" || fail "case 13: exit code $?"
for copied in articles/windows.md categories/windows.md pages/windows.md; do
  [ -f "$DEST/$copied" ] || fail "case 13: $copied was not copied"
  if LC_ALL=C grep -q "$(printf '\r')" "$DEST/$copied"; then fail "case 13: $copied still holds a carriage return"; fi
done
[ "$(cat "$DEST/pages/windows.md")" = "$(printf -- '---\ntitle: W\n---\nLine one.\nLine two.')" ] || fail "case 13: the page's text changed: $(cat "$DEST/pages/windows.md")"
cmp -s "$CRLF/articles/published-bare.md" "$DEST/articles/published-bare.md" || fail "case 13: a file with LF endings did not arrive byte for byte"
echo "ok 13: CRLF line endings arrive as LF, an LF file arrives unchanged"
# Case 14 (LEC-R10): a phone-like run in a TEXT key (title, excerpt, content, search_phrases, key_points, tags, a chapter's title and summary) becomes [number removed]; slug, url, a chapter's url,
# language, publishedDate, durationSec and the embedding are never touched (the vector line is byte for byte); a run of 14 digits, one of 9, a year list with commas, and a run split by a letter stay as they are when no number word or mask is near.
MASK="$WORK/mask"
mkdir -p "$MASK/lectures"
cp -R "$SRC/articles" "$SRC/categories" "$SRC/pages" "$MASK/"
EMB='[0.123456789012,-0.012345678901,1.234567890123E-05]'
{
  printf '%s\n' '{"slug":"abcdefghijk","title":"Call +00 0000 000000 now","url":"https://example.invalid/0000000000000","excerpt":"Or +00 000 0000000","content":"In 1445, 1446 and 1447, 12345678901234, 123456789, 000 0000 x 000 0000. Write to (000)000-0000 or 000.000.0000.","search_phrases":["00000 000000"],"key_points":["0000000000"],"tags":["+0000000000000"],"language":"en","publishedDate":"2026-01-02T03:04:05Z","durationSec":1234567890,"chapters":[{"start_sec":3,"title":"Chapter 0000-0000-00","summary":"+00 0000 0000","url":"https://example.invalid/c?t=00000000000"}],"embedding":'"$EMB"'}'
  printf '%s\n' '{"slug":"bcdefghijkl","title":"Plain","url":"https://example.invalid/b","excerpt":"","content":"nothing","search_phrases":[],"key_points":[],"tags":[],"language":"hi","publishedDate":"2025-01-02T03:04:05Z","durationSec":0,"chapters":[]}'
} > "$MASK/lectures/lectures.ndjson"
run "$MASK" "$DEST" || fail "case 14: exit code $?"
[ "$(wc -l < "$LEC" | tr -d ' ')" = 2 ] || fail "case 14: the copied file does not have two lines"
first="$(sed -n 1p "$LEC")"
[ "$(jq -r '.title, .excerpt, .search_phrases[0], .key_points[0], .tags[0], .chapters[0].summary' <<< "$first" | sort -u)" = "Call [number removed] now
Or [number removed]
[number removed]" ] || fail "case 14: a text key was not masked: $(jq -c '[.title,.excerpt,.search_phrases,.key_points,.tags,.chapters]' <<< "$first")"
[ "$(jq -r '.chapters[0].title' <<< "$first")" = "Chapter [number removed]" ] || fail "case 14: the chapter title was not masked"
[ "$(jq -r '.content' <<< "$first")" = "In 1445, 1446 and 1447, 12345678901234, 123456789, 000 0000 x 000 0000. Write to ([number removed] or [number removed]." ] || fail "case 14: the content is not as expected: $(jq -r .content <<< "$first")"
[ "$(jq -r '.url, .chapters[0].url, .slug, .language, .publishedDate, .durationSec' <<< "$first")" = "https://example.invalid/0000000000000
https://example.invalid/c?t=00000000000
abcdefghijk
en
2026-01-02T03:04:05Z
1234567890" ] || fail "case 14: a key that must not be masked was changed"
case "$first" in *',"embedding":'"$EMB"'}') ;; *) fail "case 14: the embedding is not kept byte for byte" ;; esac
[ "$(sed -n 2p "$LEC")" = "$(sed -n 2p "$MASK/lectures/lectures.ndjson")" ] || fail "case 14: a line without a number changed"
printf '{"slug":"abcdefghijk","embedding":[0.1],"title":"T"}\n' > "$MASK/lectures/lectures.ndjson"
status=0
run "$MASK" "$DEST" || status=$?
[ "$status" = 2 ] || fail "case 14: an embedding that is not the last key gave exit code $status, expected 2"
printf '{"slug":"abcdefghijk","title":"T"}\n\n{"slug":"bcdefghijkl","title":"T"}\n' > "$MASK/lectures/lectures.ndjson"
status=0
run "$MASK" "$DEST" || status=$?
[ "$status" = 2 ] || fail "case 14: a blank line gave exit code $status, expected 2"
echo "ok 14: phone-like runs in the text keys are masked, nothing else changes, the vector is byte for byte"
# Case 15 (LEC-R10, rule 2): after whatsapp, phone, mobile or contact and then number or no (any case), a run of 4 or more digits in all that begins within 80 characters becomes [number removed], and so does each repeat of it, up to 5 in a row;
# a run of 1 to 3 digits, a figure after the words without "number", and one more than 80 characters away stay.
FILL="$(printf 'z%.0s' $(seq 1 90))"
printf '%s\n' '{"slug":"abcdefghijk","title":"T","url":"https://example.invalid/a","excerpt":"","content":"WhatsApp number is 0000 000, repeat, 0000 000 again. '"$FILL"' CONTACT NO. +00 0000 '"$FILL"' phone number 123 and a 5-minute call '"$FILL"' WhatsApp 0000 stays.","search_phrases":[],"key_points":["Mobile number 0000"],"tags":[],"language":"en","publishedDate":"2026-01-02T03:04:05Z","durationSec":78,"chapters":[{"start_sec":3,"title":"C","summary":"Phone no 00-0000","url":"https://example.invalid/c"}],"embedding":[0.1]}' > "$MASK/lectures/lectures.ndjson"
run "$MASK" "$DEST" || fail "case 15: exit code $?"
line="$(sed -n 1p "$LEC")"
[ "$(jq -r '.content' <<< "$line")" = "WhatsApp number is [number removed], repeat, [number removed] again. $FILL CONTACT NO. [number removed] $FILL phone number 123 and a 5-minute call $FILL WhatsApp 0000 stays." ] || fail "case 15: the content is not as expected: $(jq -r .content <<< "$line" | cut -c1-120)"
[ "$(jq -r '.key_points[0], .chapters[0].summary' <<< "$line")" = "Mobile number [number removed]
Phone no [number removed]" ] || fail "case 15: a key point or a chapter summary was not masked"
case "$line" in *',"embedding":[0.1]}') ;; *) fail "case 15: the embedding changed" ;; esac
echo "ok 15: a figure of 4 or more digits after a number word is masked, repeats too, short figures and distant ones stay"
# Case 16 (LEC-R10, rule 2 chained): the window also opens after a [number removed], so a spoken number said in groups is masked whole; more groups than the passes allow (10) refuse.
CHAIN='WhatsApp number 1111, 2222, 3333, 4444, 5555, 6666'
printf '%s\n' '{"slug":"abcdefghijk","title":"T","url":"u","excerpt":"","content":"'"$CHAIN"'","search_phrases":[],"key_points":[],"tags":[],"language":"en","publishedDate":"2026-01-02T03:04:05Z","durationSec":78,"chapters":[],"embedding":[0.1]}' > "$MASK/lectures/lectures.ndjson"
run "$MASK" "$DEST" || fail "case 16: exit code $?"
[ "$(jq -r '.content' "$LEC")" = "WhatsApp number [number removed], [number removed], [number removed], [number removed], [number removed], [number removed]" ] || fail "case 16: the groups were not all masked: $(jq -r .content "$LEC")"
printf '%s\n' '{"slug":"abcdefghijk","title":"T","url":"u","excerpt":"","content":"WhatsApp number 1111, 1111, 1111, 1111, 1111, 1111, 1111, 1111, 1111, 1111, 1111, 1111","search_phrases":[],"key_points":[],"tags":[],"language":"en","publishedDate":"2026-01-02T03:04:05Z","durationSec":78,"chapters":[],"embedding":[0.1]}' > "$MASK/lectures/lectures.ndjson"
before="$(listing "$DEST")"
status=0
run "$MASK" "$DEST" || status=$?
[ "$status" = 2 ] || fail "case 16: a number that needs more than 10 passes gave exit code $status, expected 2"
[ "$(listing "$DEST")" = "$before" ] || fail "case 16: the destination changed after the refusal"
echo "ok 16: the groups of a spoken number are masked whole, and a number the passes cannot finish refuses"
# Case 17: every source line must be one complete JSON object, or the masked text could be paired with the wrong vector: an object over two lines, and two objects on one line, refuse.
printf '%s\n' '{"slug":"abcdefghijk","title":"T",' '"embedding":[0.1]}' > "$MASK/lectures/lectures.ndjson"
status=0
run "$MASK" "$DEST" || status=$?
[ "$status" = 2 ] || fail "case 17: an object over two lines gave exit code $status, expected 2"
printf '%s\n' '{"slug":"abcdefghijk","title":"T"}{"slug":"bcdefghijkl","title":"U"}' > "$MASK/lectures/lectures.ndjson"
status=0
run "$MASK" "$DEST" || status=$?
[ "$status" = 2 ] || fail "case 17: two objects on a line gave exit code $status, expected 2"
grep -q "not one complete JSON object" "$OUT" || fail "case 17: the output does not say why: $(cat "$OUT")"
echo "ok 17: a line that is not one complete JSON object refuses"
echo "content import proven: 17 cases"
