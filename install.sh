#!/usr/bin/env bash
# 海鸥破甲插件安装脚本 (Linux / macOS)
#
# 三种安装方式：
#   默认      用 hermes plugins install 装（本地 file:// 源，不需要联网）
#   --copy    完全跳过 git，直接把插件目录拷进 $HERMES_HOME/plugins/ 再 enable
#   --no-enable  装但不启用
#
# 如果 hermes plugins install 失败（比如缺 git、或 git 被环境限制），
# 脚本会自动退到 --copy 那条路继续装完。
#
# 不再往 config.yaml 写 active_profile / profiles.seagull / soul_file
# 这些 Hermes 根本不存在的键。

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_SRC="$REPO_ROOT/seagull-armor-break"
PLUGIN_NAME="seagull-armor-break"
NO_ENABLE=0
FORCE_COPY=0
HERMES_HOME_DIR="${HERMES_HOME:-$HOME/.hermes}"

usage() {
  cat <<EOF
用法: $0 [选项]

  --copy        跳过 hermes plugins install，直接复制目录安装（无需 git / 无需联网）
  --no-enable   安装但不启用
  --dest DIR    指定插件目录位置（默认 \$HERMES_HOME/plugins，HERMES_HOME=$HERMES_HOME_DIR）
  -h, --help    显示本帮助
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --copy) FORCE_COPY=1 ;;
    --no-enable) NO_ENABLE=1 ;;
    --dest) shift; HERMES_HOME_DIR="$1" ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数: $1"; usage; exit 1 ;;
  esac
  shift
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
STAGE_PLUGIN="$STAGE/$PLUGIN_NAME"
cleanup() { rm -rf "$STAGE"; }
trap cleanup EXIT
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

HERMES_BIN="$(command -v hermes || true)"
DEST="$HERMES_HOME_DIR/plugins/$PLUGIN_NAME"

# --- 3a. 直接复制安装（离线路径）-----------------------------------------
copy_install() {
  step "直接复制安装（不经过 git）..."
  rm -rf "$DEST"
  mkdir -p "$(dirname "$DEST")"
  cp -R "$STAGE_PLUGIN" "$DEST"
  ok "已复制到: $DEST"

  if [ -n "$HERMES_BIN" ] && [ "$NO_ENABLE" -eq 0 ]; then
    step "启用插件..."
    if "$HERMES_BIN" plugins enable "$PLUGIN_NAME"; then
      ok "已启用"
    else
      warn "自动启用失败，手动执行: hermes plugins enable $PLUGIN_NAME"
      return 1
    fi
  elif [ "$NO_ENABLE" -eq 1 ]; then
    warn "按参数要求未启用。启用命令: hermes plugins enable $PLUGIN_NAME"
  else
    warn "没找到 hermes 命令，无法自动启用。"
    warn "在 $HERMES_HOME_DIR/config.yaml 的 plugins.enabled 里加上 $PLUGIN_NAME，"
    warn "或装好 Hermes 后执行: hermes plugins enable $PLUGIN_NAME"
  fi
  return 0
}

# --- 3b. 走 Hermes 官方安装 ----------------------------------------------
if [ "$FORCE_COPY" -eq 1 ] || [ -z "$HERMES_BIN" ]; then
  [ "$FORCE_COPY" -eq 1 ] && step "指定了 --copy，跳过 hermes plugins install"
  [ -z "$HERMES_BIN" ] && warn "没找到 hermes 命令"
  copy_install || true
else
  ok "hermes: $HERMES_BIN"
  step "安装插件（本地 file:// 源，不需要联网）..."
  STAGE_URL="file://$(printf '%s' "$STAGE_PLUGIN" | sed 's| |%20|g')"
  INSTALL_OK=0
  if [ "$NO_ENABLE" -eq 1 ]; then
    "$HERMES_BIN" plugins install "$STAGE_URL" --no-enable && INSTALL_OK=1 || INSTALL_OK=0
  else
    "$HERMES_BIN" plugins install "$STAGE_URL" --enable && INSTALL_OK=1 || INSTALL_OK=0
  fi

  if [ "$INSTALL_OK" -eq 1 ]; then
    ok "插件已安装"
  else
    warn "hermes plugins install 没成功，自动改用复制方式"
    copy_install || true
  fi
fi

# --- 4. 装完核对 ---------------------------------------------------------
if [ -n "$HERMES_BIN" ]; then
  echo
  step "核对安装结果..."
  if "$HERMES_BIN" plugins list 2>/dev/null | grep -q "$PLUGIN_NAME"; then
    "$HERMES_BIN" plugins list 2>/dev/null | grep "$PLUGIN_NAME" || true
    ok "$PLUGIN_NAME 已在插件列表中"
  else
    warn "插件列表里没看到 $PLUGIN_NAME，检查上面输出"
  fi
fi

# --- 5. 人格文件 ---------------------------------------------------------
echo
step "想要海鸥人格（SOUL.md）也生效，另外装 profile 发行版"
echo "  在本仓库目录里执行（本地路径，不需要联网）："
echo "    hermes profile install . --name seagull --force"
echo "    hermes profile use seagull"
echo "  或者从 GitHub 装："
echo "    hermes profile install YeShenRenAnRan/hermes-seagull --name seagull --force"
echo "  说明：AGENTS.md 只从工作目录加载，把仓库里的 AGENTS.md 放到你常开工的目录即可。"

echo
echo "=========================================="
ok "安装完成"
echo "=========================================="
echo
echo "验证："
echo "  hermes plugins list          # $PLUGIN_NAME 应为 enabled"
echo "  python3 tools/verify_plugin.py --no-hermes"
echo "  hermes chat                  # 输入 '在吗'"
echo "  预期: 海鸥在线，你要整点薯条吗？"
echo
