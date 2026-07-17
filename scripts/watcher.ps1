<#
.SYNOPSIS
  WorkBuddy Skin Watcher - silent background daemon
.DESCRIPTION
  Runs hidden. Every 3 seconds:
    - WorkBuddy not running       -> do nothing
    - WorkBuddy running, CDP up   -> ensure skin injected (idempotent)
    - WorkBuddy running, no CDP   -> relaunch in CDP mode and inject
.PARAMETER AutoStart
  Launch WorkBuddy on startup if not running
.PARAMETER Port
  CDP debug port (default 9223)
#>
param(
  [switch]$AutoStart,
  [int]$Port = 9223
)
$ErrorActionPreference = 'Continue'
$Root = Split-Path -Parent $PSScriptRoot

$LogDir = Join-Path $env:LOCALAPPDATA 'WorkBuddySkinStudio'
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
$LogFile = Join-Path $LogDir 'watcher.log'
function Log($msg) {
  $line = "[$(Get-Date -Format 'HH:mm:ss')] $msg"
  try { Add-Content -Path $LogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue } catch {}
}

function Find-WorkBuddyExe {
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
  foreach ($p in $paths) { if (Test-Path -LiteralPath $p) { return $p } }
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
          if (Test-Path -LiteralPath $cand) { return $cand }
        }
    }
  } catch {}
  return $null
}

function Find-Node {
  $g = Get-Command node -ErrorAction SilentlyContinue
  if ($g) { return $g.Source }
  $homeNode = Join-Path $env:USERPROFILE '.workbuddy\binaries\node\versions'
  if (Test-Path $homeNode) {
    $n = Get-ChildItem $homeNode -Directory | Sort-Object Name -Descending | Select-Object -First 1
    if ($n) {
      $x = Join-Path $n.FullName 'node.exe'
      if (Test-Path -LiteralPath $x) { return $x }
    }
  }
  return $null
}

function Test-CDP([int]$P) {
  try {
    $r = Invoke-RestMethod "http://127.0.0.1:$P/json/list" -TimeoutSec 1
    return [bool]($r | Where-Object { $_.type -eq 'page' -and $_.url -like '*renderer/index.html*' })
  } catch { return $false }
}

$exe = Find-WorkBuddyExe
$node = Find-Node
if (-not $exe -or -not $node) { Log "Cannot find WorkBuddy.exe or node.exe, exiting"; exit 1 }
$cli = Join-Path $Root 'src/cli.mjs'
Log "Watcher started | AutoStart=$AutoStart"

if ($AutoStart) {
  $p = Get-Process WorkBuddy -ErrorAction SilentlyContinue
  if (-not $p) {
    Log "AutoStart: launching WorkBuddy (CDP mode)"
    Start-Process -FilePath $exe -ArgumentList "--remote-debugging-port=$Port"
    Start-Sleep -Seconds 5
  }
}

$cooldownUntil = (Get-Date).AddSeconds(-1)
$restartLock = $false

while ($true) {
  try {
    $proc = Get-Process WorkBuddy -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $proc) { Start-Sleep -Milliseconds 3000; continue }

    $hasCdpArg = $false
    try {
      $wmi = Get-CimInstance Win32_Process -Filter "ProcessId=$($proc.Id)" -ErrorAction SilentlyContinue
      if ($wmi -and $wmi.CommandLine -like '*remote-debugging*') { $hasCdpArg = $true }
    } catch {}

    if ($hasCdpArg -or (Test-CDP $Port)) {
      try { & $node $cli apply --port $Port 2>$null | Out-Null } catch {}
    } else {
      if ((Get-Date) -gt $cooldownUntil -and -not $restartLock) {
        $restartLock = $true
        Log "WorkBuddy running without CDP, relaunching with skin..."
        try {
          Stop-Process -Name WorkBuddy -Force -ErrorAction SilentlyContinue
          Start-Sleep -Seconds 2
          Start-Process -FilePath $exe -ArgumentList "--remote-debugging-port=$Port"
          $deadline = (Get-Date).AddSeconds(25)
          while (-not (Test-CDP $Port)) {
            if ((Get-Date) -ge $deadline) { throw 'CDP timeout' }
            Start-Sleep -Milliseconds 500
          }
          & $node $cli apply --port $Port 2>$null | Out-Null
          Log "Skin injected successfully"
          $cooldownUntil = (Get-Date).AddSeconds(10)
        } catch {
          Log "Relaunch/inject failed: $_"
          $cooldownUntil = (Get-Date).AddSeconds(15)
        }
        $restartLock = $false
      }
    }
  } catch {
    Log "Loop error: $_"
    Start-Sleep -Milliseconds 5000
  }
  Start-Sleep -Milliseconds 3000
}