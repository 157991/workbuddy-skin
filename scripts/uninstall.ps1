<#
.SYNOPSIS
  卸载 WorkBuddy 换肤版
.DESCRIPTION
  移除桌面/开始菜单/开机自启快捷方式，并恢复原版 WorkBuddy
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Continue'
$StudioRoot = Split-Path -Parent $PSScriptRoot

Write-Host "========================================" -ForegroundColor Yellow
Write-Host "  WorkBuddy 换肤版 卸载程序" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""

function Remove-IfExists($p) {
  if (Test-Path $p) {
    Remove-Item $p -Force -ErrorAction SilentlyContinue
    Write-Host ("  [移除] " + $p) -ForegroundColor Gray
  }
}

Remove-IfExists (Join-Path $env:USERPROFILE 'Desktop\WorkBuddy 换肤版.lnk')

$sm = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\WorkBuddy 换肤版'
if (Test-Path $sm) {
  Remove-Item $sm -Recurse -Force
  Write-Host "  [移除] 开始菜单文件夹" -ForegroundColor Gray
}

Remove-IfExists (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup\WorkBuddy 换肤版.lnk')

$node = $null
$g = Get-Command node -ErrorAction SilentlyContinue
if ($g) { $node = $g.Source } else {
  $homeNode = Join-Path $env:USERPROFILE '.workbuddy\binaries\node\versions'
  if (Test-Path $homeNode) {
    $n = Get-ChildItem $homeNode -Directory | Sort-Object Name -Descending | Select-Object -First 1
    if ($n) { $x = Join-Path $n.FullName 'node.exe'; if (Test-Path $x) { $node = $x } }
  }
}
if ($node) {
  Write-Host "  正在还原 WorkBuddy 原版外观..." -ForegroundColor Gray
  & $node (Join-Path $StudioRoot 'src/cli.mjs') pause --port 9223 2>$null
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  卸载完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  - 皮肤注入已移除" -ForegroundColor White
Write-Host "  - 快捷方式和开机自启已清理" -ForegroundColor White
Write-Host "  - WorkBuddy 下次启动将是原版外观" -ForegroundColor White
Write-Host "  - 本文件夹可手动删除" -ForegroundColor DarkGray
Write-Host ""
Read-Host "按回车退出"