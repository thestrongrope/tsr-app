#!/usr/bin/env bash
# Runs the Patrol journeys of hosts/app on an Android emulator against a lane stack. Called by tools/patrol-lane.sh
# (run, run-personas), which sets the environment below; not meant to be called by hand.
# Usage: tools/patrol/run.sh journeys|personas [journey files, relative to hosts/app]
#   journeys  the reviewer and guest journeys (hosts/app/integration_test/journeys), signed in as the reviewer
#   personas  the persona journeys (hosts/app/integration_test/personas); before each one a probe asks the API for the
#             persona's classes and the journey is skipped as failed when they are not the fixture's
# Environment (all required):
#   TSR_PATROL_API_URL             http://127.0.0.1:<port>, the lane's gateway; the device reaches it through adb reverse
#   TSR_PATROL_AUTH_EMULATOR_PORT  host port of the lane's Auth emulator (the app is told 127.0.0.1:9099)
#   TSR_PATROL_RESET_CMD           resets the lane's data; run before every journey
#   TSR_REVIEWER_PASSWORD          journeys: the reviewer's emulator password
#   TSR_PERSONA_PASSWORD           personas: the personas' emulator password
#   TSR_PATROL_ENROL_TOKEN_CMD     personas: prints the token of the registrant persona-reg.gentsplace@demo.invalid
#   TSR_PATROL_LINK_TOKEN_CMD      personas: prints the token of persona-link.member@demo.invalid, or nothing when the
#                                  fixture has no such member (the link-student journey then fails with its own message)
# Optional: TSR_AVD_NAME (default tsr_test), TSR_PATROL_TIMEOUT (seconds a journey may take, default 1800).
# Adapted from tsr-account's scripts/patrol-android.sh and scripts/patrol-personas.sh (the lane case only).
# Needs adb, jq, curl and patrol_cli. Prints no password and no row value.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
APP_DIR="$ROOT/hosts/app"
MODE="${1:?usage: tools/patrol/run.sh journeys|personas [journey files]}"
shift
case "$MODE" in journeys|personas) ;; *) echo "patrol-run: the mode is journeys or personas" >&2; exit 1 ;; esac

AVD_NAME="${TSR_AVD_NAME:-tsr_test}"
TIMEOUT_SECS="${TSR_PATROL_TIMEOUT:-1800}"
API="${TSR_PATROL_API_URL:?TSR_PATROL_API_URL not set}"
if [[ ! "$API" =~ ^http://127\.0\.0\.1:([0-9]+)$ ]]; then
  echo "patrol-run: TSR_PATROL_API_URL must be http://127.0.0.1:<port>" >&2
  exit 1
fi
API_PORT="${BASH_REMATCH[1]}"
AUTH_EMULATOR_PORT="${TSR_PATROL_AUTH_EMULATOR_PORT:?TSR_PATROL_AUTH_EMULATOR_PORT not set}"
[[ "$AUTH_EMULATOR_PORT" =~ ^[0-9]+$ ]] || { echo "patrol-run: TSR_PATROL_AUTH_EMULATOR_PORT must be a port number" >&2; exit 1; }
RESET_CMD="${TSR_PATROL_RESET_CMD:?TSR_PATROL_RESET_CMD not set}"
if [ "$MODE" = personas ]; then
  : "${TSR_PERSONA_PASSWORD:?TSR_PERSONA_PASSWORD not set}"
  : "${TSR_PATROL_ENROL_TOKEN_CMD:?TSR_PATROL_ENROL_TOKEN_CMD not set}"
  : "${TSR_PATROL_LINK_TOKEN_CMD:?TSR_PATROL_LINK_TOKEN_CMD not set}"
  command -v jq > /dev/null || { echo "patrol-run: jq not found (the probe needs it)" >&2; exit 1; }
else
  : "${TSR_REVIEWER_PASSWORD:?TSR_REVIEWER_PASSWORD not set}"
fi

# Fail on the real cause, not on a network error inside a journey twenty minutes later.
curl -s --max-time 4 "$API" > /dev/null 2>&1 || { echo "patrol-run: the API does not answer on $API; is the lane up?" >&2; exit 1; }

# patrol_cli first runs `flutter build apk --config-only`, which copies each plugin into build/<platform>/SourcePackages for
# ios and macos too, and fails on a checkout where neither was ever built because the folders do not exist.
mkdir -p "$APP_DIR/build/ios/SourcePackages" "$APP_DIR/build/macos/SourcePackages"

# patrol_cli installs to ~/.pub-cache/bin, which is not on PATH by default.
PATROL="$(command -v patrol || echo "$HOME/.pub-cache/bin/patrol")"
[ -x "$PATROL" ] || { echo "patrol-run: patrol_cli not found; run: flutter pub global activate patrol_cli" >&2; exit 1; }

# patrol_cli 4.8.0 and later need the patrol package 4.10.0 or later. A mismatch builds and signs in, then hangs on the
# first native step ("Successful: 0, Failed: 0").
PATROL_VERSION="$("$PATROL" --version 2> /dev/null | grep -oE 'patrol_cli v[0-9]+\.[0-9]+\.[0-9]+' | head -1 | cut -dv -f2)"
PATROL_PKG_VERSION="$(awk '/^  patrol:$/{f=1} f&&/^    version:/{gsub(/[" ]/,"",$2); print $2; exit}' "$ROOT/pubspec.lock")"
version_ge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" = "$2" ]; }
if [ -n "$PATROL_VERSION" ] && [ -n "$PATROL_PKG_VERSION" ]; then
  if version_ge "$PATROL_VERSION" 4.8.0 && ! version_ge "$PATROL_PKG_VERSION" 4.10.0; then
    echo "patrol-run: patrol_cli $PATROL_VERSION needs the patrol package 4.10.0 or later, but pubspec.lock has $PATROL_PKG_VERSION" >&2
    exit 1
  fi
