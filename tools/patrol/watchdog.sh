# Time-limited, fully-cleaned-up run of one command (a `patrol test`), used by
# tools/patrol/run.sh (copied from tsr-account scripts/lib/patrol-watchdog.sh). Source it; it sets
# no shell options of its own.
#
# Why this is more than `sleep N; kill $pid` (#912, #943). When patrol_cli is
# killed, its children -- Gradle and its daemon, adb, logcat -- are re-parented
# to pid 1, and a walk down from the patrol pid at kill time no longer finds
# them. They were found alive 33 minutes after a timeout. So the run is
# identified three ways, and the kill takes the union:
#
#   1. a tracker records every descendant of the command, with its start time,
#      every two seconds while it runs (catches a process before it is
#      re-parented; the start time guards against pid reuse);
#   2. a descendant walk at kill time;
#   3. an environment marker: the command is started with TSR_PATROL_RUN set to
#      a unique value, children inherit it, and `ps eww` shows it even after
#      re-parenting. Only this run's processes carry it, so a Gradle daemon of
#      another project, or one that predates the run, is left alone. (SIP
#      binaries such as /bin/sleep hide their environment; they are harmless.)
#
# Uses only pgrep, ps, kill and mktemp, all present on macOS. No setsid, no
# `timeout`, no GNU flags, and never `gradlew --stop` or kill-by-name.

# Direct and indirect children of $1.
patrol_descendants() {
  local child
  for child in $(pgrep -P "$1" 2>/dev/null || true); do
    echo "$child"
    patrol_descendants "$child"
  done
}

# Echo "pid|start time" for $1 and its descendants, for the pid-reuse guard.
patrol_snapshot() {
  local pid
  for pid in "$1" $(patrol_descendants "$1"); do
    printf '%s|%s\n' "$pid" "$(ps -o lstart= -p "$pid" 2>/dev/null | tr -s ' ')"
  done
}

# Every live process carrying run marker $1 in its environment.
patrol_marked_pids() {
  ps eww -axo pid=,command= 2>/dev/null \
    | grep -F "TSR_PATROL_RUN=$1" \
    | awk '{print $1}' \
    | grep -vx -e "$$" -e "${BASHPID:-$$}" || true
}

# kill_run_cohort <root pid> <tracker file> <run marker>
# TERM, a short grace, then KILL, for everything this run started.
patrol_kill_cohort() {
  local root="$1" file="$2" marker="$3" pid started now pids=""
  while IFS='|' read -r pid started; do
    [ -n "$pid" ] || continue
    now="$(ps -o lstart= -p "$pid" 2>/dev/null | tr -s ' ')"
    [ -n "$now" ] && [ "$now" = "$started" ] && pids="$pids $pid"
  done <"$file"
  pids="$pids $(patrol_snapshot "$root" | cut -d'|' -f1 | tr '\n' ' ') $(patrol_marked_pids "$marker" | tr '\n' ' ')"
  pids="$(printf '%s\n' $pids | sort -un | grep -vx -e "$$" -e "${BASHPID:-$$}" | tr '\n' ' ')"
  [ -n "${pids// /}" ] || return 0
  # shellcheck disable=SC2086
  kill -TERM $pids 2>/dev/null || true
  sleep 10
  # Anything the grace period let spawn something new is caught by the marker.
  pids="$pids $(patrol_marked_pids "$marker" | tr '\n' ' ')"
  # shellcheck disable=SC2086
  kill -KILL $pids 2>/dev/null || true
  # A dying Gradle client can still spawn a daemon; sweep until none is left.
  local pass
  for pass in 1 2 3; do
    sleep 2
    pids="$(patrol_marked_pids "$marker" | tr '\n' ' ')"
    [ -n "${pids// /}" ] || return 0
    # shellcheck disable=SC2086
    kill -KILL $pids 2>/dev/null || true
  done
}

# patrol_run_limited <seconds> <command...>
# Runs the command. If it is still running after <seconds>, kills everything the
# run started (see above) and returns 124 (or its own non-zero status). Returns
# the command's status otherwise. The cohort is left alone on a normal finish.
patrol_run_limited() {
  local limit="$1"
  shift
  local marker
  marker="$(date +%s)-$$-$RANDOM"
  local tracker fired
  tracker="$(mktemp)"
  fired="$(mktemp)"
  rm -f "$fired"

  TSR_PATROL_RUN="$marker" "$@" &
  local pid=$!

  # Streams are closed off: a background subshell that inherits stdout keeps a
  # caller's `| tee` pipe open for its whole sleep.
  (
    while kill -0 "$pid" 2>/dev/null; do
      patrol_snapshot "$pid" >>"$tracker"
      sleep 2
    done
  ) >/dev/null 2>&1 &
  local tracker_pid=$!

  (
    sleep "$limit"
    touch "$fired"
    patrol_kill_cohort "$pid" "$tracker" "$marker"
  ) >/dev/null 2>&1 &
  local watchdog_pid=$!

  local status=0
  wait "$pid" || status=$?
  if [ -e "$fired" ]; then
    # Timed out: let the watchdog finish its TERM, grace, KILL sequence.
    wait "$watchdog_pid" 2>/dev/null || true
    [ "$status" -ne 0 ] || status=124
    echo "patrol was killed: timeout ${limit}s reached; its process tree was cleaned up." >&2
  else
    kill $(patrol_descendants "$watchdog_pid") "$watchdog_pid" 2>/dev/null || true
    wait "$watchdog_pid" 2>/dev/null || true
  fi
  kill "$tracker_pid" 2>/dev/null || true
  wait "$tracker_pid" 2>/dev/null || true
  rm -f "$fired" "$tracker"
  return "$status"
}
