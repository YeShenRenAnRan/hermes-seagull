#!/usr/bin/env python3
"""海鸥破甲插件自检 — 校验它是否真的能被 Hermes Agent 加载。

比旧版 verify 脚本强的地方：
  * 校验 plugin.yaml 的字段与 hook 名是否真实存在于 Hermes 的 VALID_HOOKS
  * 校验 skills/*/SKILL.md 的 frontmatter（缺了 Hermes 解析不出描述）
  * 语法编译 __init__.py
  * 若本机装了 hermes-agent，用真实 loader 跑一遍并检查 hook / skill 注册结果
  * 若装了 hermes CLI，额外跑 `hermes plugins list` 确认可见

用法：
    python tools/verify_plugin.py [--plugin-dir PATH] [--no-hermes]
"""

from __future__ import annotations

import argparse
import ast
import importlib.util
import py_compile
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_PLUGIN = REPO_ROOT / "seagull-armor-break"

# Hermes 0.19.x 的 VALID_HOOKS 快照；运行时若 import 得到真值则以真值为准
KNOWN_HOOKS = {
    "pre_tool_call", "post_tool_call", "transform_terminal_output",
    "transform_tool_result", "transform_llm_output", "pre_llm_call",
    "post_llm_call", "pre_verify", "pre_api_request", "post_api_request",
    "api_request_error", "on_session_start", "on_session_end",
    "on_session_finalize", "on_session_reset", "subagent_start", "subagent_stop",
}

REQUIRED_SKILLS = [
    "seagull-reverse",
    "seagull-pentest",
    "seagull-exploit",
    "seagull-game-hack",
    "seagull-license-security",
]

GREEN, RED, YELLOW, CYAN, RESET = "\033[32m", "\033[31m", "\033[33m", "\033[36m", "\033[0m"
if sys.platform == "win32" and not sys.stdout.isatty():
    GREEN = RED = YELLOW = CYAN = RESET = ""

errors: list[str] = []
warnings: list[str] = []


def ok(msg: str) -> None:
    print(f"  {GREEN}[OK]{RESET} {msg}")


def bad(msg: str) -> None:
    print(f"  {RED}[FAIL]{RESET} {msg}")
    errors.append(msg)


def warn(msg: str) -> None:
    print(f"  {YELLOW}[WARN]{RESET} {msg}")
    warnings.append(msg)


def section(title: str) -> None:
    print(f"\n{CYAN}{title}{RESET}")


def _dir_writable(path: str | Path) -> bool:
    """这个目录能不能真的写文件（受限环境里 tempfile.gettempdir() 可能不可写）。"""
    p = Path(path)
    try:
        p.mkdir(parents=True, exist_ok=True)
        probe = p / ".seagull-write-probe"
        probe.write_text("x", encoding="utf-8")
        probe.unlink()
        return True
    except Exception:
        return False


def parse_manifest(path: Path) -> dict:
    text = path.read_text(encoding="utf-8-sig")
    try:
        import yaml  # type: ignore

        data = yaml.safe_load(text) or {}
        return data if isinstance(data, dict) else {}
    except ImportError:
        # 无 PyYAML 时的极简解析：只取顶层 key: value 与列表
        data: dict = {}
        current = None
        for line in text.splitlines():
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            if re.match(r"^[A-Za-z_][\w-]*\s*:", line):
                key, _, value = line.partition(":")
                key, value = key.strip(), value.strip()
                if value:
                    data[key] = value.strip('"\'')
                    current = None
                else:
                    data[key] = []
                    current = key
            elif current and line.lstrip().startswith("- "):
                data[current].append(line.lstrip()[2:].strip().strip('"\''))
        return data


def find_hermes_lib() -> Path | None:
    """返回能 import hermes_cli.plugins 的路径（已安装或用 HERMES_LIB 指定）。"""
    if importlib.util.find_spec("hermes_cli") is not None:
        return None  # 已可 import
    import os

    env = os.environ.get("HERMES_LIB")
    candidates = [Path(env)] if env else []
    candidates += [Path.home() / ".hermes" / "lib"]
    for cand in candidates:
        if (cand / "hermes_cli" / "plugins.py").is_file():
            sys.path.insert(0, str(cand))
            return cand
    return None