fi

# One emulator, one suite at a time.
# shellcheck source=tools/patrol/emulator-lock.sh
. "$ROOT/tools/patrol/emulator-lock.sh"
# shellcheck source=tools/patrol/watchdog.sh
. "$ROOT/tools/patrol/watchdog.sh"
patrol_emulator_lock "$AVD_NAME"
trap patrol_emulator_unlock EXIT
# Bash skips the EXIT trap when a signal kills it; an ordinary exit makes Ctrl-C clean up too.
trap 'exit 130' INT
trap 'exit 143' TERM

if [ -z "$(adb devices | sed '1d' | grep -w device || true)" ]; then
  echo "no device attached; booting $AVD_NAME"
  "${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}/emulator/emulator" -avd "$AVD_NAME" -no-snapshot-save > /dev/null 2>&1 &
fi
adb wait-for-device
# The device answers adb before Android has finished booting; an install then fails now and again.
BOOT_WAITED=0
until [ "$(adb shell getprop sys.boot_completed 2> /dev/null | tr -d '\r')" = "1" ]; do
  [ "$BOOT_WAITED" -lt 600 ] || { echo "patrol-run: the emulator did not finish booting in 10 minutes" >&2; exit 1; }
  sleep 2; BOOT_WAITED=$((BOOT_WAITED + 2))
done
adb reverse "tcp:$API_PORT" "tcp:$API_PORT"
adb reverse tcp:9099 "tcp:$AUTH_EMULATOR_PORT"

# Without a named device patrol_cli asks which one, and with no terminal it asks for ever.
DEVICE="$(adb devices | sed '1d' | grep -w device | head -1 | cut -f1)"
[ -n "$DEVICE" ] || { echo "patrol-run: no adb device after boot" >&2; exit 1; }
echo "running on $DEVICE"

# One patrol call per journey: several --target in one call build one bundle that runs the other journeys' bodies too and
# takes Gradle down after the first (seen on patrol 4.9.0).
if [ $# -gt 0 ]; then
  TARGETS="$*"
else
  TARGETS="$(cd "$APP_DIR" && ls "integration_test/$MODE"/*_test.dart)"
fi

# Which persona a journey file signs in as, and the demo classes the API must answer for it. `total` is the number of
# classes of any kind, checked only where the persona must see nothing else.
persona_for() {
  case "$(basename "$1")" in
    persona_member_*)      echo "member AYD1 total=1" ;;
    persona_coordinator_*) echo "coord AYD1 total=1" ;;
    persona_gents_admin_*) echo "gentsadmin AYD1,AYD2" ;;
    persona_ladies_admin_*) echo "ladiesadmin AYP1" ;;
    persona_super_admin_*) echo "superadmin AYD1,AYD2,AYP1" ;;
    persona_finance_*)     echo "finance - total=0" ;;
    *) echo "patrol-run: unknown persona journey: $1" >&2; return 1 ;;
  esac
}

# An ID token for one persona from the Auth emulator. The body goes in on stdin, so the password is in no argument list.
emulator_token() {
  local token
  token="$(jq -n --arg e "persona.$1@demo.invalid" --arg p "$TSR_PERSONA_PASSWORD" '{email:$e,password:$p,returnSecureToken:true}' \
    | curl -s --max-time 10 -X POST \
        "http://127.0.0.1:$AUTH_EMULATOR_PORT/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=local" \
        -H 'Content-Type: application/json' --data-binary @- \
    | jq -r '.idToken // empty')"
  [ -n "$token" ] || { echo "patrol-run: emulator sign-in failed for persona $1" >&2; return 1; }
  printf '%s' "$token"
}

