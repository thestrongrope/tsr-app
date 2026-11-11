#!/usr/bin/env bash
# Refuses (exit 1) unless the target in TSR_DST_CLIENT is a synthetic database. There is NO default target: a script that
# empties or fills a database must be told which one, and must never be able to fall back on the dev database.
# Synthetic means: no identity.users row whose email is empty or does not end in .invalid. Prints a count, never a value.
set -euo pipefail
[ -n "${TSR_DST_CLIENT:-}" ] || { echo "require-synthetic: set TSR_DST_CLIENT (the psql client command of a throwaway, synthetic target); there is no default" >&2; exit 1; }
IFS=' ' read -r -a DST <<< "$TSR_DST_CLIENT"
n="$(echo "select count(*) from identity.users where email is null or email not ilike '%.invalid'" \
     | PGCONNECT_TIMEOUT=20 "${DST[@]}" -X -q -At -v ON_ERROR_STOP=1 -f -)" \
  || { echo "require-synthetic: cannot count identity.users on the target (is it reachable and migrated?); refusing" >&2; exit 1; }
[[ "$n" =~ ^[0-9]+$ ]] || { echo "require-synthetic: unexpected answer from the target; refusing" >&2; exit 1; }
if [ "$n" != "0" ]; then
  echo "require-synthetic: the target holds $n user row(s) whose email does not end in .invalid; it is not synthetic. Refusing." >&2
  exit 1
fi
