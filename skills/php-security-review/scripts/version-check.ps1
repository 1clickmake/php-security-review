<#
.SYNOPSIS
    PHP / 그누보드 버전·패치 대조 스크립트.

.DESCRIPTION
    코드 검수 전에 "버전이 낡아서 생기는 구멍"을 먼저 판정한다.
    - 로컬 version.php 에서 G5_GNUBOARD_VER / G5_YOUNGCART_VER 파싱
    - GitHub Releases 로 최신 그누보드 버전 조회 후 차이 계산
    - PHP 버전을 PHP2Shell 등 최소 패치 버전표와 비교
    - 도메인을 주면 HTTP 헤더 / /install/ 페이지에서 PHP 버전 추정

.PARAMETER Path
    그누보드 루트 디렉터리. 기본값 현재 디렉터리.

.PARAMETER PhpVersion
    서버 PHP 버전 (예: 8.2.30). 호스팅 관리자 페이지에서 확인한 값을 넣는다.

.PARAMETER Domain
    사이트 도메인 (예: example.com). 주면 HTTP 로 PHP 버전을 추정한다.

.PARAMETER SkipLatest
    GitHub 최신 버전 조회를 건너뛴다 (오프라인/레이트리밋).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File version-check.ps1 -Path C:\work\site

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File version-check.ps1 -Path . -PhpVersion 8.2.30 -Domain example.com
#>
[CmdletBinding()]
param(
    [string]$Path = ".",
    [string]$PhpVersion,
    [string]$Domain,
    [switch]$SkipLatest
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

# ---- 유틸 ------------------------------------------------------------------
function Read-SourceText {
    param([string]$FilePath)
    $bytes = [System.IO.File]::ReadAllBytes($FilePath)
    $strictUtf8 = New-Object System.Text.UTF8Encoding($false, $true)
    try {
        return $strictUtf8.GetString($bytes)
    } catch {
        return [System.Text.Encoding]::GetEncoding(949).GetString($bytes)
    }
}

function Compare-VersionString {
    param([string]$A, [string]$B)
    $pa = @($A.Split('.') | ForEach-Object { if ($_ -match '^\d+$') { [int]$_ } else { 0 } })
    $pb = @($B.Split('.') | ForEach-Object { if ($_ -match '^\d+$') { [int]$_ } else { 0 } })
    $len = [Math]::Max($pa.Count, $pb.Count)
    for ($i = 0; $i -lt $len; $i++) {
        $x = if ($i -lt $pa.Count) { $pa[$i] } else { 0 }
        $y = if ($i -lt $pb.Count) { $pb[$i] } else { 0 }
        if ($x -lt $y) { return -1 }
        if ($x -gt $y) { return 1 }
    }
    return 0
}

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host ("== {0} ==" -f $Title) -ForegroundColor Cyan
}

# ---- 1. 로컬 버전 파싱 ------------------------------------------------------
if (-not (Test-Path -LiteralPath $Path)) { throw "path not found: $Path" }
$root = (Resolve-Path -LiteralPath $Path).Path

$verFile = Join-Path $root 'version.php'
$g5 = $null; $yc = $null; $label = $null

if (Test-Path -LiteralPath $verFile) {
    $text = Read-SourceText -FilePath $verFile
    $m = [regex]::Match($text, "G5_GNUBOARD_VER['""]?\s*,\s*['""]([0-9][0-9.]*)['""]")
    if ($m.Success) { $g5 = $m.Groups[1].Value }
    $m = [regex]::Match($text, "G5_YOUNGCART_VER['""]?\s*,\s*['""]([0-9][0-9.]*)['""]")
    if ($m.Success) { $yc = $m.Groups[1].Value }
    $m = [regex]::Match($text, "G5_VERSION['""]?\s*,\s*['""]([^'""]+)['""]")
    if ($m.Success) { $label = $m.Groups[1].Value }
}

