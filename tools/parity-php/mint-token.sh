#!/usr/bin/env bash
# Mint a token for one SYNTHETIC member from the parity stack's Auth emulator and
# write it to a Hurl variables file. Usage: ./mint-token.sh <member email> [out file]
# The email must end .invalid. The token is never printed. Needs curl and jq.
# Emulator accounts live in memory: run this again after the emulator restarts.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EMAIL="${1:?usage: mint-token.sh <member email ending .invalid> [out file]}"
OUT="${2:-$DIR/../../build/parity-php/token.vars}"
case "$EMAIL" in *.invalid) ;; *) echo "refusing: $EMAIL is not a .invalid address" >&2; exit 1 ;; esac

# shellcheck disable=SC1091
. "$DIR/parity.env"
HOST="http://127.0.0.1:${PARITY_EMULATOR_PORT}/identitytoolkit.googleapis.com/v1"
BODY="$(jq -n --arg e "$EMAIL" --arg p "$PARITY_EMULATOR_PASSWORD" \
  '{email:$e,password:$p,emailVerified:true,returnSecureToken:true}')"

# Create the account, verified (the PHP side only matches a member by a verified email).
# An existing account answers 400 EMAIL_EXISTS, which is fine.
printf '%s' "$BODY" | curl -sS --max-time 10 -o /dev/null -X POST \
  "$HOST/projects/${PARITY_FIREBASE_PROJECT_ID}/accounts" \
  -H 'Authorization: Bearer owner' -H 'Content-Type: application/json' --data-binary @-

TOKEN="$(printf '%s' "$BODY" | curl -sS --max-time 10 -X POST \
  "$HOST/accounts:signInWithPassword?key=local" \
  -H 'Content-Type: application/json' --data-binary @- | jq -r '.idToken // empty')"
[ -n "$TOKEN" ] || { echo "sign-in failed: is the emulator up on port ${PARITY_EMULATOR_PORT}?" >&2; exit 1; }

mkdir -p "$(dirname "$OUT")"
umask 077
printf 'auth_header=Authorization\nauth_value=Bearer %s\n' "$TOKEN" > "$OUT"
echo "token written to $OUT"
