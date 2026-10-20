# 仓库维护指南

本仓库已有远端：<https://github.com/YeShenRenAnRan/hermes-seagull>（默认分支 `master`）。

---

## 日常提交

```bash
git status
git add -A
git commit -m "描述改动"
git push
```

已有本地克隆时不用重建 remote：

```bash
git remote -v
# origin  https://github.com/YeShenRenAnRan/hermes-seagull.git (fetch)
# origin  https://github.com/YeShenRenAnRan/hermes-seagull.git (push)
```

---

## 推送认证

### 方式一：HTTPS + Credential Manager（推荐）

```bash
git config --global credential.helper manager
git push          # 弹出浏览器登录一次，之后自动记住
```

### 方式二：SSH

```bash
ssh-keygen -t ed25519 -C "your@email"
# 把 ~/.ssh/id_ed25519.pub 内容贴到 https://github.com/settings/keys
ssh -T git@github.com
git remote set-url origin git@github.com:YeShenRenAnRan/hermes-seagull.git
```

> Windows 上如果 `ssh` 报 `UNPROTECTED PRIVATE KEY FILE` / `Bad permissions`，
> 说明私钥权限太开放。在**当前用户**下收紧：
>
> ```powershell
> icacls "$env:USERPROFILE\.ssh\id_ed25519" /inheritance:r
> icacls "$env:USERPROFILE\.ssh\id_ed25519" /grant:r "$($env:USERNAME):(R)"
> ```

### 方式三：Personal Access Token

1. <https://github.com/settings/tokens> → Generate new token (classic)
2. 勾 `repo` 权限
3. 推送时用户名填 GitHub 用户名，密码位置粘贴 token

**永远不要把 token 写进文件提交上库**。GitHub 会直接吊销检测到的 token。

---

## 改完插件要做的自检

```bash
python tools/verify_plugin.py
```

会校验：

- `plugin.yaml` 的字段和 `provides_hooks` 是否都是 Hermes 真实存在的 hook
- `__init__.py` 语法、是否有 `register(ctx)`、注册的 hook 名是否合法
- `skills/*/SKILL.md` 的 YAML frontmatter
- 用本机 Hermes 的真实 loader 试加载：hook 数、技能数、注入字符数、问候语
- 若 PATH 里有 `hermes`，再跑一次 `hermes plugins list`

CI（`.github/workflows/sync-workflow.yml`）会在 Ubuntu + Windows × Python 3.11/3.13 上跑同一套检查。

---

## 发布新版本

1. 改 `seagull-armor-break/plugin.yaml` 的 `version`
2. 改 `distribution.yaml` 的 `version`（如果 profile 发行版也变了）
3. 在 `README.md` 记录改动
4. `git add -A && git commit -m "release: v1.1.0" && git push`
5. 打标签：

```bash
git tag -a v1.1.0 -m "seagull-armor-break v1.1.0"
git push origin v1.1.0
```

6. GitHub → Releases → Draft a new release → 选标签 → Publish

---

## 别人怎么装

```bash
# 插件
hermes plugins install YeShenRenAnRan/hermes-seagull/seagull-armor-break --enable

# profile（人格 + 磁盘上的技能）
hermes profile install YeShenRenAnRan/hermes-seagull --name seagull --force
```

安装机制说明：

- 插件安装走 `git clone --depth 1 <url>`，`owner/repo/subdir` 或
  `https://github.com/owner/repo/tree/master/subdir` 都会被解析成"只取子目录"
- profile 安装要求仓库根有 `distribution.yaml`

---

## 已知坑

| 现象 | 原因 | 处理 |
|---|---|---|
| 装了插件但完全不生效 | 用了不存在的 hook 名 | 跑 `python tools/verify_plugin.py` |
| 技能出现在索引里但是空的 | `SKILL.md` 缺 frontmatter | 补 `name` / `description` |
| `hermes profile install` 报错 | 根目录缺 `distribution.yaml` | 本仓库已有 |
| 推送 `origin main` 失败 | 本仓库默认分支是 `master` | 用 `master`，或先 `git branch -M main` 并改默认分支 |
