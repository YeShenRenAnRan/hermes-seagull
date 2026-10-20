# 海鸥破甲插件安装脚本 (Windows / PowerShell 5.1+)
#
# 做两件事：
#   1. 把 seagull-armor-break/ 组装成一个完整插件目录（含 skills/ 与 AGENTS.md）
#   2. 用 Hermes 官方命令安装并启用它
#
# 不再向 config.yaml 写入 active_profile / profiles.seagull / soul_file 之类的
# 假键（Hermes 没有这些键，写了会被忽略，还可能污染配置）。

param(
    [switch]$NoEnable
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$PluginSrc = Join-Path $RepoRoot "seagull-armor-break"

function Write-Step($msg) { Write-Host "[*] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Warn2($msg){ Write-Host "[!] $msg" -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host "[X] $msg" -ForegroundColor Red }

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  海鸥破甲插件 - 安装" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $PluginSrc)) {
    Write-Err "找不到插件目录: $PluginSrc"
    exit 1
}

# --- 1. 组装完整插件目录 ------------------------------------------------
Write-Step "组装插件目录..."
$Stage = Join-Path ([System.IO.Path]::GetTempPath()) ("seagull-stage-" + [Guid]::NewGuid().ToString("N"))
$StagePlugin = Join-Path $Stage "seagull-armor-break"
New-Item -ItemType Directory -Force -Path $StagePlugin | Out-Null
Copy-Item -Recurse -Force "$PluginSrc\*" $StagePlugin

# 仓库根目录的 skills/ 是规范源；插件目录里的副本以根目录为准重新同步
if (Test-Path (Join-Path $RepoRoot "skills")) {
    Remove-Item -Recurse -Force (Join-Path $StagePlugin "skills") -ErrorAction SilentlyContinue
    Copy-Item -Recurse -Force (Join-Path $RepoRoot "skills") (Join-Path $StagePlugin "skills")
}

# AGENTS.md 作为可选补充协议一起带上
if (Test-Path (Join-Path $RepoRoot "AGENTS.md")) {
    Copy-Item -Force (Join-Path $RepoRoot "AGENTS.md") (Join-Path $StagePlugin "AGENTS.md")
}
Remove-Item -Recurse -Force (Join-Path $StagePlugin "__pycache__") -ErrorAction SilentlyContinue
Write-Ok "已组装: $StagePlugin"

# --- 2. 校验技能文件 ----------------------------------------------------
Write-Step "校验 SKILL.md..."
$skillDirs = Get-ChildItem (Join-Path $StagePlugin "skills") -Directory -ErrorAction SilentlyContinue
if (-not $skillDirs) {
    Write-Err "skills/ 为空，插件装了也没有技能可用"
    exit 1
}
$bad = 0
foreach ($d in $skillDirs) {
    $md = Join-Path $d.FullName "SKILL.md"
    if (-not (Test-Path $md)) {
        Write-Warn2 "$($d.Name): 缺 SKILL.md"
        $bad++
        continue
    }
    $head = (Get-Content $md -TotalCount 1 -Encoding UTF8)
    if ($head -ne "---") {
        Write-Warn2 "$($d.Name): SKILL.md 缺 YAML frontmatter（name/description）"
        $bad++
    } else {
        Write-Ok "$($d.Name)/SKILL.md"
    }
}
if ($bad -gt 0) { Write-Warn2 "$bad 个技能有问题，Hermes 仍可加载但索引不完整" }

# --- 3. 找 hermes 命令 --------------------------------------------------
Write-Step "查找 hermes 命令..."
$hermes = $null
$cmd = Get-Command hermes -ErrorAction SilentlyContinue
if ($cmd) { $hermes = $cmd.Source }
if (-not $hermes) {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "hermes\bin\hermes.exe"),
        (Join-Path $env:USERPROFILE ".local\bin\hermes.exe"),
        (Join-Path $env:USERPROFILE ".local\bin\hermes")
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { $hermes = $c; break }
    }
}

if (-not $hermes) {
    Write-Warn2 "没找到 hermes 命令，改为直接复制到插件目录"
    $HermesHome = if ($env:HERMES_HOME) { $env:HERMES_HOME } else { Join-Path $env:USERPROFILE ".hermes" }
    $dest = Join-Path $HermesHome "plugins\seagull-armor-break"
    if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
    New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
    Copy-Item -Recurse -Force $StagePlugin $dest
    Write-Ok "已复制到: $dest"
    Write-Host ""
    Write-Warn2 "还需要启用：在 config.yaml 的 plugins.enabled 里加上 seagull-armor-break"
    Write-Host "  notepad `"$HermesHome\config.yaml`"" -ForegroundColor Gray
    Write-Host "或装好 Hermes 后运行：hermes plugins enable seagull-armor-break" -ForegroundColor Gray
} else {
    Write-Ok "hermes: $hermes"
    Write-Step "安装插件..."
    # 本地目录走 file:// 形式，Hermes 会把它当 git 源 clone 到 ~/.hermes/plugins/
    $stageUrl = "file:///" + ($StagePlugin -replace '\\', '/')
    $installArgs = @("plugins", "install", $stageUrl)
    if (-not $NoEnable) { $installArgs += "--enable" } else { $installArgs += "--no-enable" }
    & $hermes @installArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Err "hermes plugins install 失败（退出码 $LASTEXITCODE）"
        Remove-Item -Recurse -Force $Stage -ErrorAction SilentlyContinue
        exit 1
    }
    Write-Ok "插件已安装"
}

Remove-Item -Recurse -Force $Stage -ErrorAction SilentlyContinue

# --- 4. 提示：人格文件怎么装 --------------------------------------------
Write-Host ""
Write-Step "想要海鸥人格（SOUL.md）也生效，另外装 profile 发行版"
Write-Host "  hermes profile install YeShenRenAnRan/hermes-seagull --name seagull --force" -ForegroundColor Gray
Write-Host "  hermes profile use seagull" -ForegroundColor Gray
Write-Host "  说明：AGENTS.md 只从工作目录加载，把仓库里的 AGENTS.md 放到你常开工的目录即可。" -ForegroundColor Gray

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Ok "安装完成"
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "验证：" -ForegroundColor Yellow
Write-Host "  hermes plugins list          # seagull-armor-break 应为 enabled"
Write-Host "  hermes chat                  # 输入 '在吗'"
Write-Host "  预期: 海鸥在线，你要整点薯条吗？"
Write-Host ""
Write-Host "技能触发：" -ForegroundColor Yellow
Write-Host "  逆向 / 渗透 / pwn / 外挂 / 卡密"
Write-Host ""