def check_manifest(plugin: Path, valid_hooks: set[str]) -> None:
    section("[1] plugin.yaml")
    manifest_file = plugin / "plugin.yaml"
    if not manifest_file.is_file():
        bad("缺 plugin.yaml（Hermes 不会发现这个目录）")
        return
    data = parse_manifest(manifest_file)

    name = str(data.get("name") or "")
    if not name:
        bad("plugin.yaml 缺 name")
    elif name != plugin.name:
        warn(f"name={name} 与目录名 {plugin.name} 不一致（Hermes 用目录名做 key）")
    else:
        ok(f"name: {name}")

    for field in ("version", "description"):
        if data.get(field):
            ok(f"{field}: {str(data[field])[:50]}")
        else:
            warn(f"缺 {field}（不影响加载，但 hermes plugins list 会空着）")

    declared = data.get("provides_hooks") or []
    if not isinstance(declared, list):
        bad("provides_hooks 必须是列表")
        declared = []
    for hook in declared:
        if hook in valid_hooks:
            ok(f"hook 声明有效: {hook}")
        else:
            bad(f"provides_hooks 里有 Hermes 不存在的 hook: {hook}")


def check_init(plugin: Path, valid_hooks: set[str]) -> None:
    section("[2] __init__.py")
    init = plugin / "__init__.py"
    if not init.is_file():
        bad("缺 __init__.py（Hermes 找不到 register()）")
        return

    try:
        py_compile.compile(str(init), doraise=True, cfile=str(Path(tempfile.gettempdir()) / "seagull_check.pyc"))
        ok("语法编译通过")
    except py_compile.PyCompileError as exc:
        bad(f"语法错误: {exc}")
        return

    tree = ast.parse(init.read_text(encoding="utf-8-sig"))
    has_register = any(
        isinstance(node, ast.FunctionDef) and node.name == "register" for node in tree.body
    )
    if has_register:
        ok("存在模块级 register(ctx)")
    else:
        bad("没有模块级 register(ctx)，Hermes 会报 'no register() function'")

    source = init.read_text(encoding="utf-8-sig")
    registered = set(re.findall(r'register_hook\(\s*["\']([^"\']+)["\']', source))
    if not registered:
        warn("没有调用 ctx.register_hook()")
    for hook in sorted(registered):
        if hook in valid_hooks:
            ok(f"register_hook 使用了有效 hook: {hook}")
        else:
            bad(f"register_hook 使用了 Hermes 不存在的 hook: {hook}（永不触发）")

    if "register_system_prompt_section" in source:
        bad("register_system_prompt_section 在 Hermes 0.19.x 不存在，会 AttributeError")
    if re.search(r"from\s+hermes_cli\.|import\s+hermes_cli", source):
        warn("__init__.py 直接 import 了 Hermes 内部模块，升级后有 ImportError 风险")
    else:
        ok("没有硬依赖 Hermes 内部模块")


def check_skills(plugin: Path) -> None:
    section("[3] skills/")
    skills_dir = plugin / "skills"
    if not skills_dir.is_dir():
        bad("缺 skills/ 目录（ctx.register_skill 会找不到文件）")
        return
    found = []
    for child in sorted(skills_dir.iterdir()):
        if not child.is_dir():
            continue
        md = child / "SKILL.md"
        if not md.is_file():
            bad(f"{child.name}: 缺 SKILL.md")
            continue
        if not re.fullmatch(r"[a-zA-Z0-9_-]+", child.name):
            bad(f"{child.name}: 目录名必须是 [a-zA-Z0-9_-]+（register_skill 要求）")
        text = md.read_text(encoding="utf-8-sig")
        if not text.startswith("---"):
            bad(f"{child.name}: SKILL.md 缺 YAML frontmatter（name/description）")
        else:
            end = re.search(r"\n---\s*\n", text[3:])
            if not end:
                bad(f"{child.name}: frontmatter 没有闭合的 ---")
            else:
                fm = text[3 : end.start() + 3]
                if re.search(r"^name\s*:", fm, re.M) and re.search(r"^description\s*:", fm, re.M):
                    ok(f"{child.name}: frontmatter 完整")
                else:
                    bad(f"{child.name}: frontmatter 缺 name 或 description")
        found.append(child.name)

    missing = [s for s in REQUIRED_SKILLS if s not in found]
    for name in missing:
        bad(f"缺技能: {name}")
    if not missing:
        ok(f"5 个技能齐全: {', '.join(REQUIRED_SKILLS)}")


