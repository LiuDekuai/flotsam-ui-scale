#requires -version 3.0
# Launcher: runs scripts\install.ps1 or scripts\uninstall.ps1 with administrator rights.
# Called by install.bat / uninstall.bat so that paths containing spaces (and any
# extra parameters such as -Scale 1.75) are passed to the elevated process safely.

$action = $args[0]
if (-not $action -or ($action -ne 'install' -and $action -ne 'uninstall')) {
    Write-Host 'internal launcher, use install.bat / uninstall.bat' -ForegroundColor Yellow
    exit 1
}

$root   = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$target = Join-Path $root ("scripts\" + $action + ".ps1")
if (-not (Test-Path -LiteralPath $target)) {
    Write-Host ("script not found: " + $target) -ForegroundColor Red
    exit 1
}

$rest = @()
if ($args.Count -gt 1) {
    $rest = @($args[1..($args.Count - 1)])
}

# -WhatIf only reads files, so it does not need elevation.
if ($rest -contains '-WhatIf') {
    & $target @rest
    $code = $LASTEXITCODE
    if (-not ($rest -contains '-NoWait')) { Read-Host '按回车关闭窗口' | Out-Null }
    exit $code
}

$arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $target + '"'))
foreach ($item in $rest) {
    if ($item -match '\s' -and $item -notmatch '^".*"$') {
        $arguments += ('"' + $item + '"')
    } else {
        $arguments += $item
    }
}

Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $arguments
