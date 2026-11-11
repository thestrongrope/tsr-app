#!/usr/bin/env bash
# Run membership's Hurl contract files (domains/membership/spec/tests/*.hurl) against one side.
# Usage: tools/membership-contract.sh dev|test|parity [--prepare] [extra hurl args]
#   dev     the new API on the dev stack (http://localhost:8088; docker-compose.dev.yml must be up)
#   test    the new API on the synthetic TEST stack (http://localhost:8089; tools/test-stack.sh up); never run dev against real data
#   parity  the PHP API on the parity stack (http://127.0.0.1:18091, tools/parity-php/README.md; synthetic data only)
#   --prepare  do the preparation below and stop (for the all-files command in CLAUDE.md, Commands)
# Preparation, so both sides answer from the same data and a file can be run again:
#   - RESETS the membership fixtures (members, guardian links, registrations) on that side: db/synthetic/membership-fixtures.sql for the
#     new API, tools/parity-php/membership-fixtures.sh for PHP (which also refuses a fixture that touches a class). The files change
#     rows (accept an invite, revoke a link, save a profile), so run this script, or --prepare, before each run;
#   - loads the B4b fixtures (db/synthetic/membership-b4b-fixtures.sql, tools/parity-php/membership-b4b-fixtures.sql: tokens 9011xx, classes 9561 to 9563, they touch classes);
#   - loads the geo rows (db/synthetic/geo-fixtures.sql) that PATCH /me checks a country and postal code against;
#   - signs each fixture member in at that side's Auth emulator and writes build/<side>/membership.vars (auth_<alias>=Bearer ...).
# Only the tsr-app-dev, tsr-app-test and tsr-parity compose projects are touched. Needs docker, curl, jq, hurl. Prints no secret.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIDE="${1:?usage: membership-contract.sh dev|test|parity [--prepare] [hurl args]}"
shift || true
cd "$ROOT"

PREPARE_ONLY=0
if [ "${1:-}" = "--prepare" ]; then
  PREPARE_ONLY=1
  shift
fi

FILES=(domains/membership/spec/tests/*.hurl)

# alias=email: the fixture members the files sign in as (the aliases are the Hurl variable names, auth_<alias>).
MEMBERS=(
  "registrant_dup=registrant.duplicates@example.invalid"
  "registrant_one=registrant.single@example.invalid"
  "registrant_update=registrant.update@example.invalid"
  "fresh=gender.empty@example.invalid"
  "parent_one=parent.one@example.invalid"
  "child_active=child.active@example.invalid"
  "child_invited=child.invited@example.invalid"
  "accept_parent=accept.parent@example.invalid"
  "accept_child=accept.child@example.invalid"
  "shared_one=shared.token.one@example.invalid"
  "revoke_parent=revoke.parent@example.invalid"
  "prevoke_child=prevoke.child@example.invalid"
  "gender_one=gender.one@example.invalid"
  "gender_two=gender.two@example.invalid"
  "gender_male=gender.male@example.invalid"
  "gender_female=gender.female@example.invalid"
  "gender_empty=gender.empty@example.invalid"
  "gender_null=gender.null@example.invalid"
  "profile_entity=profile.entity@example.invalid"
  "profile_noname=profile.noname@example.invalid"
  "profile_patch=profile.patch@example.invalid"
  "b4b_invite_admin=b4b.901101@example.invalid"
  "b4b_candidate_admin=b4b.901102@example.invalid"
  "b4b_direct_admin=b4b.901103@example.invalid"
  "b4b_cancel_admin=b4b.901104@example.invalid"
  "b4b_cancel_manager=b4b.901105@example.invalid"
  "b4b_donor_admin=b4b.901106@example.invalid"
  "b4b_card_admin=b4b.901107@example.invalid"
  "b4b_reject_admin=b4b.901108@example.invalid"
  "b4b_gents_admin=b4b.901109@example.invalid"
  "b4b_plain=b4b.901110@example.invalid"
  "b4b_self_child=b4b.901114@example.invalid"
  "b4b_cancel_child=b4b.901115@example.invalid"
  "b4b_parent_kids=b4b.901121@example.invalid"
  "b4b_parent_none=b4b.901122@example.invalid"
  "b5b_admin=b5b.901801@example.invalid"
  "b5b_gents_admin=b5b.901802@example.invalid"
  "b5b_ladies_admin=b5b.901803@example.invalid"
  "b5b_plain=b5b.901804@example.invalid"
)

parity() { docker compose -p tsr-parity -f tools/parity-php/compose.parity.yml --env-file tools/parity-php/parity.env "$@"; }
php_sql() { parity exec -T db sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" tsr_synth'; }
dev_sql() { docker compose -p "${PROJECT:-tsr-app-dev}" -f docker-compose.dev.yml exec -T db psql -v ON_ERROR_STOP=1 -q -U tsr -d tsr; }

case "$SIDE" in
  dev|test)
    if [ "$SIDE" = test ]; then PROJECT=tsr-app-test; PORT=8089; export TSR_EMULATOR_PORT=19100; else PROJECT=tsr-app-dev; PORT=8088; export TSR_EMULATOR_PORT=19099; fi
    "$ROOT/tools/require-synthetic-stack.sh" "$PROJECT"
    # TSR_FIXTURES_LOADED=1: the members are already in the database (a database filled by tools/data-load from the
    # parity source, which holds the same fixtures); do not add db/synthetic/membership-fixtures.sql on top.
    [ -n "${TSR_FIXTURES_LOADED:-}" ] || { dev_sql < db/synthetic/membership-fixtures.sql; dev_sql < db/synthetic/membership-b4b-fixtures.sql; dev_sql < db/synthetic/membership-b5b-fixtures.sql; }

    { echo "set search_path = platform, public;"; cat db/synthetic/geo-fixtures.sql; } | dev_sql
    MINT="tools/dev-auth/mint-token.sh"
    BASE="http://localhost:$PORT" ;;
  parity)
    tools/parity-php/membership-fixtures.sh
    php_sql < tools/parity-php/membership-b4b-fixtures.sql
    php_sql < tools/parity-php/membership-b5b-fixtures.sql
    php_sql < db/synthetic/geo-fixtures.sql
    MINT="tools/parity-php/mint-token.sh"
    BASE="http://127.0.0.1:18091"
    # Files named *-new-api.hurl hold cases only the new API answers (a NUL byte in a text: PHP stores it, here it is 422); they run on the new API only.
    KEPT=()
    for f in "${FILES[@]}"; do case "$f" in *-new-api.hurl) ;; *) KEPT+=("$f") ;; esac; done
    FILES=("${KEPT[@]}") ;;
  *) echo "side must be dev, test or parity" >&2; exit 1 ;;
esac

VARS="build/$([ "$SIDE" = parity ] && echo parity-php || echo "$SIDE")/membership.vars"
mkdir -p "$(dirname "$VARS")"
umask 077
: > "$VARS"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
for entry in "${MEMBERS[@]}"; do
  alias="${entry%%=*}"
  email="${entry#*=}"
  "$MINT" "$email" "$TMP" > /dev/null
  printf 'auth_%s=%s\n' "$alias" "$(sed -n 's/^auth_value=//p' "$TMP")" >> "$VARS"
done
echo "membership fixtures reset on $SIDE; tokens in $VARS"

if [ "$PREPARE_ONLY" = 1 ]; then
  exit 0
fi

hurl --test --variable "base_url=$BASE" --variables-file "$VARS" "$@" "${FILES[@]}"
