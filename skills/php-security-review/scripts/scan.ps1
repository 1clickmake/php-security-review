<#
.SYNOPSIS
    PHP 8+ 순수 PHP 보안 후보 스캐너 (휴리스틱).

.DESCRIPTION
    취약점을 "확정"하지 않는다. 검토 후보를 뽑아 데이터 흐름 추적의 출발점으로 쓴다.
    각 결과는 파일:라인 근거를 포함하며, 방어 코드가 이미 있는 경우 오탐일 수 있다.

.PARAMETER Path
    검수 대상 루트 디렉터리. 기본값 현재 디렉터리.

.PARAMETER Exclude
    제외할 디렉터리 이름 목록(경로 세그먼트 기준).

.PARAMETER MaxPerRule
    규칙당 최대 출력 건수. 기본 30.

.PARAMETER Csv
    결과를 CSV 로 저장할 경로(선택).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scan.ps1 -Path C:\work\site

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scan.ps1 -Path . -Csv .\scan-report.csv
#>
[CmdletBinding()]
param(
    [string]$Path = ".",
    [string[]]$Exclude = @('vendor', 'node_modules', '.git', 'tests', 'test', 'storage', 'cache', 'tmp', 'build', 'dist', 'uploads'),
    [int]$MaxPerRule = 30,
    [string]$Csv,
    [ValidateSet('Auto', 'UTF8', 'Default', 'OEM')]
    [string]$Encoding = 'Auto',
    [ValidateSet('Critical', 'High', 'Medium', 'Low', 'All')]
    [string]$MinSeverity = 'All'
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

if (-not (Test-Path -LiteralPath $Path)) {
    throw "path not found: $Path"
}
$root = (Resolve-Path -LiteralPath $Path).Path

# ---- 파일 수집 -------------------------------------------------------------
$exPat = if ($Exclude -and $Exclude.Count -gt 0) {
    '(?i)[\\/](' + (($Exclude | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')[\\/]'
} else { $null }

$files = @(Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.php' -ErrorAction SilentlyContinue)
if ($exPat) {
    $files = @($files | Where-Object { $_.FullName -notmatch $exPat })
}

if ($files.Count -eq 0) {
    Write-Host "PHP 파일을 찾지 못했습니다: $root" -ForegroundColor Yellow
    return
}

# ---- 규칙 ------------------------------------------------------------------
$rules = @(
    @{ Id='SQLI-CONCAT'; Severity='Critical'; Note='SQL 문자열에 슈퍼글로벌 직접 연결 → prepared statement 필요'
       Rx='(?i)(select|insert|update|delete|replace)\s[^;]{0,200}\$(_GET|_POST|_REQUEST|_COOKIE|_SERVER)' }

    @{ Id='SQLI-QUERY-VAR'; Severity='High'; Note='쿼리 실행 함수에 변수 전달 → 값/식별자 구분 확인'
       Rx='(?i)(mysqli?_query|mysqli_multi_query|->query|->exec|pg_query)\s*\([^)]*\$' }

    @{ Id='XSS-ECHO'; Severity='High'; Note='슈퍼글로벌 직접 출력 → 컨텍스트별 이스케이프 필요'
       Rx='(?i)\b(echo|print)\b[^;]{0,120}\$(_GET|_POST|_REQUEST|_COOKIE)' }

    @{ Id='XSS-SHORT-TAG'; Severity='High'; Note='<?= 로 슈퍼글로벌 직접 출력'
       Rx='(?i)<\?=\s*\$(_GET|_POST|_REQUEST|_COOKIE)' }

    @{ Id='XSS-ROW-ECHO'; Severity='Medium'; Note='DB 값 직접 출력 → 저장형 XSS 확인(e() 적용 여부)'
       Rx='(?i)\b(echo|<\?=)\b[^;]{0,80}\$(row|data|item|post|user|res|result)\[' }

    @{ Id='CMD-INJECTION'; Severity='Critical'; Note='쉘 실행 함수 → escapeshellarg + 고정 바이너리 확인'
       Rx='(?i)\b(system|exec|shell_exec|passthru|popen|proc_open)\s*\(' }

    @{ Id='BACKTICK-EXEC'; Severity='High'; Note='백틱 연산자 = shell_exec (SQL 식별자 백틱과 구분)'
       Rx='(?:=|\breturn|\becho)\s*`[^`\r\n]{0,120}\$' }

    @{ Id='CODE-EVAL'; Severity='Critical'; Note='eval 사용 → 입력이 코드로 해석되는지 확인'
       Rx='(?i)\beval\s*\(' }

    @{ Id='CODE-ASSERT'; Severity='High'; Note='assert 에 변수 → 로직 우회 위험'
       Rx='(?i)\bassert\s*\(\s*\$' }

    @{ Id='DESERIALIZE'; Severity='Critical'; Note='unserialize → allowed_classes / 서명 검증 확인'
       Rx='(?i)\bunserialize\s*\(' }

    @{ Id='VAR-EXTRACT'; Severity='High'; Note='extract() → 변수 덮어쓰기'
       Rx='(?i)\bextract\s*\(' }

    @{ Id='PARSE-STR-NO-TARGET'; Severity='Medium'; Note='parse_str 2번째 인자 없음 → 변수 오염'
       Rx='(?i)\bparse_str\s*\([^,)]*\)\s*;' }

    @{ Id='LFI-INCLUDE'; Severity='Critical'; Note='가변 include/require → 화이트리스트 맵 확인'
       Rx='(?i)\b(include|include_once|require|require_once)\s*\(?\s*\$' }

    @{ Id='FILE-READ-VAR'; Severity='High'; Note='가변 경로 읽기 → realpath + prefix 검사 확인'
       Rx='(?i)\b(file_get_contents|readfile|highlight_file|show_source|fopen)\s*\(\s*\$' }

    @{ Id='FILE-WRITE-VAR'; Severity='High'; Note='가변 경로 쓰기/삭제 → 경로 조작 확인'
       Rx='(?i)\b(file_put_contents|fwrite|unlink|rename|copy|chmod)\s*\([^)]*\$' }

    @{ Id='UPLOAD'; Severity='Medium'; Note='업로드 처리 → MIME/확장자/저장 위치 검증 확인'
       Rx='(?i)\bmove_uploaded_file\s*\(' }

    @{ Id='UPLOAD-MIME-TRUST'; Severity='High'; Note='$_FILES[type] 신뢰 → 클라이언트 제공값'
       Rx='(?i)\$_FILES\s*\[[^\]]+\]\s*\[\s*[''"]type[''"]\s*\]' }

    @{ Id='SSRF-CURL'; Severity='High'; Note='사용자 입력 URL 요청 → 스킴/호스트 화이트리스트 확인'
       Rx='(?i)(curl_init|file_get_contents|fopen)\s*\([^)]*\$(_GET|_POST|_REQUEST)' }

    @{ Id='HEADER-INJECTION'; Severity='High'; Note='header() 에 변수 → CRLF 인젝션 확인'
       Rx='(?i)\bheader\s*\([^)]*\$' }

    @{ Id='COOKIE-INJECTION'; Severity='Medium'; Note='setcookie 값에 변수'
       Rx='(?i)\bsetcookie\s*\([^)]*\$' }

    @{ Id='OPEN-REDIRECT'; Severity='High'; Note='Location 에 변수 → 내부 경로 화이트리스트 확인'
       Rx='(?i)header\s*\(\s*[''"]\s*Location:\s*[^''"]*\$' }

    @{ Id='WEAK-HASH'; Severity='Medium'; Note='md5/sha1 사용 → 비밀번호/토큰 용도인지 확인'
       Rx='(?i)\b(md5|sha1|crc32)\s*\(' }

    @{ Id='WEAK-RANDOM'; Severity='Medium'; Note='보안 난수 아님 → random_bytes/random_int 확인'
       Rx='(?i)\b(rand|mt_rand|lcg_value|uniqid)\s*\(' }

    @{ Id='LOOSE-COMPARE-AUTH'; Severity='High'; Note='인증/토큰 느슨한 비교 → hash_equals/=== 확인'
       Rx='(?i)\$(password|passwd|hash|token|otp|code|key)\w*\s*(==|!=)[^=]' }

    @{ Id='MAGIC-HASH-COMPARE'; Severity='High'; Note='0e 매직 해시 비교 가능성'
       Rx='(?i)(==|!=)\s*[''"]?0[eE][0-9a-f]*[''"]?' }

    @{ Id='REQUEST-SUPERGLOBAL'; Severity='Medium'; Note='$_REQUEST 사용 → 쿠키로 파라미터 덮어쓰기'
       Rx='\$_REQUEST\b' }

    @{ Id='HARDCODED-SECRET'; Severity='High'; Note='시크릿 하드코딩 의심'
       Rx='(?i)(password|passwd|pwd|secret|api[_-]?key|apikey|token|private[_-]?key)\s*=\s*[''"][^''"]{6,}[''"]' }

    @{ Id='DEBUG-LEFTOVER'; Severity='Medium'; Note='디버그 출력 잔존 → 정보 노출'
       Rx='(?i)\b(var_dump|print_r|phpinfo|debug_zval_dump|error_log\s*\(\s*print_r)\s*\(' }

    @{ Id='ERROR-DISPLAY'; Severity='Medium'; Note='에러 표시 설정 → 운영 환경 정보 노출'
       Rx='(?i)(display_errors|display_startup_errors)\s*=' }

    @{ Id='REMOTE-INCLUDE-CFG'; Severity='Critical'; Note='allow_url_include/fopen 설정 → RFI 표면'
       Rx='(?i)(allow_url_include|allow_url_fopen)\s*=' }

    @{ Id='SESSION-START'; Severity='Low'; Note='세션 설정(cookie flags/regenerate_id) 수동 확인'
       Rx='(?i)\bsession_start\s*\(' }

    @{ Id='XXE'; Severity='High'; Note='XML 파싱 → 엔티티 로딩 차단 확인'
       Rx='(?i)(simplexml_load_(string|file)|->loadXML|new\s+SimpleXMLElement|DOMDocument)' }

    @{ Id='INSECURE-INCLUDE-PATH'; Severity='Medium'; Note='상대 경로 include → open_basedir/realpath 확인'
       Rx='(?i)\b(include|require)(_once)?\s*\(?\s*[''"]\.\.?/' }

    @{ Id='G5-SQL-RAW'; Severity='Critical'; Note='그누보드 sql_query 에 슈퍼글로벌 직접 결합 → addslashes 여부와 무관하게 재검토'
       Rx='(?i)sql_query\s*\([^;]{0,200}\$(_GET|_POST|_REQUEST|_COOKIE)' }

    @{ Id='G5-SQL-VAR'; Severity='Low'; Note='sql_query 에 변수 전달 → 조립 경로 추적 (코어의 addslashes 관행은 오탐 가능)'
       Rx='(?i)sql_query\s*\(\s*\$' }

    @{ Id='G5-OUTPUT-RAW'; Severity='Medium'; Note='g5 데이터 배열 직접 출력 → 이스케이프/정화 확인'
       Rx='(?i)(echo|<\?=)\s*\$((view|write|list|board|member)\s*\[)' }

    @{ Id='G5-ADMIN-INCLUDE'; Severity='Low'; Note='adm/ 관리자 검사 순서 수동 확인'
       Rx='(?i)include_once\s*\(?[^;]*admin\.lib\.php' }
)

# ---- 스캔 ------------------------------------------------------------------
$sevOrder = @{ Critical = 0; High = 1; Medium = 2; Low = 3 }
$results = New-Object System.Collections.Generic.List[object]
$totalHits = 0

$paths = $files.FullName

# ---- 인코딩 결정 (EUC-KR 그누보드 / UTF-8 신규 프로젝트 모두 대응) ----------
function Resolve-SourceEncoding {
    param([string[]]$SamplePaths, [string]$Requested)
    if ($Requested -ne 'Auto') { return $Requested }
    $strictUtf8 = New-Object System.Text.UTF8Encoding($false, $true)
    foreach ($p in ($SamplePaths | Select-Object -First 25)) {
        try {
            $bytes = [System.IO.File]::ReadAllBytes($p)
            [void]$strictUtf8.GetString($bytes)
        } catch {
            return 'Default'   # 시스템 ANSI(한국어 Windows = CP949)
        }
    }
    return 'UTF8'
}

$encResolved = Resolve-SourceEncoding -SamplePaths $paths -Requested $Encoding
Write-Host ("소스 인코딩: {0}" -f $encResolved) -ForegroundColor DarkGray

foreach ($rule in $rules) {
    if ($MinSeverity -ne 'All' -and $sevOrder[$rule.Severity] -gt $sevOrder[$MinSeverity]) { continue }
    $hits = @()
    try {
        $hits = @(Select-String -LiteralPath $paths -Pattern $rule.Rx -AllMatches -Encoding $encResolved -ErrorAction SilentlyContinue)
    } catch {
        Write-Warning "rule $($rule.Id) skipped: $($_.Exception.Message)"
        continue
    }
    if ($hits.Count -eq 0) { continue }

    $totalHits += $hits.Count
    $shown = 0
    foreach ($h in $hits) {
        if ($shown -ge $MaxPerRule) {
            Write-Host ("  … {0}: {1}건 초과분 생략" -f $rule.Id, ($hits.Count - $MaxPerRule)) -ForegroundColor DarkGray
            break
        }
        $rel = $h.Path
        if ($rel.StartsWith($root)) { $rel = $rel.Substring($root.Length).TrimStart('\', '/') }
        $code = ($h.Line -replace '\s+', ' ').Trim()
        if ($code.Length -gt 160) { $code = $code.Substring(0, 160) + '…' }

        $results.Add([pscustomobject]@{
            Severity = $rule.Severity
            Rule     = $rule.Id
            File     = $rel
            Line     = $h.LineNumber
            Code     = $code
            Note     = $rule.Note
        })
        $shown++
    }
}

# ---- 출력 ------------------------------------------------------------------
Write-Host ""
Write-Host ("대상: {0}" -f $root) -ForegroundColor Cyan
Write-Host ("PHP 파일: {0}개 / 후보: {1}건" -f $files.Count, $results.Count) -ForegroundColor Cyan
Write-Host ""

if ($results.Count -eq 0) {
    Write-Host "후보 없음. (휴리스틱이므로 수동 검토는 계속 필요)" -ForegroundColor Green
} else {
    $results |
        Sort-Object @{ Expression = { $sevOrder[$_.Severity] } }, Rule, File, Line |
        Format-Table Severity, Rule, File, Line, Code -AutoSize -Wrap
}

$summary = $results | Group-Object Severity | ForEach-Object {
    [pscustomobject]@{ Severity = $_.Name; Count = $_.Count }
} | Sort-Object @{ Expression = { $sevOrder[$_.Severity] } }

Write-Host ""
Write-Host "== 등급 요약 ==" -ForegroundColor Cyan
$summary | Format-Table -AutoSize

if ($Csv) {
    $results | Sort-Object @{ Expression = { $sevOrder[$_.Severity] } }, Rule, File, Line |
        Export-Csv -LiteralPath $Csv -NoTypeInformation -Encoding UTF8
    Write-Host ("CSV 저장: {0}" -f (Resolve-Path -LiteralPath $Csv).Path) -ForegroundColor Green
}

# ---- 구조 점검 (배포 노출) --------------------------------------------------
Write-Host ""
Write-Host "== 구조 점검 ==" -ForegroundColor Cyan

$structural = @(
    @{ Rel = 'install';           Kind = 'dir';  Level = 'High';   Msg = 'install/ 잔존 → 재설치 공격 위험. 삭제 또는 접근 차단' }
    @{ Rel = 'data/dbconfig.php'; Kind = 'file'; Level = 'High';   Msg = 'DB 설정 파일 → 웹 접근 차단 확인' }
    @{ Rel = '.git';              Kind = 'dir';  Level = 'High';   Msg = '.git 노출 → 전체 소스 유출' }
    @{ Rel = '.env';              Kind = 'file'; Level = 'Medium'; Msg = '.env → 웹 접근 차단 확인' }
    @{ Rel = 'composer.json';     Kind = 'file'; Level = 'Low';    Msg = '의존성 정보 노출 확인' }
    @{ Rel = 'phpinfo.php';       Kind = 'file'; Level = 'Medium'; Msg = '임시 파일 삭제' }
    @{ Rel = 'test.php';          Kind = 'file'; Level = 'Low';    Msg = '임시 파일 삭제' }
)

$found = 0
foreach ($s in $structural) {
    $full = Join-Path $root $s.Rel
    if (Test-Path -LiteralPath $full) {
        Write-Host ("  [{0,-6}] {1} — {2}" -f $s.Level, $s.Rel, $s.Msg) -ForegroundColor Yellow
        $found++
    }
}

# data/ 내 백업/덤프 파일
$dataDir = Join-Path $root 'data'
if (Test-Path -LiteralPath $dataDir) {
    $dumps = @(Get-ChildItem -LiteralPath $dataDir -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in @('.sql', '.bak', '.zip', '.gz', '.tar', '.old', '.orig') })
    foreach ($d in $dumps | Select-Object -First 20) {
        $rel = $d.FullName
        if ($rel.StartsWith($root)) { $rel = $rel.Substring($root.Length).TrimStart('\', '/') }
        Write-Host ("  [{0,-6}] {1} — data/ 백업·덤프 노출 확인" -f 'High', $rel) -ForegroundColor Yellow
        $found++
    }
}

# extend/ 자동 로드 훅 목록 (정보성)
$extendDir = Join-Path $root 'extend'
if (Test-Path -LiteralPath $extendDir) {
    $hooks = @(Get-ChildItem -LiteralPath $extendDir -File -Filter '*.php' -ErrorAction SilentlyContinue)
    if ($hooks.Count -gt 0) {
        Write-Host ("  [정보  ] extend/ 자동 로드 훅 {0}개: {1}" -f $hooks.Count, (($hooks | Select-Object -First 10 -ExpandProperty Name) -join ', ')) -ForegroundColor DarkGray
        $found++
    }
}

if ($found -eq 0) {
    Write-Host "  구조 노출 항목 없음" -ForegroundColor Green
}

Write-Host ""

Write-Host ""
Write-Host "주의: 결과는 '후보'입니다. source→sink 데이터 흐름과 실제 방어 코드를 확인한 뒤 판정하세요." -ForegroundColor Yellow
