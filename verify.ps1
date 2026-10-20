# 海鸥破甲插件自检 (Windows / PowerShell 5.1+)
#
# 调用 tools/verify_plugin.py，校验 plugin.yaml、hook 名、技能 frontmatter，
# 并在本机装了 hermes-agent 时用真实 loader 试加载一次。
#
# 旧版本检查的是 SOUL.md 里的乱码字节和文件存在性，等于什么都没验证。

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

$python = $null
foreach ($candidate in @("python", "python3", "py")) {
    $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
    if ($cmd) { $python = $cmd.Source; break }
}
if (-not $python) {
    Write-Host "[X] 找不到 python，无法自检" -ForegroundColor Red
    exit 1
}

$verifier = Join-Path $RepoRoot "tools\verify_plugin.py"
if (-not (Test-Path $verifier)) {
    Write-Host "[X] 缺 tools\verify_plugin.py" -ForegroundColor Red
    exit 1
}

& $python $verifier --plugin-dir (Join-Path $RepoRoot "seagull-armor-break") @args
exit $LASTEXITCODE
