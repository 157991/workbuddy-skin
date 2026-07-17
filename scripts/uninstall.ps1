<#
.SYNOPSIS
  Uninstall WorkBuddy Skin Studio
.DESCRIPTION
  1. Stop background watcher
  2. Remove skin from running WorkBuddy
  3. Remove desktop / Start Menu / Startup shortcuts
  4. Clear cache/logs
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Continue'
$StudioRoot = Split-Path -Parent $PSScriptRoot

Write-Host "========================================" -ForegroundColor Yellow
Write-Host "  WorkBuddy 换肤版 卸载" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""

# 1) Stop watcher
Write-Host "[1/4] 停止后台守护进程..." -ForegroundColor Cyan
$StopPs1 = Join-Path $StudioRoot 'scripts\stop-watcher.ps1'
if (Test-Path $StopPs1) {
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $StopPs1 -NoPause 2>$null
} else {
  Get-Process powershell -ErrorAction SilentlyContinue | ForEach-Object {
    try {
      $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)" -EA SilentlyContinue).CommandLine
      if ($cmd -like '*watcher.ps1*') { Stop-Process -Id $_.Id -Force -EA SilentlyContinue }
    } catch {}
  }
}

# 2) Restore skin
$node = $null
$g = Get-Command node -ErrorAction SilentlyContinue
if ($g) { $node = $g.Source } else {
  $homeNode = Join-Path $env:USERPROFILE '.workbuddy\binaries\node\versions'
  if (Test-Path $homeNode) {
    $n = Get-ChildItem $homeNode -Directory | Sort-Object Name -Descending | Select -First 1
    if ($n) { $x = Join-Path $n.FullName 'node.exe'; if (Test-Path $x) { $node = $x } }
  }
}
Write-Host "[2/4] 恢复WorkBuddy原版外观..." -ForegroundColor Cyan
if ($node) {
  & $node (Join-Path $StudioRoot 'src/cli.mjs') pause --port 9223 2>$null
}

function Remove-IfExists($p) {
  if (Test-Path $p) {
    Remove-Item $p -Force -ErrorAction SilentlyContinue
    Write-Host ("  [删除] " + $p) -ForegroundColor Gray
  }
}

# 3) Shortcuts
Write-Host "[3/4] 删除快捷方式..." -ForegroundColor Cyan
Remove-IfExists (Join-Path $env:USERPROFILE 'Desktop\WorkBuddy 换肤版.lnk')
$sm = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\WorkBuddy 换肤版'
if (Test-Path $sm) { Remove-Item $sm -Recurse -Force; Write-Host "  [删除] 开始菜单文件夹" -ForegroundColor Gray }
Remove-IfExists (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup\WorkBuddy换肤守护进程.lnk')

# 4) Cache
Write-Host "[4/4] 清理缓存..." -ForegroundColor Cyan
$logDir = Join-Path $env:LOCALAPPDATA 'WorkBuddySkinStudio'
if (Test-Path $logDir) { Remove-Item $logDir -Recurse -Force -EA SilentlyContinue; Write-Host "  [删除] 日志缓存" -ForegroundColor Gray }

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  卸载完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  - 后台守护已停止" -ForegroundColor White
Write-Host "  - 皮肤已移除，WorkBuddy恢复原版外观" -ForegroundColor White
Write-Host "  - 所有快捷方式和开机自启已清理" -ForegroundColor White
Write-Host "  - 解压的文件夹可手动删除" -ForegroundColor DarkGray
Write-Host ""
Read-Host "按回车退出"