Write-Section "1. 로컬 버전"
Write-Host ("경로          : {0}" -f $root)
Write-Host ("G5_VERSION    : {0}" -f ($(if ($label) { $label } else { '확인 불가' })))
Write-Host ("그누보드      : {0}" -f ($(if ($g5) { $g5 } else { '확인 불가 (version.php 없음)' })))
Write-Host ("영카트        : {0}" -f ($(if ($yc) { $yc } else { '없음/확인 불가' })))

# ---- 2. PHP 버전 / PHP2Shell 판정 -------------------------------------------
Write-Section "2. PHP 버전 / PHP2Shell (CVE-2026-109618, CVE-2026-109619)"

# 2026-10-21 공개된 PHP 코어 RCE. 아래 버전 이상이면 해당 브랜치 기준 패치됨.
$phpFixed = @{
    '8.5' = '8.5.12'
    '8.4' = '8.4.27'
    '8.3' = '8.3.36'
    '8.2' = '8.2.35'
}
$phpBackportOnly = @('8.1', '8.0', '7.4')

$detected = $PhpVersion
$detectSource = '입력값'

if (-not $detected -and $Domain) {
    # (a) HTTP 헤더
    try {
        $resp = Invoke-WebRequest -Uri ("https://{0}/" -f $Domain) -Method Head -UseBasicParsing -TimeoutSec 15
        $hdr = $resp.Headers
        $powered = $hdr['X-Powered-By']
        $server = $hdr['Server']
        Write-Host ("Server        : {0}" -f ($(if ($server) { $server } else { '-' })))
        Write-Host ("X-Powered-By  : {0}" -f ($(if ($powered) { $powered } else { '-' })))
        if ($powered -match 'PHP/([0-9]+\.[0-9]+\.[0-9]+)') {
            $detected = $Matches[1]
            $detectSource = 'HTTP 헤더'
        }
    } catch {
        Write-Host ("HTTP 헤더 조회 실패: {0}" -f $_.Exception.Message) -ForegroundColor DarkGray
    }

    # (b) 그누보드 install 페이지 (PHP 버전/환경 표 노출)
    if (-not $detected) {
        foreach ($u in @("/install/", "/install/index.php")) {
            try {
                $r = Invoke-WebRequest -Uri ("https://{0}{1}" -f $Domain, $u) -UseBasicParsing -TimeoutSec 15
                $body = $r.Content
                $pm = [regex]::Match($body, 'PHP[^0-9]{0,40}([0-9]+\.[0-9]+\.[0-9]+)')
                if ($pm.Success) {
                    $detected = $pm.Groups[1].Value
                    $detectSource = "install 페이지 ($u)"
                    Write-Host ("install 페이지 접근 가능: {0}  ← 노출 자체가 위험" -f $u) -ForegroundColor Yellow
                    break
                }
            } catch {
                # 접근 차단/404 는 정상일 수 있음
            }
        }
    }
}

if ($detected) {
    $branch = ($detected -split '\.')[0..1] -join '.'
    Write-Host ("PHP 버전      : {0}  (출처: {1})" -f $detected, $detectSource)

    if ($phpFixed.ContainsKey($branch)) {
        $need = $phpFixed[$branch]
        if ((Compare-VersionString $detected $need) -lt 0) {
            Write-Host ("판정          : [위험] {0} → {1} 이상 필요 (PHP2Shell)" -f $detected, $need) -ForegroundColor Red
            Write-Host "                애플리케이션 인증으로 차단 불가. PHP 자체를 패치해야 함." -ForegroundColor Red
        } else {
            Write-Host ("판정          : [양호] {0} 이상 (해당 브랜치 패치됨)" -f $need) -ForegroundColor Green
        }
    } elseif ($phpBackportOnly -contains $branch) {
        Write-Host ("판정          : [지원종료] PHP {0} — 정식 지원 종료. 백포트 패키지 적용 여부를 호스팅에 확인" -f $branch) -ForegroundColor Yellow
    } else {
        Write-Host ("판정          : [확인필요] PHP {0} — 최소 패치 버전표에 없는 브랜치" -f $branch) -ForegroundColor Yellow
    }
} else {
    Write-Host "PHP 버전      : 확인 불가" -ForegroundColor Yellow
    Write-Host "                → 호스팅 관리자 페이지에서 확인하거나, -PhpVersion 8.x.y 로 다시 실행" -ForegroundColor DarkGray
    Write-Host "                → 또는 -Domain <도메인> 으로 헤더/install 페이지 조회" -ForegroundColor DarkGray
}

