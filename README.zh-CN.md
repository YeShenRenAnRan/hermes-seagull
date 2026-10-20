# 海鸥破甲插件 seagull-armor-break

**Hermes Agent 原生插件** — 把海鸥人格路由、技能触发映射和 5 个专业技能包挂到 Hermes 上。

---

## ⚠️ 使用条款

使用前请读 [免责声明](./DISCLAIMER.md)。仅在 CTF、授权测试、自有环境、安全研究与教学场景使用。

---

## 30 秒安装

```bash
# 1. 装 Hermes Agent（已装跳过，需要 >= 0.19.0）
python -m pip install hermes-agent

# 2. 装插件并启用
hermes plugins install YeShenRenAnRan/hermes-seagull/seagull-armor-break --enable

# 3. 确认状态
hermes plugins list          # seagull-armor-break → enabled

# 4. 开工
hermes chat
```

会话里发 **在吗**：

```
海鸥在线，你要整点薯条吗？
```

想连人格（`SOUL.md`）一起装：

```bash
hermes profile install YeShenRenAnRan/hermes-seagull --name seagull --force
hermes profile use seagull
```

---

## 这一版修了什么

旧版装了**完全不生效**，因为它调用的接口在 Hermes 里不存在：

| 旧写法 | 问题 | 现在 |
|---|---|---|
| `register_hook("transform_system_prompt", ...)` | hook 名不存在，Hermes 只警告不触发 | 改 `pre_llm_call` 返回 `{"context": ...}` |
| `register_hook("pre_agent_turn", ...)` | 同上 | 改 `pre_tool_call` + `on_session_*` |
| 技能放仓库根、没调 `ctx.register_skill()` | 插件装的是子目录，根的 `skills/` 根本看不到 | 技能随插件走，`register(ctx)` 里注册 |
| `SKILL.md` 无 YAML frontmatter | Hermes 解析不出描述，索引是空条目 | 5 个技能全部补齐 |
| `install.ps1` 往 config.yaml 写 `active_profile` / `profiles.seagull` | Hermes 没这些键，写了被忽略还污染配置 | 改为 `hermes plugins install` |
| `hermes profile install <url>` | 需要仓库根有 `distribution.yaml` | 已补，命令现在真能跑 |
| 安装地址写 `laoshu666/hermes-seagull` | 别人的仓库，404 | 全改 `YeShenRenAnRan/hermes-seagull` |
| `install.hermes.nousresearch.com` | 域名不存在 | 改 `pip install hermes-agent` |
| CI 每天 merge `NousResearch/hermes-agent` 再 push `main` | 无共同历史，必失败；分支还是 `master` | 换真实自检矩阵 |
| `verify.ps1` 检查乱码字节 | 什么都没验证 | 换 `tools/verify_plugin.py` |

---

## 能力

| 能力 | Hermes 接口 |
|---|---|
| 每轮注入人格协议 + 技能路由表 | `pre_llm_call` → `{"context": ...}` |
| 注册 5 个技能 | `ctx.register_skill()` |
| 纯问候固定回复 | `transform_llm_output` |
| 记录技能加载 | `pre_tool_call` 观察者 |
| 会话状态清理 | `on_session_start/end/finalize` |

注入只进**当轮用户消息**，不动系统提示词 —— Hermes 的设计，为保住 prompt cache。

---

## 技能

| 技能 | 触发 | 交付 |
|---|---|---|
| `seagull-reverse` | 逆向 / 反编译 / 脱壳 / frida | triage → 静态/动态 → patch 点 |
| `seagull-pentest` | 渗透 / 红队 / 越权 / IDOR | recon → 假设矩阵 → 重放脚本 |
| `seagull-exploit` | pwn / ROP / 堆利用 | 崩溃分析 → 原语 → exploit |
| `seagull-game-hack` | 外挂 / ESP / 自瞄 | entity → ViewMatrix → W2S → overlay |
| `seagull-license-security` | 卡密 / 激活 / 签名校验 | 验证入口 → patch-point → harness |

技能名带命名空间：`seagull-armor-break:seagull-reverse`。

---

## 文档

- [QUICKSTART.md](./QUICKSTART.md) — 完整部署流程
- [STRUCTURE.md](./STRUCTURE.md) — 目录结构与维护
- [API_CONFIG.md](./API_CONFIG.md) — 模型 / API 配置
- [GITHUB_GUIDE.md](./GITHUB_GUIDE.md) — 仓库维护
- [DISCLAIMER.md](./DISCLAIMER.md) — 使用条款
- [seagull-armor-break/README.md](./seagull-armor-break/README.md) — 插件技术说明

---

## 自检

```bash
python tools/verify_plugin.py     # 校验 manifest / hook / 技能 / 真实 loader
```

---

## 环境要求

- Hermes Agent **>= 0.19.0**
- Python **3.11+**
- 插件本身零额外依赖

`requirements.txt` 是技能用到的工具链（pwntools / capstone / frida 等），按需装。

---

## 卸载

```bash
hermes plugins remove seagull-armor-break
hermes profile delete seagull      # 若装过 profile
```

---

MIT License