def _fallback_register(plugin: Path, valid_hooks: set[str]) -> None:
    """不依赖临时目录的直接注册检查：import __init__.py，传入 stub ctx。

    沙箱/受限环境下 tempfile 不可用时用这条路径，仍能验证 register(ctx)
    真的能跑通、hook 名合法、技能能被注册。
    """
    import importlib.util
    import types

    init = plugin / "__init__.py"
    spec = importlib.util.spec_from_file_location("seagull_verify_direct", init)
    if spec is None or spec.loader is None:
        bad("无法构造模块 spec")
        return
    module = importlib.util.module_from_spec(spec)
    try:
        spec.loader.exec_module(module)
    except Exception as exc:
        bad(f"import __init__.py 失败: {exc.__class__.__name__}: {exc}")
        return
    ok("import __init__.py 成功")

    hooks: list[str] = []
    skills: dict[str, str] = {}

    ctx = types.SimpleNamespace(
        manifest=types.SimpleNamespace(name=plugin.name, key=plugin.name),
        register_hook=lambda name, cb: hooks.append(name),
        register_skill=lambda name, path, description="": skills.__setitem__(name, str(path)),
    )

    register = getattr(module, "register", None)
    if not callable(register):
        bad("没有可调用的 register(ctx)")
        return
    try:
        register(ctx)
    except Exception as exc:
        bad(f"register(ctx) 抛异常: {exc.__class__.__name__}: {exc}")
        return
    ok(f"register(ctx) 执行成功（hook={len(hooks)}, skill={len(skills)}）")

    for hook in hooks:
        if hook not in valid_hooks:
            bad(f"注册了无效 hook: {hook}")
    if hooks and all(h in valid_hooks for h in hooks):
        ok(f"注册的 hook 全部有效: {', '.join(sorted(hooks))}")

    missing = [s for s in REQUIRED_SKILLS if s not in skills]
    if missing:
        bad(f"未注册的技能: {', '.join(missing)}")
    else:
        ok(f"技能注册成功: {', '.join(sorted(skills))}")

    # 直接用 stub 触发 hook 逻辑
    try:
        result = module.on_pre_llm_call(
            session_id="verify", user_message="帮我逆向一个 so", is_first_turn=True,
        )
        if isinstance(result, dict) and result.get("context"):
            size = len(result["context"])
            if size > 10_000:
                bad(f"注入上下文 {size} 字符，超过 Hermes 10000 字符上限会被截断")
            else:
                ok(f"pre_llm_call 返回可注入上下文 ({size} 字符)")
        else:
            bad("pre_llm_call 没有返回 {'context': ...}")
    except AttributeError:
        warn("模块没有暴露 on_pre_llm_call，跳过行为检查")
    except Exception as exc:
        bad(f"pre_llm_call 调用异常: {exc.__class__.__name__}: {exc}")

    try:
        module.on_pre_llm_call(session_id="verify2", user_message="在吗", is_first_turn=True)
        forced = module.on_transform_llm_output(response_text="在的", session_id="verify2")
        if isinstance(forced, str) and "薯条" in forced:
            ok(f"问候语强制生效: {forced.splitlines()[0]}")
        else:
            bad(f"纯问候没有触发固定问候语（返回 {forced!r}）")
    except AttributeError:
        warn("模块没有暴露 on_transform_llm_output，跳过问候检查")
    except Exception as exc:
        bad(f"问候逻辑异常: {exc.__class__.__name__}: {exc}")


