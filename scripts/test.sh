#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_DIR="$ROOT_DIR/game/冰与火"

export HOME="${HOME:-/private/tmp}"
if [[ ! -d "$HOME" || ! -w "$HOME" ]]; then
  export HOME="/private/tmp"
fi

cd "$PROJECT_DIR"
echo "[test] project: $PROJECT_DIR"
echo "[test] HOME=$HOME"

IMPORT_LOG="$(mktemp "${TMPDIR:-/tmp}/iron-throne-import.XXXXXX")"
TEST_LOG="$(mktemp "${TMPDIR:-/tmp}/iron-throne-tests.XXXXXX")"
trap 'rm -f "$IMPORT_LOG" "$TEST_LOG"' EXIT

echo "[test] importing project and refreshing global script classes"
if ! godot --headless --path . --import 2>&1 | tee "$IMPORT_LOG"; then
  echo "[test] ERROR: Godot project import failed" >&2
  exit 1
fi
if grep -Eq 'SCRIPT ERROR:|ERROR: Failed to load script' "$IMPORT_LOG"; then
  echo "[test] ERROR: script error detected during project import" >&2
  exit 1
fi

echo "[test] running automated suites"
if ! godot --headless --path . --script tests/run_tests.gd 2>&1 | tee "$TEST_LOG"; then
  echo "[test] ERROR: Godot test process failed" >&2
  exit 1
fi
if grep -Eq 'SCRIPT ERROR:|ERROR: Failed to load script' "$TEST_LOG"; then
  echo "[test] ERROR: script error detected during test run" >&2
  exit 1
fi
SUITE_COUNT="$(grep -E '^TEST_RUN_COMPLETE suites=[0-9]+$' "$TEST_LOG" | tail -1 | sed -E 's/^TEST_RUN_COMPLETE suites=([0-9]+)$/\1/')"
if [[ -z "$SUITE_COUNT" ]]; then
  echo "[test] ERROR: test runner did not emit a completion marker" >&2
  exit 1
fi
if ! grep -Fxq "TEST_RUN_COMPLETE suites=$SUITE_COUNT" "$TEST_LOG"; then
  echo "[test] ERROR: test runner completion marker is inconsistent" >&2
  exit 1
fi
