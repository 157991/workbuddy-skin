<#
.SYNOPSIS
  一键安装 WorkBuddy 换肤版（桌面快捷方式 + 开始菜单 + 开机自启）
.DESCRIPTION
  右键"使用 PowerShell 运行"或在 PowerShell 中执行：
    Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force
    .\install.ps1
.PARAMETER NoAutoStart
  加上此参数则不设置开机自启
#>
[CmdletBinding()]
param(
  [switch]$NoAutoStart
)
$ErrorActionPreference = 'Stop'
$StudioRoot = Split-Path -Parent $PSScriptRoot
$VbsPath = Join-Path $StudioRoot 'scripts\launcher.vbs'
$Ps1Path = Join-Path $StudioRoot 'scripts\launcher.ps1'
$PausePs1 = Join-Path $StudioRoot 'scripts\pause.ps1'
$UninstallPs1 = Join-Path $StudioRoot 'scripts\uninstall.ps1'

$ExePath = Join-Path $env:LOCALAPPDATA 'Programs\WorkBuddy\WorkBuddy.exe'
if (-not (Test-Path $ExePath)) {
  $candidates = @(
    (Join-Path $env:LOCALAPPDATA 'workbuddy\WorkBuddy.exe'),
    (Join-Path $env:ProgramFiles 'WorkBuddy\WorkBuddy.exe')
  )
  foreach ($c in $candidates) { if (Test-Path $c) { $ExePath = $c; break } }
}
if (-not (Test-Path $VbsPath)) { Write-Error "找不到 launcher.vbs，请确认 install.ps1 位于 scripts 目录"; exit 1 }

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  WorkBuddy 换肤版 一键安装" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

try { Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force -ErrorAction SilentlyContinue } catch {}

function New-Shortcut($LinkPath, $TargetPath, $Arguments, $Description, $IconLocation, $WorkDir) {
  $wsh = New-Object -ComObject WScript.Shell
  $lnk = $wsh.CreateShortcut($LinkPath)
  $lnk.TargetPath = $TargetPath
  if ($Arguments) { $lnk.Arguments = $Arguments }
  if ($WorkDir) { $lnk.WorkingDirectory = $WorkDir }
  if ($IconLocation) { $lnk.IconLocation = $IconLocation }
  $lnk.Description = $Description
  $lnk.Save()
  Write-Host ("  [OK] " + $LinkPath) -ForegroundColor Green
}

$icon = if (Test-Path $ExePath) { "$ExePath,0" } else { "" }

$deskLnk = Join-Path $env:USERPROFILE 'Desktop\WorkBuddy 换肤版.lnk'
New-Shortcut $deskLnk 'wscript.exe' "`"$VbsPath`"" 'WorkBuddy 换肤版：双击启动自动带皮肤' $icon $StudioRoot

$startMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\WorkBuddy 换肤版'
New-Item -ItemType Directory -Path $startMenu -Force | Out-Null
$smLnk = Join-Path $startMenu 'WorkBuddy 换肤版.lnk'
New-Shortcut $smLnk 'wscript.exe' "`"$VbsPath`"" 'WorkBuddy 换肤版' $icon $StudioRoot

if (Test-Path $PausePs1) {
  $pauseLnk = Join-Path $startMenu '暂停皮肤（恢复原版）.lnk'
  New-Shortcut $pauseLnk 'powershell.exe' "-NoProfile -ExecutionPolicy Bypass -File `"$PausePs1`"" '暂停皮肤、恢复 WorkBuddy 原版外观' $icon $StudioRoot
}
if (Test-Path $UninstallPs1) {
  $uninstallLnk = Join-Path $startMenu '卸载换肤版.lnk'
  New-Shortcut $uninstallLnk 'powershell.exe' "-NoProfile -ExecutionPolicy Bypass -File `"$UninstallPs1`"" '卸载 WorkBuddy 换肤版' $icon $StudioRoot
}

if (-not $NoAutoStart) {
  $startupDir = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'
  $startupLnk = Join-Path $startupDir 'WorkBuddy 换肤版.lnk'
  New-Shortcut $startupLnk 'wscript.exe' "`"$VbsPath`"" 'WorkBuddy 换肤版（开机自启）' $icon $StudioRoot
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  安装完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  使用方法：" -ForegroundColor Yellow
Write-Host "   1. 双击桌面 [WorkBuddy 换肤版] 启动" -ForegroundColor White
Write-Host "   2. WorkBuddy 右上角出现 🎨 按钮，点击切换主题" -ForegroundColor White
Write-Host "   3. 🎨 菜单里可 [＋ 自定义图片] 上传自己的图做皮肤" -ForegroundColor White
Write-Host "   4. 想还原原版：开始菜单 → WorkBuddy 换肤版 → 暂停皮肤" -ForegroundColor White
Write-Host "   5. 卸载：开始菜单 → 卸载换肤版" -ForegroundColor White
if (-not $NoAutoStart) {
  Write-Host "   6. 已设置开机自启，下次开机自动带皮肤" -ForegroundColor White
}
Write-Host ""
Write-Host "  提示：请从 [WorkBuddy 换肤版] 启动，不要用原版快捷方式" -ForegroundColor DarkGray
Write-Host ""
Read-Host "按回车退出"