<#
.SYNOPSIS
    Flotsam UI Scale - raise the in-game UI scale limit (default 150%).

.DESCRIPTION
    Patches Flotsam's scene files so the "UI Scale" slider in
    Settings -> Video can go above the hard-coded 125% cap,
    and writes the chosen value into PlayerSettings.json.

.PARAMETER Scale
    New upper limit for the UI scale slider. 1.0 - 2.0, default 1.5.

.PARAMETER GameDir
    Flotsam install folder (the one that contains Flotsam_Data).
    Auto-detected when omitted.

.PARAMETER WhatIf
    Show what would happen, without changing any file.
    Can be used without administrator rights.

.EXAMPLE
    .\install.ps1
    .\install.ps1 -Scale 1.6
    .\install.ps1 -GameDir 'D:\Games\Flotsam' -WhatIf
#>
[CmdletBinding()]
param(
    [ValidateRange(1.0, 2.0)]
    [double]$Scale = 1.5,

    [string]$GameDir,

    [switch]$WhatIf,

    [switch]$NoWait
)

$ErrorActionPreference = 'Stop'

trap {
    Write-Host ''
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host '如果问题持续存在，请到 GitHub Issues 反馈。' -ForegroundColor Yellow
    exit 1
}

# ---------------------------------------------------------------------------
# Build-specific data (Flotsam 1.1.0f5, Unity 6000.3.26f1, Windows x64)
# SHA-256 of the *unmodified* level1 / level2 files.
# ---------------------------------------------------------------------------
$KnownHashes = @{
    'level1' = 'A15A40BD855589C84001B29002260999AAE096A2B1BF06AFF1D6A7FA17C61E13'
    'level2' = '8A79413A6E6754526256FC283A190BC56C8184F39968AB56D21BAB5275D486D1'
}

# Byte offset of each UIScaleSlider MonoBehaviour inside the file.
$Offsets = @{
    'level1' = @(0xa5dc0, 0xd1910)
    'level2' = @(0x3c0bb0, 0x497ce0)
}

# Offset of Slider.m_MaxValue relative to the MonoBehaviour header.
$MaxValueOffset = 0x154
$OriginalScale  = 1.25

$BackupDir = Join-Path $env:LOCALAPPDATA 'FlotsamUIScale\backup'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Test-Administrator {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-Sha256([byte[]]$Data) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash($Data))).Replace('-', '')
    } finally {
        $sha.Dispose()
    }
}

function Find-FlotsamDataDir([string]$Hint) {
    if ($Hint) {
        $candidate = Join-Path $Hint 'Flotsam_Data'
        if (Test-Path -LiteralPath (Join-Path $candidate 'level1')) { return (Resolve-Path $candidate).Path }
        throw "在 '$Hint' 下找不到 Flotsam_Data\level1，请确认 -GameDir 指向 Flotsam 安装目录。"
    }

    $candidates = New-Object System.Collections.Generic.List[string]

    # Epic Games Launcher manifest
    $manifest = Join-Path $env:ProgramData 'Epic\UnrealEngineLauncher\LauncherInstalled.dat'
    if (Test-Path -LiteralPath $manifest) {
        try {
            $json = Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json
            foreach ($item in $json.InstallationList) {
                if ($item.AppName -match 'Flotsam') {
                    $candidates.Add((Join-Path $item.InstallLocation 'Flotsam_Data'))
                }
            }
        } catch { }
    }

    # Steam libraries
    $steamPath = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
    if ($steamPath) {
        $candidates.Add((Join-Path $steamPath 'steamapps\common\Flotsam\Flotsam_Data'))
        $libraryFile = Join-Path $steamPath 'steamapps\libraryfolders.vdf'
        if (Test-Path -LiteralPath $libraryFile) {
            $text = Get-Content -LiteralPath $libraryFile -Raw
            foreach ($match in [regex]::Matches($text, '"path"\s+"([^"]+)"')) {
                $library = $match.Groups[1].Value.Replace('\\', '\')
                $candidates.Add((Join-Path $library 'steamapps\common\Flotsam\Flotsam_Data'))
            }
        }
    }

    # Usual locations
    $candidates.Add('C:\Program Files\Epic Games\Flotsam\Flotsam_Data')
    $candidates.Add('C:\Program Files (x86)\Epic Games\Flotsam\Flotsam_Data')
    $candidates.Add('D:\Epic Games\Flotsam\Flotsam_Data')
    $candidates.Add('E:\Epic Games\Flotsam\Flotsam_Data')

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath (Join-Path $candidate 'level1'))) {
            return (Resolve-Path $candidate).Path
        }
    }

    throw "找不到 Flotsam 安装目录。请用 -GameDir 手动指定，例如：-GameDir 'D:\Epic Games\Flotsam'"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '  Flotsam UI Scale' -ForegroundColor Cyan