def check_live_load(plugin: Path) -> None:
    section("[4] 真实 Hermes loader 试加载")
    try:
        from hermes_cli import plugins as P  # type: ignore
    except Exception as exc:
        warn(f"本机没有可 import 的 hermes-agent（{exc.__class__.__name__}），跳过试加载")
        return

    valid_hooks = set(getattr(P, "VALID_HOOKS", KNOWN_HOOKS))

    # 优先用真实 loader；tempfile 被沙箱挡住时退回直接注册检查
    try:
        tmp_home = Path(tempfile.mkdtemp(prefix="seagull-verify-"))
    except Exception as exc:
        warn(f"临时目录不可用（{exc.__class__.__name__}），退回直接注册检查")
        _fallback_register(plugin, valid_hooks)
        return

    try:
        dest = tmp_home / "plugins" / plugin.name
        shutil.copytree(plugin, dest)
        import os

        os.environ["HERMES_HOME"] = str(tmp_home)

        P._get_enabled_plugins = lambda: {plugin.name}  # type: ignore[assignment]
        manager = P.PluginManager()
        manager.discover_and_load(force=True)

        entry = next((p for p in manager.list_plugins() if p["name"] == plugin.name), None)
        if entry is None:
            bad("Hermes 没发现这个插件")
            return
        if entry.get("error"):
            bad(f"加载报错: {entry['error']}")
            return
        ok(f"加载成功 (source={entry['source']}, hooks={entry['hooks']})")

        bad_hooks = [h for h in manager._hooks if h not in valid_hooks]
        for hook in bad_hooks:
            bad(f"注册了无效 hook: {hook}")
        if not bad_hooks:
            ok(f"注册的 hook 全部有效: {', '.join(sorted(manager._hooks))}")

        skills = manager.list_plugin_skills(plugin.name)
        missing = [s for s in REQUIRED_SKILLS if s not in skills]
        if missing:
            bad(f"未注册的技能: {', '.join(missing)}")
        else:
            ok(f"技能注册成功: {', '.join(skills)}")

        ctx = manager.invoke_hook(
            "pre_llm_call", session_id="verify", user_message="帮我逆向一个 so",
            is_first_turn=True, model="verify", platform="cli",
        )
        if ctx and isinstance(ctx[0], dict) and "context" in ctx[0]:
            size = len(ctx[0]["context"])
            if size > 10_000:
                bad(f"注入上下文 {size} 字符，超过 Hermes 10000 字符上限会被截断")
            else:
                ok(f"pre_llm_call 返回可注入上下文 ({size} 字符)")
        else:
            bad("pre_llm_call 没有返回 {'context': ...}")

        manager.invoke_hook(
            "pre_llm_call", session_id="verify2", user_message="在吗",
            is_first_turn=True, model="verify", platform="cli",
        )
        forced = manager.invoke_hook(
            "transform_llm_output", response_text="在的", session_id="verify2",
            model="verify", platform="cli",
        )
        if forced and isinstance(forced[0], str) and "薯条" in forced[0]:
            ok(f"问候语强制生效: {forced[0].splitlines()[0]}")
        else:
            bad("纯问候没有触发固定问候语")
    except Exception as exc:
        warn(f"真实 loader 试加载异常（{exc.__class__.__name__}），退回直接注册检查")
        _fallback_register(plugin, valid_hooks)
    finally:
        shutil.rmtree(tmp_home, ignore_errors=True)


