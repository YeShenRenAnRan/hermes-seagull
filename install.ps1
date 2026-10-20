# 海鸥破甲插件安装脚本 (Windows / PowerShell 5.1+)
#
# 三种安装方式：
#   默认         用 hermes plugins install 装（本地 file:// 源，不需要联网）
#   -Copy        完全跳过 git，直接把插件目录拷进 $HERMES_HOME\plugins\ 再 enable
#   -NoEnable    装但不启用
#
# hermes plugins install 失败时（缺 git、git 被环境限制等）自动退到复制安装。
#
# 不再向 config.yaml 写入 active_profile / profiles.seagull / soul_file 之类的
# 假键（Hermes 没有这些键，写了会被忽略，还可能污染配置）。

param(
    [switch]$NoEnable,
    [switch]$Copy,
    [string]$Dest
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$PluginSrc = Join-Path $RepoRoot "seagull-armor-break"
$PluginName = "seagull-armor-break"
$HermesHome = if ($env:HERMES_HOME) { $env:HERMES_HOME } else { Join-Path $env:USERPROFILE ".hermes" }
if ($Dest) { $HermesHome = $Dest }

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
$StagePlugin = Join-Path $Stage $PluginName
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
    Remove-Item -Recurse -Force $Stage -ErrorAction SilentlyContinue
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

# --- 4a. 直接复制安装（离线路径）----------------------------------------
function Invoke-CopyInstall {
    Write-Step "直接复制安装（不经过 git）..."
    $target = Join-Path (Join-Path $HermesHome "plugins") $PluginName
    if (Test-Path $target) { Remove-Item -Recurse -Force $target }
    New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null
    Copy-Item -Recurse -Force $StagePlugin $target
    Write-Ok "已复制到: $target"

    if ($hermes -and -not $NoEnable) {
        Write-Step "启用插件..."
        & $hermes plugins enable $PluginName
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "已启用"
        } else {
            Write-Warn2 "自动启用失败，手动执行: hermes plugins enable $PluginName"
        }
    } elseif ($NoEnable) {
        Write-Warn2 "按参数要求未启用。启用命令: hermes plugins enable $PluginName"
    } else {
        Write-Warn2 "没找到 hermes 命令，无法自动启用。"
        Write-Host "  在 $HermesHome\config.yaml 的 plugins.enabled 里加上 $PluginName" -ForegroundColor Gray
        Write-Host "  或装好 Hermes 后执行: hermes plugins enable $PluginName" -ForegroundColor Gray
    }
}

# --- 4b. 走 Hermes 官方安装 ---------------------------------------------
if ($Copy -or -not $hermes) {
    if ($Copy) { Write-Step "指定了 -Copy，跳过 hermes plugins install" }
    if (-not $hermes) { Write-Warn2 "没找到 hermes 命令" }
    Invoke-CopyInstall
} else {
    Write-Ok "hermes: $hermes"
    Write-Step "安装插件（本地 file:// 源，不需要联网）..."
    # 本地目录走 file:// 形式，Hermes 会把它当 git 源 clone 到 plugins 目录
    $stageUrl = "file:///" + ($StagePlugin -replace '\\', '/')
    $installArgs = @("plugins", "install", $stageUrl)
    if (-not $NoEnable) { $installArgs += "--enable" } else { $installArgs += "--no-enable" }
    & $hermes @installArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Warn2 "hermes plugins install 没成功，自动改用复制方式"
        Invoke-CopyInstall
    } else {
        Write-Ok "插件已安装"
    }
}

# --- 5. 装完核对 --------------------------------------------------------
if ($hermes) {
    Write-Host ""
    Write-Step "核对安装结果..."
    $list = & $hermes plugins list 2>&1 | Out-String
    if ($list -match [regex]::Escape($PluginName)) {
        ($list -split "`n" | Where-Object { $_ -match [regex]::Escape($PluginName) }) | ForEach-Object { Write-Host "  $_" }
        Write-Ok "$PluginName 已在插件列表中"
    } else {
        Write-Warn2 "插件列表里没看到 $PluginName，检查上面输出"
    }
}

Remove-Item -Recurse -Force $Stage -ErrorAction SilentlyContinue

# --- 6. 提示：人格文件怎么装 --------------------------------------------
Write-Host ""
Write-Step "想要海鸥人格（SOUL.md）也生效，另外装 profile 发行版"
Write-Host "  在本仓库目录里执行（本地路径，不需要联网）：" -ForegroundColor Gray
Write-Host "    hermes profile install . --name seagull --force" -ForegroundColor Gray
Write-Host "    hermes profile use seagull" -ForegroundColor Gray
Write-Host "  或者从 GitHub 装：" -ForegroundColor Gray
Write-Host "    hermes profile install YeShenRenAnRan/hermes-seagull --name seagull --force" -ForegroundColor Gray
Write-Host "  说明：AGENTS.md 只从工作目录加载，把仓库里的 AGENTS.md 放到你常开工的目录即可。" -ForegroundColor Gray

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Ok "安装完成"
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "验证：" -ForegroundColor Yellow
Write-Host "  hermes plugins list          # $PluginName 应为 enabled"
Write-Host "  python tools\verify_plugin.py --no-hermes"
Write-Host "  hermes chat                  # 输入 '在吗'"
Write-Host "  预期: 海鸥在线，你要整点薯条吗？"
Write-Host ""
Write-Host "技能触发：" -ForegroundColor Yellow
Write-Host "  逆向 / 渗透 / pwn / 外挂 / 卡密"
Write-Host ""
