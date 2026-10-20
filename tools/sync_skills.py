#!/usr/bin/env python3
"""把根目录 skills/ 同步到 seagull-armor-break/skills/（或反向）。

这套仓库的技能有两份副本：
  * skills/                       —— profile 发行版（hermes profile install）用
  * seagull-armor-break/skills/   —— 插件（hermes plugins install）用

改完一边不跑这个脚本，另一边就是旧的。默认从根目录同步到插件目录。

用法：
    python tools/sync_skills.py            # 根 → 插件（默认）
    python tools/sync_skills.py --reverse  # 插件 → 根
    python tools/sync_skills.py --check    # 只检查，不写
"""

from __future__ import annotations

import argparse
import filecmp
import shutil
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
ROOT_SKILLS = REPO_ROOT / "skills"
PLUGIN_SKILLS = REPO_ROOT / "seagull-armor-break" / "skills"


def iter_files(base: Path):
    for path in sorted(base.rglob("*")):
        if path.is_file() and "__pycache__" not in path.parts:
            yield path.relative_to(base)


def diff(src: Path, dst: Path) -> list[str]:
    problems: list[str] = []
    if not src.is_dir():
        return [f"源目录不存在: {src}"]
    for rel in iter_files(src):
        target = dst / rel
        if not target.is_file():
            problems.append(f"{rel}: 目标缺失")
        elif not filecmp.cmp(src / rel, target, shallow=False):
            problems.append(f"{rel}: 内容不一致")
    if dst.is_dir():
        for rel in iter_files(dst):
            if not (src / rel).is_file():
                problems.append(f"{rel}: 只存在于目标")
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description="同步技能副本")
    parser.add_argument("--reverse", action="store_true", help="插件 → 根")
    parser.add_argument("--check", action="store_true", help="只检查不写")
    args = parser.parse_args()

    src, dst = (PLUGIN_SKILLS, ROOT_SKILLS) if args.reverse else (ROOT_SKILLS, PLUGIN_SKILLS)
    label = f"{src.relative_to(REPO_ROOT)} → {dst.relative_to(REPO_ROOT)}"

    problems = diff(src, dst)
    if args.check:
        if problems:
            print(f"不一致（{label}）:")
            for p in problems:
                print(f"  - {p}")
            return 1
        print(f"一致: {label}")
        return 0

    if not problems:
        print(f"已经一致，无需同步: {label}")
        return 0

    dst.mkdir(parents=True, exist_ok=True)
    for rel in iter_files(src):
        target = dst / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src / rel, target)

    # 删掉目标里源没有的文件（保持两边完全一致）
    if dst.is_dir():
        for rel in iter_files(dst):
            if not (src / rel).is_file():
                (dst / rel).unlink()

    remaining = diff(src, dst)
    if remaining:
        print("同步后仍有差异:")
        for p in remaining:
            print(f"  - {p}")
        return 1
    print(f"已同步: {label}（{len(list(iter_files(src)))} 个文件）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
