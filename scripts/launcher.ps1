<#
.SYNOPSIS
  WorkBuddy 换肤启动器 - 启动 WorkBuddy 并自动注入皮肤
.DESCRIPTION
  1. 查找 WorkBuddy.exe 与 node.exe
  2. 若 CDP 端口未就绪，重启 WorkBuddy 为调试模式
  3. 等待就绪后自动 apply 皮肤
.PARAMETER Theme
  指定主题 id，例如 miku-light / genshin-night。留空则使用默认/上次主题
.PARAMETER Port
  CDP 调试端口，默认 9223
#>
[CmdletBinding()]
param(
  [string]$Theme = "",
  [int]$Port = 9223
)
$ErrorActionPreference = 'Continue'
$Root = Split-Path -Parent $PSScriptRoot

function Find-WorkBuddyExe {
  $candidates = @(
    (Join-Path $env:LOCALAPPDATA 'Programs\WorkBuddy\WorkBuddy.exe'),
    (Join-Path $env:LOCALAPPDATA 'workbuddy\WorkBuddy.exe'),
    (Join-Path $env:ProgramFiles 'WorkBuddy\WorkBuddy.exe')
  )
  if (${env:ProgramFiles(x86)}) { $candidates += (Join-Path ${env:ProgramFiles(x86)} 'WorkBuddy\WorkBuddy.exe') }
  foreach ($c in $candidates) { if (Test-Path -LiteralPath $c) { return $c } }
  try {
    $keys = @(
      'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
      'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
      'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    foreach ($k in $keys) {
      Get-ItemProperty $k -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like '*WorkBuddy*' -and $_.InstallLocation } |
        ForEach-Object {
          $p = Join-Path $_.InstallLocation 'WorkBuddy.exe'
          if (Test-Path -LiteralPath $p) { return $p }
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
      $exe = Join-Path $n.FullName 'node.exe'
      if (Test-Path -LiteralPath $exe) { return $exe }
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
if (-not $exe) { Write-Host '[错误] 未找到 WorkBuddy.exe，请先安装 WorkBuddy 桌面版'; exit 1 }
$node = Find-Node
if (-not $node) { Write-Host '[错误] 未找到 node，请先安装 Node.js 或 WorkBuddy'; exit 1 }

Write-Host "=== WorkBuddy 换肤启动器 ==="
Write-Host "WorkBuddy : $exe"
Write-Host "Node      : $node"
Write-Host ""

if (Test-CDP $Port) {
  Write-Host "CDP 已就绪，注入皮肤..."
} else {
  $proc = Get-Process WorkBuddy -ErrorAction SilentlyContinue
  if ($proc) {
    Write-Host "WorkBuddy 正在运行，重启以启用换肤模式..."
    Stop-Process -Name WorkBuddy -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
  } else {
    Write-Host "正在启动 WorkBuddy..."
  }
  Start-Process -FilePath $exe -ArgumentList "--remote-debugging-port=$Port"
  $deadline = (Get-Date).AddSeconds(30)
  while (-not (Test-CDP $Port)) {
    if ((Get-Date) -ge $deadline) { Write-Host '[错误] CDP 启动超时（30秒）'; exit 1 }
    Start-Sleep -Milliseconds 400
  }
  Write-Host "CDP 就绪"
}

Write-Host "正在注入皮肤..."
$cli = Join-Path $Root 'src/cli.mjs'
$applyArgs = @('apply', '--port', "$Port")
if ($Theme) { $applyArgs += @('--theme', $Theme) }
& $node $cli @applyArgs
Write-Host ""
Write-Host "[完成] WorkBuddy 已带皮肤启动" -ForegroundColor Green
Write-Host "  → 右上角点 🎨 按钮可切换主题 / 上传自定义图片"
Start-Sleep -Seconds 4