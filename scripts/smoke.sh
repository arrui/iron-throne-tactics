#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_DIR="$ROOT_DIR/game/冰与火"

export HOME="${HOME:-/tmp}"
if [[ ! -d "$HOME" || ! -w "$HOME" ]]; then
  export HOME="/tmp"
fi

cd "$PROJECT_DIR"
echo "[smoke] project: $PROJECT_DIR"
echo "[smoke] HOME=$HOME"
# 仅验证项目可被 headless 正常启动
# quit-after 让 Godot 在短时间后自动退出
# 某些 macOS 环境会打印 CA 证书警告，不影响退出码

godot --headless --path . --quit-after 60
