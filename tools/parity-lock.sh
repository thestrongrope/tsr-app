#!/usr/bin/env bash
# Sourced by the contract scripts' parity side. The one PHP parity stack is shared by every git worktree, so
# fixture loads and test runs on it must not interleave: parity_lock takes a lock DIRECTORY (mkdir is atomic) under the
# repository's common git directory, waits up to 10 minutes, and parity_unlock (call it from the script's EXIT trap) removes it.
# A crashed run that left the lock behind: remove the directory the message names.
TSR_PARITY_LOCK_DIR=""

parity_lock() {
  local dir waited=0
  dir="$(git rev-parse --path-format=absolute --git-common-dir)/tsr-parity.lock"
  while ! mkdir "$dir" 2> /dev/null; do
    if [ "$waited" -ge 600 ]; then echo "parity stack busy for 10 minutes; lock held at $dir" >&2; exit 1; fi
    [ "$waited" -ne 0 ] || echo "waiting for the parity lock ($dir)" >&2
    sleep 2; waited=$((waited + 2))
  done
  TSR_PARITY_LOCK_DIR="$dir"
  trap parity_unlock EXIT
}

parity_unlock() {
  if [ -n "$TSR_PARITY_LOCK_DIR" ]; then rmdir "$TSR_PARITY_LOCK_DIR"; TSR_PARITY_LOCK_DIR=""; fi
}
