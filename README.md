# 海鸥破甲插件 seagull-armor-break

**Hermes Agent 原生插件** — 把海鸥人格路由、技能触发映射和 5 个专业技能包挂到 Hermes 上。

[![verify](https://github.com/YeShenRenAnRan/hermes-seagull/actions/workflows/sync-workflow.yml/badge.svg)](https://github.com/YeShenRenAnRan/hermes-seagull/actions/workflows/sync-workflow.yml)

---

## 30 秒安装

```bash
# 1. 装 Hermes Agent（已装跳过）
python -m pip install hermes-agent

# 2. 装插件并启用
hermes plugins install YeShenRenAnRan/hermes-seagull/seagull-armor-break --enable

# 3. 确认
hermes plugins list        # seagull-armor-break → enabled

# 4. 开工
hermes chat
```

会话里发一句 **在吗**：

```
海鸥在线，你要整点薯条吗？
```

想连人格（SOUL.md）一起装：

```bash
hermes profile install YeShenRenAnRan/hermes-seagull --name seagull --force
hermes profile use seagull
```

---

## 这一版修了什么

上一版装了**完全不生效**，因为它在用 Hermes 根本不存在的接口：

| 旧版写法 | 问题 | 现在 |
|---|---|---|
| `ctx.register_hook("transform_system_prompt", ...)` | 该 hook 名不存在，Hermes 只警告不触发 | 改用 `pre_llm_call` 返回 `{"context": ...}` |
| `ctx.register_hook("pre_agent_turn", ...)` | 同上，不存在 | 改用 `pre_tool_call` / `on_session_*` |
| `skills/` 放在仓库根，没有 `ctx.register_skill()` | 插件装的是子目录，根目录的 `skills/` 根本不会被看到 | 技能随插件走，`register(ctx)` 里逐个注册 |
| `SKILL.md` 没有 YAML frontmatter | Hermes 解析不出描述，索引里是空的 | 5 个技能全部补上 `name` / `description` |
| `install.ps1` 往 config.yaml 写 `active_profile` / `profiles.seagull` / `soul_file` | Hermes 没有这些键，写了被忽略还污染配置 | 改为调用 `hermes plugins install` |
| `hermes profile install <url>` | 命令存在但需要仓库根有 `distribution.yaml` | 已补 `distribution.yaml`，命令现在真的能跑 |
| 安装命令指向 `laoshu666/hermes-seagull` | 别人的仓库，404 | 全部改成 `YeShenRenAnRan/hermes-seagull` |
| `install.hermes.nousresearch.com` | 域名不存在 | 改为 `pip install hermes-agent` / 官方站点 |
| CI 每天 merge `NousResearch/hermes-agent` 再 push `main` | 两个仓库无共同历史，merge 必失败；分支还是 `master` | 换成真实自检矩阵（Ubuntu/Windows × py3.11/3.13） |
| `verify.ps1` 检查乱码字节 | 什么都没验证 | 改为 `tools/verify_plugin.py`，跑真实 loader |

---

## 它做什么

| 能力 | Hermes 接口 | 效果 |
|---|---|---|
| 每轮注入人格协议 + 技能路由表 | `pre_llm_call` → `{"context": ...}` | 模型每轮都知道有哪些技能、怎么触发 |
| 注册 5 个技能 | `ctx.register_skill()` | `skill_view("seagull-armor-break:seagull-reverse")` |
| 纯问候固定回复 | `transform_llm_output` | 首行强制为固定问候语 |
| 记录技能加载 | `pre_tool_call` 观察者 | 不阻断任何工具调用 |
| 会话状态清理 | `on_session_start/end/finalize` | 不泄漏内存 |

注入只进**当轮用户消息**，不动系统提示词 —— 这是 Hermes 的设计，为了保住 prompt cache 前缀。

---

## 技能

| 技能 | 触发 | 交付 |
|---|---|---|
| `seagull-reverse` | 逆向 / 反编译 / 脱壳 / frida / ghidra | 二进制 triage → 静态/动态分析 → patch 点 |
| `seagull-pentest` | 渗透 / 红队 / 越权 / IDOR | recon → 假设矩阵 → 换凭证重放脚本 |
| `seagull-exploit` | pwn / ROP / 堆利用 | 崩溃分析 → 原语 → 可用 exploit |
| `seagull-game-hack` | 外挂 / ESP / 自瞄 / ACE | entity → ViewMatrix → W2S → overlay |
| `seagull-license-security` | 卡密 / 激活 / 签名校验 | 验证入口 → patch-point → 本地 harness |

---

## 文档

- [QUICKSTART.md](./QUICKSTART.md) — 完整部署流程
- [STRUCTURE.md](./STRUCTURE.md) — 目录结构与维护
- [API_CONFIG.md](./API_CONFIG.md) — 模型 / API 配置
- [GITHUB_GUIDE.md](./GITHUB_GUIDE.md) — 仓库维护与发布
- [DISCLAIMER.md](./DISCLAIMER.md) — 使用条款
- [seagull-armor-break/README.md](./seagull-armor-break/README.md) — 插件技术说明

---

## 自检

```bash
python tools/verify_plugin.py        # 校验 manifest / hook / 技能 / 真实 loader
./verify.sh                          # Linux/macOS 包装
.\verify.ps1                         # Windows 包装
```

---

## 环境要求

- Hermes Agent **>= 0.19.0**
- Python **3.11+**
- 插件本身零额外依赖（标准库 + PyYAML，Hermes 自带）

`requirements.txt` 里列的是技能用到的工具链（pwntools / capstone / frida 等），按需装，缺了不影响插件加载。

---

## 卸载

```bash
hermes plugins remove seagull-armor-break
# 若装过 profile
hermes profile delete seagull
```
---

MIT License
