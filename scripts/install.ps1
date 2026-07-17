<#
.SYNOPSIS
  One-click installer for WorkBuddy Skin Studio
.DESCRIPTION
  1. Sets PowerShell execution policy
  2. Creates desktop shortcut "WorkBuddy 换肤版"
  3. Creates Start Menu folder (launch / pause / uninstall)
  4. Installs background watcher to Startup (auto-start with Windows)
  5. Starts the watcher immediately - skin applies automatically whenever WorkBuddy launches
.PARAMETER NoAutoStart
  Do not install the auto-start watcher
#>
[CmdletBinding()]
param(
  [switch]$NoAutoStart
)
$ErrorActionPreference = 'Stop'
$StudioRoot = Split-Path -Parent $PSScriptRoot

$VbsAutoPath    = Join-Path $StudioRoot 'scripts\watcher-autostart.vbs'
$LauncherVbsPath= Join-Path $StudioRoot 'scripts\launcher.vbs'
$StopPs1        = Join-Path $StudioRoot 'scripts\stop-watcher.ps1'
$PausePs1       = Join-Path $StudioRoot 'scripts\pause.ps1'
$UninstallPs1   = Join-Path $StudioRoot 'scripts\uninstall.ps1'
$WatcherVbs     = Join-Path $StudioRoot 'scripts\watcher.vbs'

# Locate WorkBuddy.exe
$ExePath = $null
$paths = @(
  (Join-Path $env:LOCALAPPDATA 'Programs\WorkBuddy\WorkBuddy.exe'),
  (Join-Path $env:LOCALAPPDATA 'Programs\workbuddy\WorkBuddy.exe'),
  (Join-Path $env:LOCALAPPDATA 'workbuddy\WorkBuddy.exe'),
  (Join-Path $env:ProgramFiles 'WorkBuddy\WorkBuddy.exe'),
  (Join-Path $env:ProgramFiles 'workbuddy\WorkBuddy.exe')
)
$pfx86 = ${env:ProgramFiles(x86)}
if ($pfx86) {
  $paths += (Join-Path $pfx86 'WorkBuddy\WorkBuddy.exe')
  $paths += (Join-Path $pfx86 'workbuddy\WorkBuddy.exe')
}
foreach ($p in $paths) { if (Test-Path -LiteralPath $p) { $ExePath = $p; break } }
if (-not $ExePath) {
  try {
    $regKeys = @(
      'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
      'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
      'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    foreach ($k in $regKeys) {
      Get-ItemProperty $k -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like '*WorkBuddy*' -and $_.InstallLocation } |
        ForEach-Object {
          $cand = Join-Path $_.InstallLocation 'WorkBuddy.exe'
          if (Test-Path -LiteralPath $cand) { $ExePath = $cand }
        }
    }
  } catch {}
}
if (-not $ExePath) { Write-Error 'WorkBuddy.exe not found. Please install WorkBuddy first.'; exit 1 }
if (-not (Test-Path $VbsAutoPath)) { Write-Error 'Missing scripts. Please keep the entire extracted folder intact.'; exit 1 }

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  WorkBuddy 换肤版 一键安装" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

try { Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force -ErrorAction SilentlyContinue } catch {}

# Stop any existing watcher
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $StopPs1 -NoPause 2>$null
Start-Sleep -Milliseconds 500

function New-Shortcut($LinkPath, $Target, $Arguments, $Description, $Icon, $WorkDir) {
  $wsh = New-Object -ComObject WScript.Shell
  $lnk = $wsh.CreateShortcut($LinkPath)
  $lnk.TargetPath = $Target
  if ($Arguments) { $lnk.Arguments = $Arguments }
  if ($WorkDir) { $lnk.WorkingDirectory = $WorkDir }
  if ($Icon) { $lnk.IconLocation = $Icon }
  $lnk.Description = $Description
  $lnk.Save()
  Write-Host ("  [OK] " + $LinkPath) -ForegroundColor Green
}

$icon = "$ExePath,0"

# Desktop shortcut (one-click launcher)
$deskLnk = Join-Path $env:USERPROFILE 'Desktop\WorkBuddy 换肤版.lnk'
New-Shortcut $deskLnk 'wscript.exe' "`"$LauncherVbsPath`"" 'WorkBuddy 换肤版 - auto-skin on launch' $icon $StudioRoot

# Start Menu
$sm = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\WorkBuddy 换肤版'
New-Item -ItemType Directory -Path $sm -Force | Out-Null
New-Shortcut (Join-Path $sm 'WorkBuddy 换肤版.lnk') 'wscript.exe' "`"$LauncherVbsPath`"" 'WorkBuddy Skin Studio' $icon $StudioRoot
if (Test-Path $PausePs1) {
  New-Shortcut (Join-Path $sm '暂停皮肤（恢复原版）.lnk') 'powershell.exe' "-NoProfile -ExecutionPolicy Bypass -File `"$PausePs1`"" 'Pause skin (restore default)' $icon $StudioRoot
}
New-Shortcut (Join-Path $sm '停止后台守护.lnk') 'powershell.exe' "-NoProfile -ExecutionPolicy Bypass -File `"$StopPs1`"" 'Stop background watcher' $icon $StudioRoot
New-Shortcut (Join-Path $sm '卸载换肤版.lnk') 'powershell.exe' "-NoProfile -ExecutionPolicy Bypass -File `"$UninstallPs1`"" 'Uninstall WorkBuddy Skin Studio' $icon $StudioRoot

# Startup folder - watcher (with AutoStart so it launches WorkBuddy on boot)
if (-not $NoAutoStart) {
  $startup = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'
  $startupLnk = Join-Path $startup 'WorkBuddy换肤守护进程.lnk'
  New-Shortcut $startupLnk 'wscript.exe' "`"$VbsAutoPath`"" 'WorkBuddy Skin watcher (auto-start)' $icon $StudioRoot
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  安装完成！正在启动守护进程..." -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

# Start watcher now (with AutoStart)
Start-Process wscript.exe -ArgumentList "`"$VbsAutoPath`"" -WindowStyle Hidden

Write-Host ""
Write-Host "  使用说明：" -ForegroundColor Yellow
Write-Host "   1. 双击桌面 [WorkBuddy 换肤版] 启动带皮肤的WorkBuddy" -ForegroundColor White
Write-Host "   2. 以后无论从哪里打开WorkBuddy（原版图标/任务栏等），皮肤都会自动加载" -ForegroundColor White
Write-Host "   3. 右上角点 🎨 按钮自由切换主题 / 上传自定义图片" -ForegroundColor White
Write-Host "   4. 开始菜单提供暂停/停止/卸载入口" -ForegroundColor White
Write-Host "   5. 已设置开机自启，电脑重启后皮肤也会自动加载" -ForegroundColor White
Write-Host ""
Write-Host "  首次启动可能会闪一下重启（切换到调试模式），之后无感" -ForegroundColor DarkGray
Write-Host ""
Start-Sleep -Seconds 5