# Prints counts and class codes only.
probe() {
  local persona expected total token body got n
  read -r persona expected total <<< "$(persona_for "$1")"
  token="$(emulator_token "$persona")"
  body="$(curl -s --max-time 30 -H "Authorization: Bearer $token" "$API/classes?include=managed")"
  got="$(printf '%s' "$body" | jq -r '[.. | objects | .code? // empty | select(type == "string")] | .[]' 2> /dev/null \
    | grep -E '^AY[DP][0-9]+$' | sort | paste -sd, - || true)"
  [ -n "$got" ] || got="-"
  n="$(printf '%s' "$body" | jq 'if type == "array" then length elif .classes then (.classes | length) elif .data then (.data | length) else -1 end' 2> /dev/null || echo -1)"
  echo "probe $persona: classes=$n demo=[$got] expected demo=[$expected]"
  [ "$got" = "$expected" ] || { echo "PROBE FAILED for $persona: wrong demo classes" >&2; return 1; }
  case "$total" in
    total=*) [ "$n" = "${total#total=}" ] || { echo "PROBE FAILED for $persona: expected ${total#total=} classes in all, got $n" >&2; return 1; } ;;
  esac
}

# A debug build is signed with the debug key, which assetlinks.json does not list, so Android does not verify the TSR
# hosts for it and a tapped link opens the browser. Approving the domains is what a member does under "Open by default";
# patrol reinstalls the app on every run, which wipes the approval, so it is applied again until the journey ends.
approve_links_until_killed() {
  while true; do
    adb shell pm set-app-links --package com.thestrongrope 2 all > /dev/null 2>&1 || true
    sleep 1
  done
}

run_one() {
  local status=0 approver
  local defines=(--dart-define "TSR_API_BASE_URL=$API" --dart-define "TSR_AUTH_EMULATOR_HOST=127.0.0.1:9099")
  if [ "$MODE" = personas ]; then
    defines+=(--dart-define "TSR_PERSONA_PASSWORD=$TSR_PERSONA_PASSWORD" --dart-define "TSR_PERSONA_ENROL_TOKEN=$ENROL_TOKEN" \
      --dart-define "TSR_PERSONA_LINK_MEMBER_TOKEN=$LINK_MEMBER_TOKEN")
  else
    defines+=(--dart-define "TSR_REVIEWER_PASSWORD=$TSR_REVIEWER_PASSWORD")
  fi
  approve_links_until_killed &
  approver=$!
  ( cd "$APP_DIR" && patrol_run_limited "$TIMEOUT_SECS" "$PATROL" test --device "$DEVICE" --target "$1" "${defines[@]}" ) || status=$?
  kill "$approver" 2> /dev/null || true
  if [ "$status" -ge 124 ]; then
    echo "Last test events: adb logcat -d -s flutter:V | grep PATROL_LOG | tail" >&2
  fi
  return "$status"
}

STATUS=0
FAILED=""
ENROL_TOKEN=""
LINK_MEMBER_TOKEN=""
for target in $TARGETS; do
  echo
  echo "=== $target"
  # Per journey, not per run: a journey that writes must not hand its state to the next one.
  ( cd "$ROOT" && $RESET_CMD )
  # Anything the previous journey left holding Patrol's ports 8081 and 8082 makes the next one report "Total: 0".
  adb shell am force-stop com.thestrongrope 2> /dev/null || true
  adb shell am force-stop com.thestrongrope.test 2> /dev/null || true

  if [ "$MODE" = personas ]; then
    # Tokens sit above the current maximum, so the enrol-by-token journey is told the registrant's.
    ENROL_TOKEN="$($TSR_PATROL_ENROL_TOKEN_CMD | tail -n 1)"
    case "$ENROL_TOKEN" in
      ""|*[!0-9]*) echo "patrol-run: could not read the enrol-by-token fixture token" >&2; exit 1 ;;
    esac
    LINK_MEMBER_TOKEN="$($TSR_PATROL_LINK_TOKEN_CMD | tail -n 1)"
    case "$LINK_MEMBER_TOKEN" in
      *[!0-9]*) echo "patrol-run: the link-member fixture token is not a number" >&2; exit 1 ;;
    esac
    if ! probe "$target"; then
      STATUS=1; FAILED="$FAILED $target(probe)"
      continue
    fi
  fi

  run_one "$target" || { STATUS=1; FAILED="$FAILED $target"; }
done

echo
if [ -n "$FAILED" ]; then
  echo "FAILED:$FAILED" >&2
else
  echo "all $MODE passed"
fi
exit "$STATUS"
