# 海鸥破甲插件 seagull-armor-break

Hermes Agent 的**原生插件**（`plugin.yaml` + `register(ctx)`），把海鸥人格路由、
技能触发映射和 5 个专业技能包挂到 Hermes 上。

---

## 它到底做什么

| 能力 | 实现 | Hermes 接口 |
|---|---|---|
| 每轮注入人格协议 + 技能路由表 | `pre_llm_call` 返回 `{"context": ...}` | 注入到当轮用户消息 |
| 注册 5 个技能 | `ctx.register_skill()` | `skill_view("seagull-armor-break:<name>")` |
| 纯问候固定回复 | `transform_llm_output` | 保证首行是固定问候语 |
| 记录模型实际加载了哪个技能 | `pre_tool_call` 观察者 | 不阻断任何调用 |
| 会话状态清理 | `on_session_start/end/finalize` | 防内存泄漏 |

**没有任何 hook 名是编造的。** 上一版用的 `transform_system_prompt` 和
`pre_agent_turn` 在 Hermes 里不存在，所以装了也不生效 —— 这是本次修复的核心。

---

## 安装

```bash
hermes plugins install YeShenRenAnRan/hermes-seagull/seagull-armor-break --enable
```

验证：

```bash
hermes plugins list          # seagull-armor-break → enabled
```

会话内：

```
/skills                      # 应能看到 seagull-armor-break:* 的技能
在吗                          # → 海鸥在线，你要整点薯条吗？
逆向这个 so 文件              # → 逆向工程已打开，然后加载 seagull-reverse
```

卸载：

```bash
hermes plugins remove seagull-armor-break
```

---

## 目录结构

```
seagull-armor-break/
├── plugin.yaml            # 清单：provides_hooks / provides_skills
├── __init__.py            # register(ctx)：注册 hook + 技能
├── AGENTS.md              # 可选补充协议（install 脚本会复制进来）
├── README.md              # 本文件
└── skills/
    ├── seagull-reverse/SKILL.md
    ├── seagull-pentest/SKILL.md
    ├── seagull-exploit/SKILL.md
    ├── seagull-game-hack/SKILL.md
    └── seagull-license-security/SKILL.md
```

`skills/*/SKILL.md` 必须有 YAML frontmatter（`name` + `description`），
否则 Hermes 解析不出描述，技能虽可加载但不会出现在索引里。

---

## 自定义

| 想改什么 | 改哪里 |
|---|---|
| 人格 / 身份 | `~/.hermes/SOUL.md`（Hermes 的身份槽，系统提示词里稳定生效） |
| 补充协议（路由表、执行模式） | `~/.hermes/AGENTS.md` 或插件目录的 `AGENTS.md` |
| 触发词 / 确认词 | `__init__.py` 里的 `SKILL_ROUTES` |
| 注入内容上限 | `__init__.py` 里的 `MAX_INJECTED_CHARS`（Hermes 硬上限 10000 字符） |

注入是**每轮**发生的，且只注入到用户消息、不写进系统提示词 ——
这是 Hermes 刻意设计，为了保住 prompt cache 前缀。

---

## 兼容性

- Hermes Agent `>= 0.19.0`（Python 3.11+）
- 只依赖 `hermes_cli.plugins.VALID_HOOKS` 和 `PluginContext` 的公开方法
- 不 import Hermes 内部模块，不 monkey-patch 核心，因此 Hermes 升级不会静默失效

MIT License
