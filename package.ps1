# 打包发布脚本 (Windows / PowerShell 5.1+)
#
# 先自检，再打 zip，输出 SHA256。
# 打出来的包同时包含插件（seagull-armor-break/）和 profile 发行版（SOUL.md / skills/）。

param(
    [string]$OutDir = "."
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $RepoRoot

$version = "1.0.0"
$pluginYaml = Join-Path $RepoRoot "seagull-armor-break\plugin.yaml"
if (Test-Path $pluginYaml) {
    $m = Select-String -Path $pluginYaml -Pattern '^version:\s*(.+)$' | Select-Object -First 1
    if ($m) { $version = $m.Matches[0].Groups[1].Value.Trim() }
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Seagull Package v$version" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/4] 自检..." -ForegroundColor Yellow
& (Join-Path $RepoRoot "verify.ps1")
if ($LASTEXITCODE -ne 0) {
    Write-Host "[X] 自检失败，终止打包" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[2/4] 组装..." -ForegroundColor Yellow
$name = "seagull-armor-break-v$version"
$stage = Join-Path ([System.IO.Path]::GetTempPath()) $name
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Force -Path $stage | Out-Null

# profile 发行版部分
foreach ($f in @("SOUL.md", "AGENTS.md", "distribution.yaml", "LICENSE",
                 "README.md", "README.zh-CN.md", "QUICKSTART.md",
                 "STRUCTURE.md", "API_CONFIG.md", "GITHUB_GUIDE.md",
                 "DISCLAIMER.md", "requirements.txt",
                 "install.ps1", "install.sh", "verify.ps1", "verify.sh")) {
    $src = Join-Path $RepoRoot $f
    if (Test-Path $src) { Copy-Item $src $stage }
}
Copy-Item -Recurse (Join-Path $RepoRoot "skills") (Join-Path $stage "skills")
Copy-Item -Recurse (Join-Path $RepoRoot "tools") (Join-Path $stage "tools")

# 插件部分（确保技能与根目录一致）
$stagePlugin = Join-Path $stage "seagull-armor-break"
Copy-Item -Recurse (Join-Path $RepoRoot "seagull-armor-break") $stagePlugin
Remove-Item -Recurse -Force (Join-Path $stagePlugin "skills") -ErrorAction SilentlyContinue
Copy-Item -Recurse (Join-Path $RepoRoot "skills") (Join-Path $stagePlugin "skills")
Remove-Item -Recurse -Force (Join-Path $stagePlugin "__pycache__") -ErrorAction SilentlyContinue
Copy-Item -Force (Join-Path $RepoRoot "AGENTS.md") (Join-Path $stagePlugin "AGENTS.md")

Write-Host ""
Write-Host "[3/4] 压缩..." -ForegroundColor Yellow
$archive = Join-Path (Resolve-Path $OutDir) "$name.zip"
Compress-Archive -Path "$stage\*" -DestinationPath $archive -Force
Remove-Item $stage -Recurse -Force

Write-Host ""
Write-Host "[4/4] 校验和..." -ForegroundColor Yellow
$hash = (Get-FileHash $archive -Algorithm SHA256).Hash

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  打包完成" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "文件:   $archive"
Write-Host "大小:   $([math]::Round((Get-Item $archive).Length / 1KB, 2)) KB"
Write-Host "SHA256: $hash" -ForegroundColor Gray
Write-Host ""
