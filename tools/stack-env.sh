#!/usr/bin/env bash
# Sourced by every script that talks to the synthetic TEST stack. The one place that maps TSR_STACK to a stack.
#   TSR_STACK unset or empty   project tsr-app-test, gateway 8089, database 5434, emulator 19100, vars in build/test
#   TSR_STACK=n (integer 1-8)  project tsr-app-test-n, gateway 8100+n, database 5440+n, emulator 19110+n, vars in build/test-n
# Anything else is refused before any docker command. The ranges 8101-8108, 5441-5448 and 19111-19118 contain none of
# the dev stack's ports (8088, 5433, 19099), and every project name starts tsr-app-test, never tsr-app-dev.
# Exports TSR_TEST_PROJECT, TSR_TEST_BASE_URL, TSR_TEST_DB_PORT, TSR_TEST_EMULATOR_PORT, TSR_TEST_VARS_DIR (relative to the repo root).
# Never use this for the dev side: the dev values stay literal in each script.
case "${TSR_STACK:-}" in
  "")
    TSR_TEST_PROJECT=tsr-app-test; TSR_TEST_GATEWAY_PORT=8089; TSR_TEST_DB_PORT=5434
    TSR_TEST_EMULATOR_PORT=19100; TSR_TEST_VARS_DIR=build/test ;;
  [1-8])
    TSR_TEST_PROJECT="tsr-app-test-$TSR_STACK"; TSR_TEST_GATEWAY_PORT=$((8100 + TSR_STACK)); TSR_TEST_DB_PORT=$((5440 + TSR_STACK))
    TSR_TEST_EMULATOR_PORT=$((19110 + TSR_STACK)); TSR_TEST_VARS_DIR="build/test-$TSR_STACK" ;;
  *) echo "TSR_STACK must be unset or an integer from 1 to 8" >&2; exit 1 ;;
esac
TSR_TEST_BASE_URL="http://localhost:$TSR_TEST_GATEWAY_PORT"
export TSR_TEST_PROJECT TSR_TEST_GATEWAY_PORT TSR_TEST_BASE_URL TSR_TEST_DB_PORT TSR_TEST_EMULATOR_PORT TSR_TEST_VARS_DIR
