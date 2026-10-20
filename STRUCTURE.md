# 项目结构

## 目录树

```
hermes-seagull/
├── seagull-armor-break/            # ← 插件本体（hermes plugins install 的目标）
│   ├── plugin.yaml                 #   清单：name/version/provides_hooks/provides_skills
│   ├── __init__.py                 #   register(ctx)：注册 hook + 技能
│   ├── README.md                   #   插件技术说明
│   ├── AGENTS.md                   #   可选补充协议（安装脚本会带进来）
│   └── skills/                     #   随插件分发的技能（ctx.register_skill 的源）
│       ├── seagull-reverse/SKILL.md
│       ├── seagull-pentest/SKILL.md
│       ├── seagull-exploit/SKILL.md
│       ├── seagull-game-hack/SKILL.md
│       └── seagull-license-security/SKILL.md
│
├── skills/                         # 同一批技能的规范源（profile 发行版用）
│   └── seagull-*/SKILL.md
│
├── tools/
│   └── verify_plugin.py            # 自检脚本（manifest / hook / 技能 / 真实 loader）
│
├── .github/workflows/
│   └── sync-workflow.yml           # CI：Ubuntu+Windows × py3.11/3.13 跑自检
│
├── distribution.yaml               # profile 发行版清单（hermes profile install 用）
├── SOUL.md                         # 海鸥人格（profile 的身份槽）
├── AGENTS.md                       # 技能路由与执行指令（工作目录上下文文件）
│
├── install.ps1 / install.sh        # 一键安装：组装插件 → hermes plugins install
├── verify.ps1  / verify.sh         # 调用 tools/verify_plugin.py
├── package.ps1                     # 打包 zip 并输出 SHA256
│
├── README.md / README.zh-CN.md     # 项目说明
├── QUICKSTART.md                   # 快速部署
├── STRUCTURE.md                    # 本文件
├── API_CONFIG.md                   # 模型 / API 配置
├── GITHUB_GUIDE.md                 # 仓库维护与发布
├── DISCLAIMER.md                   # 使用条款
├── requirements.txt                # 技能用到的工具链（不是插件依赖）
└── LICENSE                         # MIT
```

**为什么技能有两份？**

- `seagull-armor-break/skills/` —— 插件安装时 Hermes 只 clone 那个子目录，
  所以技能必须在那里面，`register(ctx)` 才能用 `ctx.register_skill()` 注册。
- `skills/` —— profile 发行版安装时会把仓库根的 `skills/` 拷进
  `~/.hermes/profiles/seagull/skills/`，让技能出现在磁盘索引里。

两份内容一致；`install.ps1` / `install.sh` 安装时会用根目录的版本覆盖插件目录的副本，
所以改技能改 `skills/` 就行。

---

## 核心文件

### seagull-armor-break/plugin.yaml

```yaml
name: seagull-armor-break
version: 1.0.0
description: "..."
author: "YeShenRenAnRan"
license: MIT
provides_hooks:        # 必须是 Hermes VALID_HOOKS 的成员
  - pre_llm_call
  - pre_tool_call
  - transform_llm_output
  - on_session_start
  - on_session_end
  - on_session_finalize
provides_skills:
  - seagull-reverse
  - ...
```

### seagull-armor-break/__init__.py

只依赖两样东西：

| 接口 | 用途 |
|---|---|
| `ctx.register_hook(name, fn)` | 挂生命周期钩子 |
| `ctx.register_skill(name, path, desc)` | 注册 `seagull-armor-break:<name>` |

hook 契约（Hermes 0.19.x）：

| hook | 传入 | 返回 |
|---|---|---|
| `pre_llm_call` | `session_id`, `user_message`, `is_first_turn`, `conversation_history`, `model`, `platform` | `{"context": "..."}` 或字符串 |
| `pre_tool_call` | `tool_name`, `args`, `session_id`, `tool_call_id` | `None`（或阻断指令） |
| `transform_llm_output` | `response_text`, `session_id`, `model`, `platform` | 替换后的字符串 |
| `on_session_start/end/finalize` | `session_id` | `None` |

注入只进**当轮用户消息**，永不进系统提示词 —— Hermes 刻意如此，为了保住 prompt cache 前缀。

### skills/seagull-*/SKILL.md

必须带 YAML frontmatter：

```yaml
---
name: seagull-reverse
description: 逆向工程技能 — ...
---
```

缺了 frontmatter，Hermes 解析不出 `description`，技能索引里就是空条目。

### SOUL.md

海鸥人格，装在 profile 的 `$HERMES_HOME/SOUL.md`，由 Hermes 放进系统提示词的身份槽。
**不参与插件**；插件负责路由，人格负责语气。

### AGENTS.md

技能路由表与执行模式。Hermes 从**当前工作目录**加载 `AGENTS.md`（只顶层，不递归）。
插件也会尝试从 `$HERMES_HOME/AGENTS.md` 或插件目录读一份作为补充注入。

### distribution.yaml

`hermes profile install` 的清单，必须在仓库根。字段：`name` / `version` /
`hermes_requires` / `author` / `license` / `distribution_owned`。

---

## 维护

### 加一个技能

1. `skills/<new-skill>/SKILL.md`，带 frontmatter（`name` 用目录名）
2. 同步到 `seagull-armor-break/skills/`
3. 在 `__init__.py` 的 `SKILL_ROUTES` 加触发词与确认词
4. 在 `plugin.yaml` 的 `provides_skills` 加名字
5. `python tools/verify_plugin.py`
6. 把新技能加进 `tools/verify_plugin.py` 的 `REQUIRED_SKILLS`

### 改注入内容

- 协议块：`__init__.py` 的 `PROTOCOL_BLOCK`
- 路由表渲染：`_build_catalog()`
- 上限：`MAX_INJECTED_CHARS`（**不要超过 10000**，Hermes 会截断落盘）

### 改人格

改 `SOUL.md`，然后 `hermes profile update seagull`。

### 改脚本文件

`seagull-armor-break/skills/` 和根 `skills/` 都改，或只改根目录然后重装
（安装脚本会用根目录覆盖）。

---

## 调试

```bash
hermes --dev chat                 # 打开插件调试日志
python tools/verify_plugin.py     # 完整自检
hermes plugins list               # 状态
hermes config show | grep plugins # 看 plugins.enabled
```

环境变量：`HERMES_HOME` 指定配置目录；`HERMES_LIB` 指定 hermes-agent 源码路径
（给 `tools/verify_plugin.py` 用，未安装时）。
