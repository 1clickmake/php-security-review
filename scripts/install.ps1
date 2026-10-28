<#
.SYNOPSIS
    php-security-review 스킬을 여러 AI 에이전트에 설치한다.

.DESCRIPTION
    저장소의 skills/php-security-review 폴더를 대상 에이전트의 스킬 경로로 복사한다.
    지원 대상: opencode, claude, codex, cursor, copilot, antigravity, all

.PARAMETER Target
    설치 대상. 기본 opencode. 여러 개 지정 가능.

.PARAMETER Scope
    global(사용자 홈) 또는 project(지정 폴더). 기본 global.

.PARAMETER ProjectPath
    Scope=project 일 때 대상 프로젝트 루트. 기본 현재 디렉터리.

.PARAMETER WithCommand
    OpenCode / Claude Code 슬래시 커맨드(phpsec.md)도 함께 복사.

.PARAMETER List
    설치 경로만 출력하고 복사하지 않는다.

.EXAMPLE
    .\install.ps1 -Target all -Scope global

.EXAMPLE
    .\install.ps1 -Target cursor -Scope project -ProjectPath C:\work\site -WithCommand

.EXAMPLE
    .\install.ps1 -List -Target all -Scope project
#>
[CmdletBinding()]
param(
    [ValidateSet('opencode', 'claude', 'codex', 'cursor', 'copilot', 'antigravity', 'all')]
    [string[]]$Target = @('opencode'),

    [ValidateSet('global', 'project')]
    [string]$Scope = 'global',

    [string]$ProjectPath = '.',

    [switch]$WithCommand,

    [switch]$List
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

$repo = Split-Path -Parent $PSScriptRoot
$src = Join-Path $repo 'skills\php-security-review'
if (-not (Test-Path -LiteralPath $src)) { throw "스킬 폴더를 찾을 수 없습니다: $src" }

$userHome = $env:USERPROFILE
$proj = (Resolve-Path -LiteralPath $ProjectPath).Path

function Get-SkillDest {
    param([string]$Name)

    switch ($Name) {
        'opencode' {
            if ($Scope -eq 'global') { return (Join-Path $userHome '.config\opencode\skills\php-security-review') }
            return (Join-Path $proj '.opencode\skills\php-security-review')
        }
        'claude' {
            if ($Scope -eq 'global') { return (Join-Path $userHome '.claude\skills\php-security-review') }
            return (Join-Path $proj '.claude\skills\php-security-review')
        }
        'codex' {
            if ($Scope -eq 'global') { return (Join-Path $userHome '.agents\skills\php-security-review') }
            return (Join-Path $proj '.agents\skills\php-security-review')
        }
        'cursor' {
            if ($Scope -eq 'global') { return (Join-Path $userHome '.cursor\skills\php-security-review') }
            return (Join-Path $proj '.cursor\skills\php-security-review')
        }
        'copilot' {
            if ($Scope -eq 'global') { return (Join-Path $userHome '.copilot\skills\php-security-review') }
            return (Join-Path $proj '.github\skills\php-security-review')
        }
        'antigravity' {
            if ($Scope -eq 'global') { return (Join-Path $userHome '.gemini\config\skills\php-security-review') }
            return (Join-Path $proj '.agents\skills\php-security-review')
        }
    }
}

function Get-CommandDest {
    param([string]$Name)

    switch ($Name) {
        'opencode' {
            if ($Scope -eq 'global') { return (Join-Path $userHome '.config\opencode\commands\phpsec.md') }
            return (Join-Path $proj '.opencode\commands\phpsec.md')
        }
        'claude' {
            if ($Scope -eq 'global') { return (Join-Path $userHome '.claude\commands\phpsec.md') }
            return (Join-Path $proj '.claude\commands\phpsec.md')
        }
    }
    return $null
}

$targets = @($Target)
if ($targets -contains 'all') {
    $targets = @('opencode', 'claude', 'codex', 'cursor', 'copilot', 'antigravity')
}

$rows = @()
$seen = @{}

foreach ($t in $targets) {
    $dest = Get-SkillDest -Name $t
    $key = $dest.ToLowerInvariant()
    $isDup = $seen.ContainsKey($key)
    $seen[$key] = $true

    $rows += [pscustomobject]@{
        Agent  = $t
        Scope  = $Scope
        Path   = $dest
        Status = if ($isDup) { '공유' } elseif ($List) { '예정' } else { '복사' }
    }

    if ($List -or $isDup) { continue }

    $parent = Split-Path -Parent $dest
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Copy-Item -Path (Join-Path $src '*') -Destination $dest -Recurse -Force

    if ($WithCommand) {
        $cmdDest = Get-CommandDest -Name $t
        if ($cmdDest) {
            $cmdSrc = Join-Path $repo 'commands\phpsec.md'
            if (Test-Path -LiteralPath $cmdSrc) {
                New-Item -ItemType Directory -Force -Path (Split-Path -Parent $cmdDest) | Out-Null
                Copy-Item -LiteralPath $cmdSrc -Destination $cmdDest -Force
                $rows += [pscustomobject]@{
                    Agent  = $t
                    Scope  = $Scope
                    Path   = $cmdDest
                    Status = '커맨드'
                }
            }
        }
    }
}

Write-Host ""
Write-Host ("php-security-review 설치 ({0})" -f $Scope) -ForegroundColor Cyan
Write-Host ("소스: {0}" -f $src) -ForegroundColor DarkGray
Write-Host ""
$rows | Format-Table Agent, Scope, Status, Path -AutoSize -Wrap

if ($List) {
    Write-Host "-List 모드: 실제 복사는 하지 않았습니다." -ForegroundColor Yellow
} else {
    Write-Host "완료. 에이전트를 재시작한 뒤 스킬 목록에서 'php-security-review' 를 확인하세요." -ForegroundColor Green
    Write-Host "자세한 사용법: docs/portable.md" -ForegroundColor DarkGray
}