Write-Host '  --------------------------------' -ForegroundColor Cyan

if (-not $WhatIf -and -not (Test-Administrator)) {
    Write-Host '需要管理员权限：请右键 install.bat -> 以管理员身份运行。' -ForegroundColor Red
    exit 1
}

$dataDir = Find-FlotsamDataDir $GameDir
Write-Host "游戏目录: $dataDir"

if (Get-Process -Name Flotsam -ErrorAction SilentlyContinue) {
    Write-Host '检测到 Flotsam 正在运行，请先完全退出游戏。' -ForegroundColor Red
    exit 1
}

$plans = @()
foreach ($file in @('level1', 'level2')) {
    $path = Join-Path $dataDir $file
    if (-not (Test-Path -LiteralPath $path)) { throw "缺少文件: $path" }

    $bytes = [System.IO.File]::ReadAllBytes($path)
    $original = [byte[]]$bytes.Clone()

    foreach ($offset in $Offsets[$file]) {
        if ($offset + $MaxValueOffset + 4 -gt $original.Length) { throw "偏移量超出文件范围: $file 0x$($offset.ToString('X'))" }
        [Array]::Copy([BitConverter]::GetBytes([single]$OriginalScale), 0, $original, $offset + $MaxValueOffset, 4)
    }

    $originalHash = Get-Sha256 $original
    if ($originalHash -ne $KnownHashes[$file]) {
        Write-Host ''
        Write-Host "无法识别的游戏版本：$file" -ForegroundColor Red
        Write-Host "  文件:        $path"
        Write-Host "  SHA-256:     $(Get-Sha256 $bytes)"
        Write-Host "  还原后哈希:  $originalHash"
        Write-Host '  可能是 Steam 版、更新后的版本，或已被其它 MOD 修改过。'
        Write-Host '  请不要继续，先到 GitHub Issues 反馈（附上上面两个哈希）。'
        exit 2
    }

    $plans += [pscustomobject]@{
        File     = $file
        Path     = $path
        Bytes    = $bytes
        Original = $original
    }
}

foreach ($plan in $plans) {
    Write-Host ("  {0}: UI 缩放上限 {1} -> {2}" -f $plan.File, $OriginalScale, $Scale)
}

if ($WhatIf) {
    Write-Host ''
    Write-Host '[WhatIf] 未修改任何文件。' -ForegroundColor Yellow
    exit 0
}

# Back up the pristine originals once.
if (-not (Test-Path -LiteralPath $BackupDir)) {
    New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
}
foreach ($plan in $plans) {
    $backupPath = Join-Path $BackupDir ($plan.File + '.orig')
    if (-not (Test-Path -LiteralPath $backupPath)) {
        [System.IO.File]::WriteAllBytes($backupPath, $plan.Original)
        Write-Host "  已备份原始文件 -> $backupPath"
    }
}

# Apply the patch.
foreach ($plan in $plans) {
    $bytes = $plan.Bytes
    foreach ($offset in $Offsets[$plan.File]) {
        [Array]::Copy([BitConverter]::GetBytes([single]$Scale), 0, $bytes, $offset + $MaxValueOffset, 4)
    }
    [System.IO.File]::WriteAllBytes($plan.Path, $bytes)
    Write-Host ("  已修改 {0}" -f $plan.Path) -ForegroundColor Green
}

# Update the saved player setting as well.
$config = Join-Path $env:USERPROFILE 'AppData\LocalLow\Pajama Llama Games\Flotsam\PlayerSettings.json'
if (Test-Path -LiteralPath $config) {
    $raw = [System.IO.File]::ReadAllText($config).TrimStart([char]0xFEFF)
    $new = [regex]::Replace($raw, '"UIScale"\s*:\s*[0-9.]+', ('"UIScale":' + $Scale.ToString([System.Globalization.CultureInfo]::InvariantCulture)))
    [System.IO.File]::WriteAllText($config, $new, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ("  已把 UIScale 设为 {0}" -f $Scale) -ForegroundColor Green
}

Write-Host ''
Write-Host ("完成！进入游戏 -> 设置 -> 画面 -> UI 缩放，现在最高可调到 {0:P0}。" -f $Scale) -ForegroundColor Green
Write-Host '如需还原，运行 uninstall.bat。'
Write-Host ''
if (-not $NoWait) { Read-Host '按回车关闭窗口' | Out-Null }
