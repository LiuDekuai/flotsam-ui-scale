<#
.SYNOPSIS
    Publish this repository to GitHub with as few clicks as possible.

.DESCRIPTION
    No GitHub CLI required. The script:
      1. asks for your GitHub user name (only once) and the repository name,
      2. opens the "new repository" page in your browser,
      3. after you press Enter, adds the remote and pushes the "main" branch,
      4. opens the new repository page when the push succeeds.

.PARAMETER UserName
    GitHub user or organization name. Asked interactively when omitted.

.PARAMETER RepoName
    Repository name. Defaults to "flotsam-ui-scale".

.PARAMETER Private
    Create a private repository hint page instead of a public one.

.PARAMETER WhatIf
    Only print what would be done; does not touch git or the browser.

.EXAMPLE
    .\publish-to-github.ps1 -UserName octocat
    .\publish-to-github.ps1 -UserName octocat -RepoName my-flotsam-mod -Private
#>
[CmdletBinding()]
param(
    [string]$UserName,
    [string]$RepoName = 'flotsam-ui-scale',
    [switch]$Private,
    [switch]$WhatIf
)

$ErrorActionPreference = 'Continue'

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

function Write-Step($text) { Write-Host "  $text" -ForegroundColor Cyan }
function Fail($text) {
    Write-Host ''
    Write-Host $text -ForegroundColor Red
    Write-Host ''
    Read-Host '按回车关闭窗口' | Out-Null
    exit 1
}

if (-not (Test-Path -LiteralPath (Join-Path $root '.git'))) {
    Fail "这里不是 git 仓库：$root"
}

$branch = (& git -C $root rev-parse --abbrev-ref HEAD).Trim()
if (-not $branch) { $branch = 'main' }

$commitCount = 0
try { $commitCount = [int](& git -C $root rev-list --count HEAD) } catch { $commitCount = 0 }
if ($commitCount -lt 1) { Fail '仓库里还没有 commit，无法发布。' }

if (-not $UserName) {
    $UserName = (& git -C $root config --get github.user)
    if ($UserName) { $UserName = $UserName.Trim() }
}
if (-not $UserName) {
    $UserName = Read-Host '你的 GitHub 用户名'
}
$UserName = $UserName.Trim()
if (-not $UserName) { Fail '用户名不能为空。' }

$answer = Read-Host ("仓库名 [" + $RepoName + "]")
if ($answer -and $answer.Trim()) { $RepoName = $answer.Trim() }

$repoUrl   = "https://github.com/$UserName/$RepoName"
$createUrl = "https://github.com/new?name=$RepoName"
if ($Private) { $createUrl += '&private=true' }

Write-Host ''
Write-Host '  Flotsam UI Scale - 发布到 GitHub' -ForegroundColor Cyan
Write-Host '  --------------------------------' -ForegroundColor Cyan
Write-Step "账号:   $UserName"
Write-Step "仓库:   $RepoName"
Write-Step ("分支:   " + $branch)
Write-Step "地址:   $repoUrl"

if ($WhatIf) {
    Write-Host ''
    Write-Host '[WhatIf] 将执行:'
    Write-Host "  git remote set-url origin $repoUrl.git"
    Write-Host "  git push -u origin $branch"
    exit 0
}

Write-Host ''
Write-Host '接下来会打开 GitHub 的「新建仓库」页面：' -ForegroundColor Yellow
Write-Host '  - 仓库名保持上面的名字'
Write-Host '  - 不要勾选 Add a README / .gitignore / license（本地已经有了）'
Write-Host '  - 点绿色的「Create repository」'
Write-Host ''
Start-Process $createUrl
Read-Host '仓库创建好后，回到这里按回车继续'

$remotes = @(& git -C $root remote 2>&1 | ForEach-Object { $_.ToString().Trim() })
if ($remotes -contains 'origin') {
    $null = & git -C $root remote set-url origin "$repoUrl.git" 2>&1
} else {
    $null = & git -C $root remote add origin "$repoUrl.git" 2>&1
}

Write-Host ''
Write-Step "推送 $branch 到 origin ..."
$pushOutput = & git -C $root push -u origin $branch 2>&1
$pushExit = $LASTEXITCODE
foreach ($line in $pushOutput) { Write-Host ("  " + $line.ToString()) }
if ($pushExit -ne 0) {
    Write-Host ''
    Write-Host '推送失败。常见原因：' -ForegroundColor Red
    Write-Host '  1. 还没有登录 GitHub：弹出的登录窗口里完成授权后，重新运行本脚本即可。'
    Write-Host '  2. 仓库已存在且不是空的（例如创建时勾选了 README）：'
    Write-Host "     git -C `"$root`" pull --rebase origin $branch"
    Write-Host "     git -C `"$root`" push -u origin $branch"
    Read-Host '按回车关闭窗口' | Out-Null
    exit 1
}

Write-Host ''
Write-Host "发布成功：$repoUrl" -ForegroundColor Green
Start-Process $repoUrl
Read-Host '按回车关闭窗口' | Out-Null
