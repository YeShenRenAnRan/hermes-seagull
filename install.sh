#!/usr/bin/env bash
# 海鸥破甲插件安装脚本 (Linux / macOS)
#
# 1. 组装完整插件目录（含 skills/ 与 AGENTS.md）
# 2. 用 Hermes 官方命令安装并启用
#
# 不再往 config.yaml 写 active_profile / profiles.seagull / soul_file
# 这些 Hermes 根本不存在的键。

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_SRC="$REPO_ROOT/seagull-armor-break"
NO_ENABLE=0

for arg in "$@"; do
  case "$arg" in
    --no-enable) NO_ENABLE=1 ;;
    -h|--help)
      echo "用法: $0 [--no-enable]"
      exit 0
      ;;
  esac
done

step() { printf '\033[36m[*] %s\033[0m\n' "$1"; }
ok()   { printf '\033[32m[OK] %s\033[0m\n' "$1"; }
warn() { printf '\033[33m[!] %s\033[0m\n' "$1"; }
err()  { printf '\033[31m[X] %s\033[0m\n' "$1"; }

echo
echo "=========================================="
echo "  海鸥破甲插件 - 安装"
echo "=========================================="
echo

[ -d "$PLUGIN_SRC" ] || { err "找不到插件目录: $PLUGIN_SRC"; exit 1; }

# --- 1. 组装 -------------------------------------------------------------
step "组装插件目录..."
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/seagull-stage-XXXXXX")"
STAGE_PLUGIN="$STAGE/seagull-armor-break"
mkdir -p "$STAGE_PLUGIN"
cp -R "$PLUGIN_SRC"/. "$STAGE_PLUGIN"/

# 仓库根的 skills/ 是规范源
if [ -d "$REPO_ROOT/skills" ]; then
  rm -rf "$STAGE_PLUGIN/skills"
  cp -R "$REPO_ROOT/skills" "$STAGE_PLUGIN/skills"
fi

[ -f "$REPO_ROOT/AGENTS.md" ] && cp "$REPO_ROOT/AGENTS.md" "$STAGE_PLUGIN/AGENTS.md"
rm -rf "$STAGE_PLUGIN/__pycache__"
ok "已组装: $STAGE_PLUGIN"

# --- 2. 校验技能 ---------------------------------------------------------
step "校验 SKILL.md..."
BAD=0
for d in "$STAGE_PLUGIN"/skills/*/; do
  [ -d "$d" ] || continue
  name="$(basename "$d")"
  md="$d/SKILL.md"
  if [ ! -f "$md" ]; then
    warn "$name: 缺 SKILL.md"; BAD=$((BAD+1)); continue
  fi
  if [ "$(head -c 3 "$md")" != "---" ]; then
    warn "$name: SKILL.md 缺 YAML frontmatter（name/description）"; BAD=$((BAD+1))
  else
    ok "$name/SKILL.md"
  fi
done
[ "$BAD" -gt 0 ] && warn "$BAD 个技能有问题，Hermes 仍可加载但索引不完整"

# --- 3. 安装 -------------------------------------------------------------
HERMES_BIN="$(command -v hermes || true)"

if [ -z "$HERMES_BIN" ]; then
  warn "没找到 hermes 命令，改为直接复制到插件目录"
  HERMES_HOME_DIR="${HERMES_HOME:-$HOME/.hermes}"
  DEST="$HERMES_HOME_DIR/plugins/seagull-armor-break"
  rm -rf "$DEST"
  mkdir -p "$(dirname "$DEST")"
  cp -R "$STAGE_PLUGIN" "$DEST"
  ok "已复制到: $DEST"
  echo
  warn "还需要启用：在 $HERMES_HOME_DIR/config.yaml 的 plugins.enabled 里加上 seagull-armor-break"
  echo "或装好 Hermes 后运行：hermes plugins enable seagull-armor-break"
else
  ok "hermes: $HERMES_BIN"
  step "安装插件..."
  # 本地目录走 file:// 形式，Hermes 会把它当 git 源 clone 到 ~/.hermes/plugins/
  STAGE_URL="file://$(printf '%s' "$STAGE_PLUGIN" | sed 's| |%20|g')"
  if [ "$NO_ENABLE" -eq 1 ]; then
    "$HERMES_BIN" plugins install "$STAGE_URL" --no-enable
  else
    "$HERMES_BIN" plugins install "$STAGE_URL" --enable
  fi
  ok "插件已安装"
fi

rm -rf "$STAGE"

# --- 4. 人格文件 ---------------------------------------------------------
echo
step "想要海鸥人格（SOUL.md）也生效，另外装 profile 发行版"
echo "  hermes profile install YeShenRenAnRan/hermes-seagull --name seagull --force"
echo "  hermes profile use seagull"
echo "  说明：AGENTS.md 只从工作目录加载，把仓库里的 AGENTS.md 放到你常开工的目录即可。"

echo
echo "=========================================="
ok "安装完成"
echo "=========================================="
echo
echo "验证："
echo "  hermes plugins list          # seagull-armor-break 应为 enabled"
echo "  hermes chat                  # 输入 '在吗'"
echo "  预期: 海鸥在线，你要整点薯条吗？"
echo
