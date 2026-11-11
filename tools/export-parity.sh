#!/usr/bin/env bash
# Compare a report's xlsx download from PHP and from the new API: the same sheet names and every cell's kind and text (tools/export_parity.py, standard library only).
# Usage: tools/export-parity.sh [<alias> "<path>?format=xlsx&..." [--unordered] [--filter COL:PREFIX] [--ignore COLS]]   (no arguments: every case in tools/export-parity.cases)
# Both sides must be up with their fixtures loaded and tokens written: tools/classes-contract.sh parity --prepare and ... test --prepare (build/parity-php/classes.vars, build/test/classes.vars),
# the same for membership. The alias is a Hurl variable name without the auth_ prefix; it is looked up in the .vars files of each side. Synthetic stacks only:
# PHP on 127.0.0.1:18091, the new API on the TEST stack localhost:8089. Downloads go to build/export-parity/ (kept for inspection).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
OUT="build/export-parity"
mkdir -p "$OUT"

token() { # side-folder alias
  local value
  value="$(cat "$1"/*.vars 2>/dev/null | sed -n "s/^auth_$2=//p" | head -n 1)"
  [ -n "$value" ] || { echo "no token for $2 in $1" >&2; exit 2; }
  printf '%s' "$value"
}

compare() { # alias path [--unordered]
  local alias="$1" path="$2" flag="${3:-}" slug
  slug="$(printf '%s_%s' "$alias" "$path" | tr -c 'A-Za-z0-9\n' '_')"
  rm -f "$OUT/$slug.php.xlsx" "$OUT/$slug.new.xlsx"
  curl -fsS --max-time 60 -H "Authorization: $(token build/parity-php "$alias")" -o "$OUT/$slug.php.xlsx" "http://127.0.0.1:18091$path" || { echo "$alias $path: PHP did not answer 200"; return 1; }
  curl -fsS --max-time 60 -H "Authorization: $(token build/test "$alias")" -o "$OUT/$slug.new.xlsx" "http://localhost:8089$path" || { echo "$alias $path: the new API did not answer 200"; return 1; }
  printf '%s %s: ' "$alias" "$path"
  uv run python -I tools/export_parity.py "$OUT/$slug.php.xlsx" "$OUT/$slug.new.xlsx" $flag
}

status=0
if [ "$#" -ge 2 ]; then
  compare "$1" "$2" "${*:3}" || status=1
else
  while read -r alias path flag; do
    case "$alias" in ''|'#'*) continue ;; esac
    compare "$alias" "$path" "${flag:-}" || status=1
  done < tools/export-parity.cases
fi
exit "$status"
