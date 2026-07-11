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
godot --headless --path . --script tests/run_tests.gd
