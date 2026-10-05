# ============================================================
#  星穹铁道 官服/B服 双切启动器（通用版）
#  首次运行会要求填写游戏目录（包含 StarRail.exe 的文件夹），保存在同目录"游戏路径.conf"
#  之后每次运行直接选 1(官服) / 2(B服)
# ============================================================
param(
    [string]$Server = "",      # 可选：guan / bili，跳过菜单直接启动
    [string]$GameDir = "",     # 可选：直接指定游戏目录（跳过读取已保存路径）
    [switch]$NoLaunch          # 可选：只切换配置不启动游戏（测试用）
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$confFile  = Join-Path $scriptDir '游戏路径.conf'
$utf8bom   = New-Object Text.UTF8Encoding $true

$channels = @{
    guan = @{ ch = 1;  sub = 1; cps = 'gw_PC';       name = '官服' }
    bili = @{ ch = 14; sub = 0; cps = 'bilibili_PC'; name = 'B服'  }
}

# 把用户输入的各种形式（带引号/拖拽/上层目录/直接给exe）解析成真正的游戏目录
function Resolve-GameDir([string]$raw) {
    $p = $raw.Trim().Trim('"').Trim("'").Trim().TrimEnd('\').Trim()
    if (-not $p) { return $null }
    if ($p -like '*StarRail.exe') {
        if (Test-Path -LiteralPath $p) { return (Split-Path -Parent $p) }
        return $null
    }
    if (Test-Path -LiteralPath (Join-Path $p 'StarRail.exe')) { return $p }
    foreach ($sub in @('games\Star Rail Game', 'Star Rail Game', 'Game')) {
        $c = Join-Path $p $sub
        if (Test-Path -LiteralPath (Join-Path $c 'StarRail.exe')) { return $c }
    }
    return $null
}

function Read-SavedGameDir {
    if (Test-Path -LiteralPath $confFile) {
        $p = ([IO.File]::ReadAllText($confFile)).Trim().Trim('"')
        if ($p -and (Test-Path -LiteralPath (Join-Path $p 'StarRail.exe'))) { return $p }
    }
    return $null
}

function Save-GameDir([string]$dir) {
    [IO.File]::WriteAllText($confFile, $dir, $utf8bom)
}

function Ask-GameDir {
    while ($true) {
        Write-Host ""
        Write-Host "首次使用：请设置游戏目录（包含 StarRail.exe 的文件夹）" -ForegroundColor Yellow
        Write-Host "  方法1：在游戏文件夹上按住 Shift 点右键 -> ""复制文件地址""，粘贴到下面"
        Write-Host "  方法2：直接把游戏文件夹拖进本窗口"
        Write-Host "  常见路径形如: ...\Star Rail\games\Star Rail Game"
        $raw = Read-Host "游戏目录"
        $g = Resolve-GameDir $raw
        if ($g) {
            Save-GameDir $g
            Write-Host "[OK] 游戏目录已保存：$g" -ForegroundColor Green
            return $g
        }
        Write-Host "[错误] 在输入的路径里找不到 StarRail.exe，请重新输入" -ForegroundColor Red
    }
}

function Set-Channel([string]$key) {
    $c    = $channels[$key]
    $cfg  = Join-Path $gameDir 'config.ini'
    $text = [IO.File]::ReadAllText($cfg)
    $text = [regex]::Replace($text, '(?m)^channel=[^\r\n]*',     "channel=$($c.ch)")
    $text = [regex]::Replace($text, '(?m)^sub_channel=[^\r\n]*', "sub_channel=$($c.sub)")
    $text = [regex]::Replace($text, '(?m)^cps=[^\r\n]*',         "cps=$($c.cps)")
    if ($text -notmatch '(?m)^channel=') { throw "config.ini 中没有 channel 配置，可能不是国服客户端" }
    [IO.File]::WriteAllText($cfg, $text, [Text.Encoding]::Default)
    Write-Host "[OK] 已切换为：$($c.name)（channel=$($c.ch), cps=$($c.cps)）" -ForegroundColor Green
}

function New-DesktopShortcut {
    $ws      = New-Object -ComObject WScript.Shell
    $desktop = [Environment]::GetFolderPath('Desktop')
    $lnk     = Join-Path $desktop '星穹铁道(选服启动).lnk'
    $l = $ws.CreateShortcut($lnk)
    $bat = Join-Path $scriptDir '星铁双服启动器.bat'
    if (Test-Path -LiteralPath $bat) {
        $l.TargetPath = $bat
        $l.Arguments  = ''
    } else {
        $l.TargetPath = 'powershell.exe'
        $l.Arguments  = '-NoProfile -ExecutionPolicy Bypass -File "' + (Join-Path $scriptDir 'start.ps1') + '"'
    }
    $l.WorkingDirectory = $scriptDir
    $l.IconLocation     = (Join-Path $gameDir 'StarRail.exe') + ',0'
    $l.Save()
    Write-Host "[OK] 已创建桌面快捷方式：$lnk" -ForegroundColor Green
}

# ---------- 主流程 ----------
Write-Host ""
Write-Host "========= 星穹铁道 双服启动器 =========" -ForegroundColor Cyan

if ($GameDir) {
    $g = Resolve-GameDir $GameDir
    if (-not $g) { Write-Host "[错误] -GameDir 指定的目录里找不到 StarRail.exe" -ForegroundColor Red; exit 1 }
    $gameDir = $g
} else {
    $gameDir = Read-SavedGameDir
    if (-not $gameDir) {
        # 脚本被直接放进游戏目录的情况：取上一级
        $try = Split-Path -Parent $scriptDir
        if (Test-Path -LiteralPath (Join-Path $try 'StarRail.exe')) {
            $gameDir = $try; Save-GameDir $try
        } else {
            $gameDir = Ask-GameDir
        }
    }
}
Write-Host "游戏目录：$gameDir"
Write-Host ""

# 选服
$pick = ''
if ($Server -eq 'guan' -or $Server -eq 'bili') { $pick = $Server }
else {
    while ($true) {
        Write-Host "   [1] 启动官服（米哈游账号）"
        Write-Host "   [2] 启动B服（B站账号）"
        Write-Host "   [3] 修改游戏目录"
        Write-Host "   [4] 创建桌面快捷方式"
        Write-Host "   [0] 退出"
        $c = Read-Host "请选择"
        if     ($c -eq '1') { $pick = 'guan'; break }
        elseif ($c -eq '2') { $pick = 'bili'; break }
        elseif ($c -eq '3') { $gameDir = Ask-GameDir; Write-Host "" ; continue }
        elseif ($c -eq '4') { New-DesktopShortcut; Write-Host ""; continue }
        elseif ($c -eq '0') { exit }
    }
}

try {
    Set-Channel $pick
} catch {
    Write-Host "[错误] $_ （游戏是否正在运行？关掉后重试）" -ForegroundColor Red
    exit 1
}

if ($NoLaunch) { exit 0 }

Write-Host "[OK] 正在启动游戏..."
Start-Process -FilePath (Join-Path $gameDir 'StarRail.exe') -WorkingDirectory $gameDir
