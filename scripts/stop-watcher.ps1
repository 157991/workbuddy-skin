<#
.SYNOPSIS
  Stop the WorkBuddy skin watcher daemon
.PARAMETER NoPause
  Do not pause (used internally by uninstall)
#>
param([switch]$NoPause)
$ErrorActionPreference = 'Continue'
$count = 0
Get-Process powershell -ErrorAction SilentlyContinue | ForEach-Object {
  try {
    $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)" -ErrorAction SilentlyContinue).CommandLine
    if ($cmdLine -and $cmdLine -like '*watcher.ps1*') {
      Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
      Write-Host "Stopped watcher (PID: $($_.Id))"
      $count++
    }
  } catch {}
}
if ($count -eq 0) { Write-Host "Watcher is not running." }
if (-not $NoPause) { Write-Host ""; Read-Host "Press Enter to exit" }