def check_cli(plugin: Path) -> None:
    section("[5] hermes CLI")
    hermes = shutil.which("hermes")
    if not hermes:
        warn("PATH 里没有 hermes 命令，跳过 CLI 检查")
        return
    try:
        out = subprocess.run(
            [hermes, "plugins", "list"], capture_output=True, text=True, timeout=180,
            encoding="utf-8", errors="replace",
        )
    except Exception as exc:
        warn(f"hermes plugins list 执行失败: {exc}")
        return
    if plugin.name in (out.stdout or ""):
        ok(f"hermes plugins list 能看到 {plugin.name}")
    else:
        warn(f"hermes plugins list 里没有 {plugin.name}（还没安装？）")


def check_skills_sync(plugin: Path) -> None:
    """根 skills/ 是规范源，插件目录里的副本必须与之一致。

    两份文件漂移过的话，用户改根目录的技能却不生效（或反过来），
    是这套布局最容易踩的坑。
    """
    section("[6] 技能副本一致性")
    root_skills = REPO_ROOT / "skills"
    plugin_skills = plugin / "skills"
    if not root_skills.is_dir():
        warn("仓库根没有 skills/，无法比对")
        return

    drifted: list[str] = []
    for src in sorted(root_skills.rglob("*")):
        if not src.is_file() or "__pycache__" in src.parts:
            continue
        rel = src.relative_to(root_skills)
        dst = plugin_skills / rel
        if not dst.is_file():
            drifted.append(f"{rel} (插件目录里缺失)")
            continue
        if src.read_bytes() != dst.read_bytes():
            drifted.append(f"{rel} (内容不一致)")

    for dst in sorted(plugin_skills.rglob("*")):
        if not dst.is_file() or "__pycache__" in dst.parts:
            continue
        rel = dst.relative_to(plugin_skills)
        if not (root_skills / rel).is_file():
            drifted.append(f"{rel} (只存在于插件目录)")

    if drifted:
        for d in drifted:
            warn(f"技能副本漂移: {d}")
        warn("跑 install.ps1 / install.sh 重装会自动以根 skills/ 为准同步，或手动复制")
    else:
        ok("根 skills/ 与插件 skills/ 一致")


def main() -> int:
    parser = argparse.ArgumentParser(description="校验海鸥破甲插件")
    parser.add_argument("--plugin-dir", default=str(DEFAULT_PLUGIN))
    parser.add_argument("--no-hermes", action="store_true", help="跳过真实 loader 试加载")
    args = parser.parse_args()

    # 受限环境里系统临时目录可能不可写；能写仓库本地 .tmp 就用它
    import os

    if not _dir_writable(tempfile.gettempdir()):
        local_tmp = REPO_ROOT / ".tmp"
        if _dir_writable(local_tmp):
            os.environ["TMPDIR"] = os.environ["TEMP"] = os.environ["TMP"] = str(local_tmp)
            tempfile.tempdir = str(local_tmp)

    plugin = Path(args.plugin_dir).resolve()
    print(f"{CYAN}海鸥破甲插件自检{RESET}")
    print(f"插件目录: {plugin}")

    if not plugin.is_dir():
        print(f"{RED}[FAIL]{RESET} 插件目录不存在")
        return 1

    find_hermes_lib()
    valid_hooks = set(KNOWN_HOOKS)
    try:
        from hermes_cli.plugins import VALID_HOOKS  # type: ignore

        valid_hooks = set(VALID_HOOKS)
        print(f"Hermes hook 契约: 已从 hermes_cli.plugins 读取 ({len(valid_hooks)} 个)")
    except Exception:
        print(f"Hermes hook 契约: 使用内置快照 ({len(valid_hooks)} 个)")

    check_manifest(plugin, valid_hooks)
    check_init(plugin, valid_hooks)
    check_skills(plugin)
    if not args.no_hermes:
        check_live_load(plugin)
    check_skills_sync(plugin)
    check_cli(plugin)

    print()
    print("=" * 46)
    if errors:
        print(f"{RED}失败 {len(errors)} 项{RESET}，{YELLOW}警告 {len(warnings)} 项{RESET}")
        for e in errors:
            print(f"  - {e}")
        return 1
    print(f"{GREEN}全部通过{RESET}（警告 {len(warnings)} 项）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
