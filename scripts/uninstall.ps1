<#
.SYNOPSIS
    Restore Flotsam's original UI scale limit (125%).

.DESCRIPTION
    Reverts the byte patch applied by install.ps1 and sets
    PlayerSettings.json back to UIScale 1.25.

.PARAMETER GameDir
    Flotsam install folder (the one that contains Flotsam_Data).
    Auto-detected when omitted.

.PARAMETER WhatIf
    Show what would happen, without changing any file.

.EXAMPLE
    .\uninstall.ps1
    .\uninstall.ps1 -GameDir 'D:\Games\Flotsam'
#>
[CmdletBinding()]
param(
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

$KnownHashes = @{
    'level1' = '67334511710E41D3CE7767604DA8FA3D4990EF1A7ED10D7412E4FBE2543809FE'
    'level2' = 'E17D1913729498398EC0117A4D32A69E04470F2CAE7944469B24ED2395DF3412'
}
$Offsets = @{
    'level1' = @(0xa5dc0, 0xd1910)
    'level2' = @(0x3c0bb0, 0x497ce0)
}
$MaxValueOffset = 0x154
$OriginalScale  = 1.25

$BackupDir = Join-Path $env:LOCALAPPDATA 'FlotsamUIScale\backup'

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

Write-Host ''
Write-Host '  Flotsam UI Scale - 还原' -ForegroundColor Cyan
Write-Host '  --------------------------------' -ForegroundColor Cyan

if (-not $WhatIf -and -not (Test-Administrator)) {
    Write-Host '需要管理员权限：请右键 uninstall.bat -> 以管理员身份运行。' -ForegroundColor Red
    exit 1
}

$dataDir = Find-FlotsamDataDir $GameDir
Write-Host "游戏目录: $dataDir"

if (Get-Process -Name Flotsam -ErrorAction SilentlyContinue) {
    Write-Host '检测到 Flotsam 正在运行，请先完全退出游戏。' -ForegroundColor Red
    exit 1
}

foreach ($file in @('level1', 'level2')) {
    $path = Join-Path $dataDir $file
    $bytes = [System.IO.File]::ReadAllBytes($path)
    $restored = [byte[]]$bytes.Clone()

    foreach ($offset in $Offsets[$file]) {
        if ($offset + $MaxValueOffset + 4 -gt $restored.Length) { throw "偏移量超出文件范围: $file" }
        [Array]::Copy([BitConverter]::GetBytes([single]$OriginalScale), 0, $restored, $offset + $MaxValueOffset, 4)
    }

    if ((Get-Sha256 $restored) -ne $KnownHashes[$file]) {
        Write-Host ''
        Write-Host "无法还原 $file：文件既不是原版，也不是本工具修改过的版本。" -ForegroundColor Red
        Write-Host "  文件: $path"
        Write-Host '  建议：在 Epic / Steam 里「验证游戏文件完整性」，或运行 install.ps1 -WhatIf 查看详情。'
        exit 2
    }

    if ($WhatIf) {
        Write-Host "  $file : 将还原为原始文件"
        continue
    }

    [System.IO.File]::WriteAllBytes($path, $restored)
    Write-Host "  已还原 $file" -ForegroundColor Green
}

if ($WhatIf) {
    Write-Host ''
    Write-Host '[WhatIf] 未修改任何文件。' -ForegroundColor Yellow
    exit 0
}

$config = Join-Path $env:USERPROFILE 'AppData\LocalLow\Pajama Llama Games\Flotsam\PlayerSettings.json'
if (Test-Path -LiteralPath $config) {
    $raw = [System.IO.File]::ReadAllText($config).TrimStart([char]0xFEFF)
    $new = [regex]::Replace($raw, '"UIScale"\s*:\s*[0-9.]+', '"UIScale":1.25')
    [System.IO.File]::WriteAllText($config, $new, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host '  已把 UIScale 还原为 1.25' -ForegroundColor Green
}

Write-Host ''
Write-Host '还原完成，游戏内 UI 缩放上限回到 125%。' -ForegroundColor Green
Write-Host ''
if (-not $NoWait) { Read-Host '按回车关闭窗口' | Out-Null }
