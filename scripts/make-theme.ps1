<#
.SYNOPSIS
  一键制作新主题
.DESCRIPTION
  1. 弹出文件选择框，选一张背景图
  2. 输入主题名字
  3. 选深色/浅色模式（自动填配色）
  4. 自动打包到 themes 目录，下次启动WorkBuddy就出现在🎨菜单里
#>
param()
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Continue'
$StudioRoot = Split-Path -Parent $PSScriptRoot
$ThemesDir = Join-Path $StudioRoot 'themes'

function Read-Color($prompt, $default) {
  do {
    $c = Read-Host "$prompt (6位色码，例如 FF6A00，直接回车用默认 $default)"
    if (-not $c) { return $default }
    $c = $c.Trim().TrimStart('#')
  } while ($c -notmatch '^[0-9A-Fa-f]{6}$')
  return '#' + $c.ToUpper()
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  WorkBuddy 新主题制作工具" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1) 选图片
Write-Host "[1/4] 请选择背景图片（PNG/JPG/WebP）..." -ForegroundColor Yellow
$dlg = New-Object System.Windows.Forms.OpenFileDialog
$dlg.Filter = "图片文件 (*.png;*.jpg;*.jpeg;*.webp)|*.png;*.jpg;*.jpeg;*.webp|所有文件 (*.*)|*.*"
$dlg.Title = "选择主题背景图"
if ($dlg.ShowDialog() -ne 'OK') { Write-Host "已取消"; Read-Host "按回车退出"; exit }
$imgPath = $dlg.FileName
$imgExt = [System.IO.Path]::GetExtension($imgPath).ToLower()
Write-Host "  已选: $imgPath" -ForegroundColor Green

# 2) 主题名
Write-Host ""
Write-Host "[2/4] 主题名字（例如：猫咪日记、星空浪漫、战神）" -ForegroundColor Yellow
$name = Read-Host "名字"
if (-not $name.Trim()) { Write-Host "名字不能为空"; Read-Host "按回车退出"; exit }
$name = $name.Trim()

# 生成id（小写字母+数字+连字符）
$id = $name.ToLower() -replace '[^\w\u4e00-\u9fa5]+', '-' -replace '^-+|-+$', ''
# 中文需要转拼音或用custom前缀，简单起见用custom-前缀+随机后缀
if ($id -match '[\u4e00-\u9fa5]') {
  $id = "custom-" + ([Guid]::NewGuid().ToString('N').Substring(0,6))
} else {
  $id = "custom-" + $id
}
Write-Host "  主题ID: $id" -ForegroundColor Gray

# 3) 配色
Write-Host ""
Write-Host "[3/4] 选择模式：" -ForegroundColor Yellow
Write-Host "  1. 深色主题（暗色背景+亮色文字）- 适合夜晚/二次元壁纸"
Write-Host "  2. 浅色主题（亮色背景+深色文字）- 适合白天/风景照"
Write-Host "  3. 自定义四个颜色"
do {
  $mode = Read-Host "选 1/2/3"
} while ($mode -notmatch '^[123]$')

switch ($mode) {
  '1' {
    Write-Host "  已选深色主题" -ForegroundColor Green
    $accent = Read-Color "  强调色（按钮/高亮）" "FF7A00"
    $secondary = Read-Color "  次要色（装饰/渐变）" "FFD166"
    $surface = Read-Color "  背景底色（侧边栏/面板）" "1A0500"
    $text = Read-Color "  文字色" "FFE8C0"
  }
  '2' {
    Write-Host "  已选浅色主题" -ForegroundColor Green
    $accent = Read-Color "  强调色（按钮/高亮）" "4294D0"
    $secondary = Read-Color "  次要色（装饰/渐变）" "EF8FD3"
    $surface = Read-Color "  背景底色（侧边栏/面板）" "F7FBFF"
    $text = Read-Color "  文字色" "17344F"
  }
  '3' {
    Write-Host "  自定义配色（请输入6位HEX色码，不要带#）" -ForegroundColor Green
    $accent = Read-Color "  强调色 accent" "FF7A00"
    $secondary = Read-Color "  次要色 secondary" "FFD166"
    $surface = Read-Color "  背景底色 surface（浅色就白FF接近白色，深色就接近黑色）" "1A0500"
    $text = Read-Color "  文字色 text（和surface要对比强烈）" "FFE8C0"
  }
}

# 4) 可选：宣传文案
Write-Host ""
Write-Host "[4/4] 主题文案（可选，直接回车跳过）" -ForegroundColor Yellow
$brand = Read-Host "  英文小字（显示在大字上方，例如 IGNITE · FORGE）"
$headline = Read-Host "  中文大字（显示在左上角，例如 薪火向前）"
$copy = ""
if ($brand -or $headline) {
  $copyObj = @{}
  if ($brand) { $copyObj.brand = $brand }
  if ($headline) { $copyObj.headline = $headline }
  $copy = ",`"copy`":$($copyObj | ConvertTo-Json -Compress)"
}

# 创建主题目录
$themeDir = Join-Path $ThemesDir $id
New-Item -ItemType Directory -Path $themeDir -Force | Out-Null
$heroName = "hero$imgExt"
Copy-Item $imgPath (Join-Path $themeDir $heroName) -Force

$themeJson = @"
{
  "schemaVersion": 1,
  "id": "$id",
  "name": "$name",
  "hero": "$heroName",
  "colors": {
    "accent": "$accent",
    "secondary": "$secondary",
    "surface": "$surface",
    "text": "$text"
  }$copy
}
"@
[System.IO.File]::WriteAllText((Join-Path $themeDir "theme.json"), $themeJson, [System.Text.UTF8Encoding]::new($false))

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  主题制作完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  主题名: $name" -ForegroundColor White
Write-Host "  主题ID: $id" -ForegroundColor Gray
Write-Host "  位置: $themeDir" -ForegroundColor Gray
Write-Host "  配色: accent=$accent secondary=$secondary surface=$surface text=$text" -ForegroundColor Gray
Write-Host ""
Write-Host "下一步：" -ForegroundColor Yellow
Write-Host "  方式A（推荐）：双击桌面「WorkBuddy换肤版」启动，右上角🎨菜单里就能看到 [$name] 主题了" -ForegroundColor White
Write-Host "  方式B：如果WorkBuddy已经在运行，关闭后重新启动即可" -ForegroundColor White
Write-Host ""
Write-Host "提示：可以把 $themeDir 文件夹打包zip发给朋友，放到他们的themes目录就能用" -ForegroundColor DarkGray
Write-Host ""
Read-Host "按回车退出"