# ---- 3. 그누보드 최신 버전 대조 --------------------------------------------
Write-Section "3. 그누보드 최신 버전 대조"

if (-not $g5) {
    Write-Host "로컬 버전을 확인할 수 없어 대조를 건너뜁니다." -ForegroundColor Yellow
} elseif ($SkipLatest) {
    Write-Host "SkipLatest 지정 — 조회 생략" -ForegroundColor DarkGray
} else {
    $latest = $null
    try {
        $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/gnuboard/gnuboard5/releases/latest" `
            -Headers @{ 'User-Agent' = 'opencode-php-security-review' } -TimeoutSec 20
        if ($rel.tag_name) { $latest = ($rel.tag_name -replace '^[vV]', '') }
        if ($rel.published_at) { Write-Host ("최신 릴리스   : {0} ({1:yyyy-MM-dd})" -f $latest, ([datetime]$rel.published_at)) }
    } catch {
        try {
            $tags = Invoke-RestMethod -Uri "https://api.github.com/repos/gnuboard/gnuboard5/tags?per_page=5" `
                -Headers @{ 'User-Agent' = 'opencode-php-security-review' } -TimeoutSec 20
            if ($tags.Count -gt 0) { $latest = ($tags[0].name -replace '^[vV]', '') }
        } catch {
            Write-Host ("최신 버전 조회 실패: {0}" -f $_.Exception.Message) -ForegroundColor DarkGray
        }
    }

    if ($latest) {
        Write-Host ("설치 버전     : {0}" -f $g5)
        Write-Host ("최신 버전     : {0}" -f $latest)
        if ((Compare-VersionString $g5 $latest) -lt 0) {
            Write-Host ("판정          : [위험] {0} 버전 뒤처짐 — 보안패치 누락 가능" -f $latest) -ForegroundColor Red
            Write-Host "                코어 직접 수정 금지. 백업 후 공식 버전으로 업데이트." -ForegroundColor Red
            Write-Host "                업데이트 후 관리자 → 환경설정 → DB업그레이드 필요할 수 있음." -ForegroundColor DarkGray
        } else {
            Write-Host "판정          : [양호] 최신 버전" -ForegroundColor Green
        }
    }
}

# ---- 4. 요약 ---------------------------------------------------------------
Write-Section "4. 요약"
if ($detected -and $phpFixed.ContainsKey((($detected -split '\.')[0..1] -join '.'))) {
    $branch = ($detected -split '\.')[0..1] -join '.'
    $need = $phpFixed[$branch]
    if ((Compare-VersionString $detected $need) -lt 0) {
        Write-Host ("- PHP {0} → {1} 이상으로 즉시 패치 (PHP2Shell)" -f $detected, $need) -ForegroundColor Red
    }
}
if ($g5 -and $latest -and ((Compare-VersionString $g5 $latest) -lt 0)) {
    Write-Host ("- 그누보드 {0} → {1} 업데이트 검토" -f $g5, $latest) -ForegroundColor Yellow
}
if (-not $detected) {
    Write-Host "- PHP 버전 확인 필요 (호스팅 관리자 페이지 / -PhpVersion / -Domain)" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "이 결과는 버전 축만 다룹니다. 코드 취약점은 scan.ps1 + 데이터 흐름 추적으로 별도 판정하세요." -ForegroundColor DarkGray
