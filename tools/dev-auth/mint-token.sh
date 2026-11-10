#!/usr/bin/env bash
# Sign one SYNTHETIC member in at the dev stack's Firebase Auth emulator and write a Hurl variables file.
# Usage: ./mint-token.sh [member email, default member.gents@example.invalid] [out file, default build/dev/token.vars]
# The email must end .invalid. The token is never printed. Needs curl and jq.
# Emulator accounts live in memory: run this again after the emulator restarts.
# The file holds auth_header, auth_value (Bearer <token>), and emulator_url, project_id, emulator_password,
# which domains/identity/spec/tests/link-account.hurl uses to sign in by itself.
# Same shape as tools/parity-php/mint-token.sh, so one Hurl command shape works on both sides.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EMAIL="${1:-member.gents@example.invalid}"
OUT="${2:-$DIR/../../build/dev/token.vars}"
case "$EMAIL" in *.invalid) ;; *) echo "refusing: $EMAIL is not a .invalid address" >&2; exit 1 ;; esac

# Local-only placeholders; they guard an in-memory emulator on 127.0.0.1 (docker-compose.dev.yml).
PROJECT="demo-tsr-app"
PASSWORD="dev-member-local-only"
PORT="19099"
HOST="http://127.0.0.1:${PORT}/identitytoolkit.googleapis.com/v1"
BODY="$(jq -n --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p,emailVerified:true,returnSecureToken:true}')"

# Create the account, verified. An existing account answers 400 EMAIL_EXISTS, which is fine.
printf '%s' "$BODY" | curl -sS --max-time 10 -o /dev/null -X POST \
  "$HOST/projects/${PROJECT}/accounts" \
  -H 'Authorization: Bearer owner' -H 'Content-Type: application/json' --data-binary @-

TOKEN="$(printf '%s' "$BODY" | curl -sS --max-time 10 -X POST \
  "$HOST/accounts:signInWithPassword?key=local" \
  -H 'Content-Type: application/json' --data-binary @- | jq -r '.idToken // empty')"
[ -n "$TOKEN" ] || { echo "sign-in failed: is the emulator up on port ${PORT}?" >&2; exit 1; }

mkdir -p "$(dirname "$OUT")"
umask 077
{
  printf 'auth_header=Authorization\nauth_value=Bearer %s\n' "$TOKEN"
  printf 'emulator_url=%s\nproject_id=%s\nemulator_password=%s\n' "$HOST" "$PROJECT" "$PASSWORD"
} > "$OUT"
echo "token written to $OUT"
