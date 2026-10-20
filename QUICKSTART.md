# 海鸥破甲插件 - 快速部署

> Hermes Agent 原生插件，一条命令装完。

---

## 步骤 1：装 Hermes Agent（已装跳过）

```bash
python -m pip install hermes-agent
hermes --version          # 需要 >= 0.19.0
```

> 官方安装方式见 <https://hermes-agent.nousresearch.com/docs/>

---

## 步骤 2：装插件

```bash
hermes plugins install YeShenRenAnRan/hermes-seagull/seagull-armor-break --enable
```

> 注意最后的 `/seagull-armor-break` —— 插件在仓库子目录里，
> Hermes 支持 `owner/repo/subdir` 这种写法，会自动只取那个子目录。

确认：

```bash
hermes plugins list
# seagull-armor-break   enabled   1.0.0   ...   user
```

没启用的话：

```bash
hermes plugins enable seagull-armor-break
```

---

## 步骤 3：配置模型 / API

```bash
hermes login                 # 交互式登录（推荐）
# 或
hermes model                 # 选 provider 与模型
```

手动改配置文件：

| 平台 | 路径 |
|---|---|
| Windows | `%LOCALAPPDATA%\hermes\config.yaml` |
| Linux / macOS | `~/.hermes/config.yaml` |

也可以直接看路径：

```bash
hermes config path
hermes config edit
```

> 详细配置（OpenAI / DeepSeek / 中转 / Ollama）：[API_CONFIG.md](./API_CONFIG.md)

---

## 步骤 4：启动

```bash
hermes chat
```

发 **在吗**：

```
海鸥在线，你要整点薯条吗？
```

看到这行就说明插件真的加载了。

---

## 步骤 5（可选）：连人格一起装

插件负责技能与路由；**人格（SOUL.md）走 profile 发行版**：

```bash
hermes profile install YeShenRenAnRan/hermes-seagull --name seagull --force
hermes profile use seagull
```

`AGENTS.md` 是 Hermes 的**工作目录上下文文件**，只从当前目录加载。
把仓库里的 `AGENTS.md` 放到你常开工的目录即可；不放也行，插件自带协议块。

---

## 常用命令

| 命令 | 说明 |
|---|---|
| `hermes chat` | 启动会话 |
| `hermes plugins list` | 看插件状态 |
| `hermes plugins update seagull-armor-break` | 拉取插件更新 |
| `hermes plugins remove seagull-armor-break` | 卸载插件 |
| `在吗` | 固定问候激活 |
| `逆向` / `渗透` / `pwn` / `外挂` / `卡密` | 触发对应技能 |

---

## 更新

```bash
# 更新插件（重新拉取仓库子目录）
hermes plugins update seagull-armor-break

# 或强制重装
hermes plugins install YeShenRenAnRan/hermes-seagull/seagull-armor-break --force --enable

# 更新 profile 发行版
hermes profile update seagull
```

---

## 排错

### Q1: `hermes: command not found`
Hermes 没装或不在 PATH。`python -m pip install hermes-agent` 后重开终端。

### Q2: `hermes plugins list` 里没有 seagull-armor-break
看安装输出有没有报错；手动装：

```bash
git clone https://github.com/YeShenRenAnRan/hermes-seagull
hermes plugins install ./hermes-seagull/seagull-armor-break --enable
```

### Q3: 装了但发"在吗"没反应
按顺序查：

```bash
hermes plugins list                       # 状态是否 enabled
python tools/verify_plugin.py             # 插件本身是否健康
hermes --dev chat                         # 打开插件调试日志
```

### Q4: 技能能触发但 `skill_view` 找不到
技能名是带命名空间的：`seagull-armor-break:seagull-reverse`，不是 `seagull-reverse`。

### Q5: 怎么彻底卸载
```bash
hermes plugins remove seagull-armor-break
hermes profile delete seagull            # 如果装过 profile
```

---

## 下一步

- [README.md](./README.md) — 完整说明与修复记录
- [STRUCTURE.md](./STRUCTURE.md) — 目录结构与维护
- [API_CONFIG.md](./API_CONFIG.md) — API 配置
- [DISCLAIMER.md](./DISCLAIMER.md) — 使用条款
