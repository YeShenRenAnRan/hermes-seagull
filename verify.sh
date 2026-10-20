#!/usr/bin/env bash
# 海鸥破甲插件自检 (Linux / macOS)
#
# 调用 tools/verify_plugin.py：校验 plugin.yaml、hook 名、技能 frontmatter，
# 并在本机装了 hermes-agent 时用真实 loader 试加载一次。

set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PY="$(command -v python3 || command -v python || true)"
if [ -z "$PY" ]; then
  echo "[X] 找不到 python，无法自检"
  exit 1
fi

VERIFIER="$REPO_ROOT/tools/verify_plugin.py"
if [ ! -f "$VERIFIER" ]; then
  echo "[X] 缺 tools/verify_plugin.py"
  exit 1
fi

exec "$PY" "$VERIFIER" --plugin-dir "$REPO_ROOT/seagull-armor-break" "$@"
