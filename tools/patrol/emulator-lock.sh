#!/usr/bin/env bash
# Sourced by tools/patrol/run.sh (copied from tsr-account scripts/patrol-emulator-lock.sh; the lock is shared with its runners). One Android emulator runs one Patrol suite at a time: two
# runners on it reinstall and restart the same app under each other, and journeys then fail at random (a journey
# that "executed 0 tests", a widget that vanishes, a skipped first request).
#
# patrol_emulator_lock <avd name> takes a lock DIRECTORY (mkdir is atomic) in the temp directory, so every checkout
# and every repository on this machine shares it. It waits up to 4 hours (a full persona run is about 2), and takes
# over a lock whose holder is no longer running. patrol_emulator_unlock removes it; call it from the EXIT trap.
TSR_PATROL_EMULATOR_LOCK=""

patrol_emulator_lock() {
  local dir="${TMPDIR:-/tmp}/tsr-patrol-emulator-$1.lock" waited=0 holder
  while ! mkdir "$dir" 2>/dev/null; do
    holder="$(cat "$dir/pid" 2>/dev/null || true)"
    if [ -n "$holder" ] && ! kill -0 "$holder" 2>/dev/null; then
      echo "taking over the emulator lock of a runner that is gone (pid $holder)" >&2
      rm -f "$dir/pid"; rmdir "$dir" 2>/dev/null || true
      continue
    fi
    if [ "$waited" -ge 14400 ]; then echo "emulator busy for 4 hours; lock held at $dir (pid ${holder:-unknown})" >&2; exit 1; fi
    [ "$waited" -ne 0 ] || echo "another Patrol run holds the emulator (pid ${holder:-unknown}); waiting for $dir" >&2
    sleep 5; waited=$((waited + 5))
  done
  echo "$$" > "$dir/pid"
  TSR_PATROL_EMULATOR_LOCK="$dir"
}

patrol_emulator_unlock() {
  if [ -n "$TSR_PATROL_EMULATOR_LOCK" ]; then
    rm -f "$TSR_PATROL_EMULATOR_LOCK/pid"; rmdir "$TSR_PATROL_EMULATOR_LOCK" 2>/dev/null || true
    TSR_PATROL_EMULATOR_LOCK=""
  fi
}
