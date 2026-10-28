# 사용 가이드 (Usage)

실전 시나리오별 사용법입니다. 설치가 안 되어 있다면 먼저 [`install.md`](install.md)를 보세요.

- [1. 빠른 시작](#1-빠른-시작)
- [2. 시나리오별 검수](#2-시나리오별-검수)
- [3. `/phpsec` 커맨드](#3-phpsec-커맨드)
- [4. 스캐너 상세](#4-스캐너-상세)
- [5. 버전 대조 상세](#5-버전-대조-상세)
- [6. 보고서 읽는 법](#6-보고서-읽는-법)
- [7. 오탐 처리](#7-오탐-처리)
- [8. 규칙 추가](#8-규칙-추가)
- [9. 자동화 (CI)](#9-자동화-ci)
- [10. 치트시트](#10-치트시트)

---

## 1. 빠른 시작

### 에이전트에서

```text
/phpsec C:\work\my-site
```

### 스크립트만

```powershell
$S = "$env:USERPROFILE\.config\opencode\skills\php-security-review\scripts"

# 1) 버전 먼저
powershell -ExecutionPolicy Bypass -File "$S\version-check.ps1" -Path C:\work\my-site

# 2) 코드 스캔
powershell -ExecutionPolicy Bypass -File "$S\scan.ps1" -Path C:\work\my-site -MinSeverity High
```

---

## 2. 시나리오별 검수

### A. 순수 PHP 프로젝트 — 배포 전 전체 검수

```text
/phpsec C:\work\my-app
```

에이전트가 수행하는 순서:

1. `composer audit` (composer.json이 있으면)
2. `version-check.ps1` — PHP 버전·의존성 확인
3. `scan.ps1` — 후보 수집
4. 후보별 `source → sink` 추적
5. 심각도 판정 + 패치 코드 제시
6. 보고서 작성

원하는 범위를 자연어로 덧붙일 수 있습니다.

```text
/phpsec C:\work\my-app
- 인증/세션 코드는 제외
- 파일 업로드와 결제 관련만 깊게
- High 이상만
```

### B. 그누보드5 — 커스텀 영역 우선

그누보드 코어는 스캔해도 노이즈만 커집니다. **커스텀 영역만** 스캔하고, 코어는 버전으로 처리합니다.

```powershell
$S = "$env:USERPROFILE\.config\opencode\skills\php-security-review\scripts"
$site = "C:\work\gnuboard-site"

# 버전 대조 (코어는 여기서 처리)
powershell -ExecutionPolicy Bypass -File "$S\version-check.ps1" -Path $site -PhpVersion 8.3.12

# 커스텀 영역만
powershell -ExecutionPolicy Bypass -File "$S\scan.ps1" -Path "$site\theme" -MinSeverity High
powershell -ExecutionPolicy Bypass -File "$S\scan.ps1" -Path "$site\extend" -MinSeverity Medium
powershell -ExecutionPolicy Bypass -File "$S\scan.ps1" -Path "$site\page" -MinSeverity Medium
```

에이전트에게 맡길 때:

```text
/phpsec C:\work\gnuboard-site
그누보드 5.5.x 사이트야. theme/, extend/, page/, 루트 커스텀 파일만 검수하고
코어(lib, bbs, adm, shop, plugin)는 버전 대조로만 처리해줘.
```

**그누보드에서 반드시 확인하는 항목** (스킬이 자동 점검):

| 항목 | 이유 |
|---|---|
| `install/` 잔존 | 재설치 공격, SQL 덤프 노출 |
| `data/dbconfig.php` 접근 | DB 자격증명 유출 |
| `data/*.sql`, 백업 파일 | 전체 DB 유출 |
| `extend/*.php` | 자동 로드 → 백도어 상시 실행 |
| `plugin/` 구버전 | 서드파티 취약점 |
| 코어 파일 수정 여부 | 업데이트 시 유실 + 취약점 은폐 |
| `<?` short open tag | PHP 8 기본 설정에서 동작 안 함 |

### C. 버전만 빠르게 확인 (도메인만)

파일 접근 없이 PHP 버전과 그누보드 버전만 볼 때:

```powershell
powershell -ExecutionPolicy Bypass -File "$S\version-check.ps1" `
  -Path C:\work\gnuboard-site `
  -Domain example.com
```

동작 순서:

1. `X-Powered-By` 헤더에서 `PHP/x.y.z` 추출
2. 실패하면 `https://example.com/install/` 페이지에서 버전 패턴 추출
3. `version.php`의 `G5_GNUBOARD_VER`와 GitHub 최신 릴리스 비교

> 도메인 조회는 **읽기 요청만** 보냅니다. 서버에 파일을 쓰지 않습니다.

### D. 대규모 CMS — 노이즈 제어

1,600개 PHP 파일 규모에서 전체 스캔하면 후보가 5,000건 이상 나옵니다. 이때:

```powershell
# 1단계: High 이상, 규칙당 5건
powershell -ExecutionPolicy Bypass -File "$S\scan.ps1" `
  -Path C:\work\site -MinSeverity High -MaxPerRule 5 -Csv "$env:TEMP\high.csv"

# 2단계: 커스텀 디렉터리만
powershell -ExecutionPolicy Bypass -File "$S\scan.ps1" `
  -Path C:\work\site\theme -MinSeverity High

# 3단계: 특정 규칙만 보고 싶으면 CSV에서 필터
Import-Csv "$env:TEMP\high.csv" | Where-Object Rule -eq 'DESERIALIZE'
```

### E. 패치 후 재검증

```powershell
# 1) 수정 파일 문법 확인
php -l C:\work\site\theme\board\view.php

# 2) 동일 범위 재스캔
powershell -ExecutionPolicy Bypass -File "$S\scan.ps1" -Path C:\work\site\theme -MinSeverity High

# 3) 이전 CSV와 비교
$before = @(Import-Csv "$env:TEMP\before.csv")
$after  = @(Import-Csv "$env:TEMP\after.csv")
"before: $($before.Count) / after: $($after.Count)"
Compare-Object $before.Rule $after.Rule
```

에이전트에게는:

```text
/phpsec C:\work\site\theme
아까 지적한 XSS 2건 패치했어. 해당 파일만 재검증하고, 방어가 싱크 직전에 있는지 확인해줘.
```

---

## 3. `/phpsec` 커맨드

```text
/phpsec [대상 경로] [추가 지시]
```

| 예시 | 의미 |
|---|---|
| `/phpsec` | 현재 작업 디렉터리 전체 |
| `/phpsec C:\work\site` | 해당 경로 |
| `/phpsec C:\work\site\theme` | 커스텀 테마만 |
| `/phpsec C:\work\site High 이상만` | 심각도 필터 |
| `/phpsec C:\work\site 버전만 확인` | Step 0.5만 수행 |

커맨드는 다음을 강제합니다.

1. **Step 0.5(버전 대조)를 가장 먼저** 수행
2. 스캐너를 에이전트가 직접 실행 (사용자에게 터미널 요청 금지)
3. 후보를 데이터 흐름으로 검증
4. 보고서를 "즉시 조치(버전) → 요약 → 항목별" 순으로 작성
5. 코드 수정은 하지 않고 패치 코드만 제시

---

## 4. 스캐너 상세

### 4.1 기본 실행

```powershell
powershell -ExecutionPolicy Bypass -File scan.ps1 -Path <루트> [옵션]
```

### 4.2 옵션

| 옵션 | 형식 | 기본값 | 설명 |
|---|---|---|---|
| `-Path` | string | `.` | 검수 대상 루트 |
| `-Exclude` | string[] | `vendor, node_modules, .git, tests, test, storage, cache, tmp, build, dist, uploads` | 제외할 **디렉터리명** |
| `-MaxPerRule` | int | `30` | 규칙당 최대 출력/저장 건수 |
| `-Csv` | string | 없음 | CSV 저장 경로 |
| `-Encoding` | enum | `Auto` | `Auto` / `UTF8` / `Default` / `OEM` |
| `-MinSeverity` | enum | `All` | `Critical` / `High` / `Medium` / `Low` / `All` |

`-Exclude` 예:

```powershell
-Exclude @('vendor','node_modules','.git','backup','_old')
```

### 4.3 인코딩

| 값 | 의미 | 사용 시점 |
|---|---|---|
| `Auto` | 샘플 25개를 strict UTF-8로 디코드 시도 → 실패 시 `Default` | 기본값. 대부분 정상 |
| `UTF8` | UTF-8 강제 | 신규 프로젝트 |
| `Default` | 시스템 ANSI (한국어 Windows = CP949) | 그누보드 구버전 |
| `OEM` | 콘솔 OEM 코드페이지 | 콘솔 출력이 깨질 때 |

> `Auto`는 **파일 내용 기준**으로 판정합니다. UTF-8과 CP949가 섞인 사이트에서는 다수 파일 기준으로 하나가 선택되므로, 한쪽이 깨지면 `-Encoding`을 명시해 두 번 실행하세요.

### 4.4 규칙 목록 (37개)

| 규칙 | 심각도 | 탐지 대상 |
|---|---|---|
| `SQLI-CONCAT` | Critical | 문자열 결합으로 만든 SQL |
| `SQLI-QUERY-VAR` | High | 쿼리 함수에 변수 직접 전달 |
| `XSS-ECHO` | High | `echo`/`print` 로 슈퍼글로벌 원본 출력 |
| `XSS-SHORT-TAG` | High | `<?=` 로 원본 출력 |
| `XSS-ROW-ECHO` | Medium | DB row 값을 이스케이프 없이 출력 |
| `CMD-INJECTION` | Critical | `system`/`exec`/`shell_exec` 등에 변수 |
| `BACKTICK-EXEC` | High | 백틱 연산자 실행 |
| `CODE-EVAL` | Critical | `eval`, `create_function`, `preg_replace /e` |
| `CODE-ASSERT` | High | `assert()` 에 변수 |
| `DESERIALIZE` | Critical | `unserialize()` |
| `VAR-EXTRACT` | High | `extract()` 로 요청 변수 주입 |
| `PARSE-STR-NO-TARGET` | Medium | `parse_str()` 대상 인자 누락 |
| `LFI-INCLUDE` | Critical | 가변 `include`/`require` |
| `FILE-READ-VAR` | High | 변수 경로로 파일 읽기 |
| `FILE-WRITE-VAR` | High | 변수 경로로 파일 쓰기 |
| `UPLOAD` | Medium | `move_uploaded_file` 사용 지점 |
| `UPLOAD-MIME-TRUST` | High | `$_FILES['type']` 신뢰 |
| `SSRF-CURL` | High | 변수 URL로 cURL |
| `HEADER-INJECTION` | High | 변수로 `header()` |
| `COOKIE-INJECTION` | Medium | 변수로 `setcookie()` |
| `OPEN-REDIRECT` | High | 변수로 `Location:` |
| `WEAK-HASH` | Medium | `md5`, `sha1`, `crypt` |
| `WEAK-RANDOM` | Medium | `rand`, `mt_rand`, `uniqid` |
| `LOOSE-COMPARE-AUTH` | High | 인증/토큰 `==` 비교 |
| `MAGIC-HASH-COMPARE` | High | `0e` 매직 해시 비교 |
| `REQUEST-SUPERGLOBAL` | Medium | `$_REQUEST` 사용 |
| `HARDCODED-SECRET` | High | 코드에 비밀번호/키 하드코딩 |
| `DEBUG-LEFTOVER` | Medium | `var_dump`, `print_r`, `error_log` 디버그 |
| `ERROR-DISPLAY` | Medium | `display_errors` On, `error_reporting(E_ALL)` |
| `REMOTE-INCLUDE-CFG` | Critical | `allow_url_include` 류 설정 |
| `SESSION-START` | Low | `session_start()` (플래그 점검용) |
| `XXE` | High | `libxml_disable_entity_loader(false)`, `LIBXML_NOENT` |
| `INSECURE-INCLUDE-PATH` | Medium | 상대경로 `include` (경로 조작 가능성) |
| `G5-SQL-RAW` | Critical | 그누보드 `sql_query` 에 원본 요청값 |
| `G5-SQL-VAR` | Low | `sql_query($var)` — 코어 관행상 오탐 가능 |
| `G5-OUTPUT-RAW` | Medium | 그누보드 스킨에서 원본 출력 |
| `G5-ADMIN-INCLUDE` | Low | 관리자 페이지 include 패턴 |

> 규칙은 **후보 탐지**입니다. 예를 들어 `G5-SQL-VAR`는 그누보드 코어가 `addslashes`를 관행적으로 적용하기 때문에 Low로 낮춰 두었습니다. 실제 판정은 데이터 흐름 추적으로 합니다.

### 4.5 CSV 활용

```powershell
$rows = Import-Csv "$env:TEMP\scan.csv"

# 등급별 집계
$rows | Group-Object Severity | Sort-Object Count -Descending

# 파일별 집계
$rows | Group-Object File | Sort-Object Count -Descending | Select-Object -First 10

# 특정 규칙
$rows | Where-Object Rule -eq 'DESERIALIZE' | Format-Table File, Line, Code -Wrap
```

컬럼: `Severity`, `Rule`, `File`, `Line`, `Code`, `Note`

---

## 5. 버전 대조 상세

### 5.1 실행

```powershell
powershell -ExecutionPolicy Bypass -File version-check.ps1 `
  -Path <그누보드루트> `
  [-PhpVersion <x.y.z>] `
  [-Domain <도메인>] `
  [-SkipLatest]
```

### 5.2 PHP 판정

| 판정 | 의미 | 조치 |
|---|---|---|
| `[양호]` | 해당 브랜치의 최소 패치 버전 이상 | 없음 |
| `[위험]` | PHP2Shell 등 코어 CVE 미패치 | **즉시 PHP 업데이트** |
| `[지원종료]` | 8.1/8.0/7.4 등 EOL | 호스팅 백포트 확인 또는 업그레이드 |
| `[확인필요]` | 표에 없는 브랜치 | 수동 확인 |

> PHP 코어 CVE는 **애플리케이션 코드로 완화할 수 없습니다.** PHP가 앱 코드보다 먼저 요청을 처리하기 때문입니다.

### 5.3 그누보드 판정

- `G5_GNUBOARD_VER`를 파싱해 GitHub 최신 릴리스와 비교
- 뒤처지면 "보안패치 누락"으로 표시
- **코어 직접 수정 금지**, 백업 후 공식 업데이트 권고

### 5.4 PHP 버전을 모를 때

우선순위:

1. 호스팅 관리자 페이지 (가장 정확)
2. `-Domain` → `X-Powered-By` 헤더
3. `-Domain` → `/install/` 페이지
4. FTP 프로브 (파일 1개 업로드 → 확인 → 즉시 삭제, **사용자 승인 필수**)

> 스킬은 FTP 접속 정보를 먼저 요구하지 않습니다. 도메인/관리자 페이지로 확인하고, 불가능할 때만 선택지로 제시합니다.

---

## 6. 보고서 읽는 법

### 6.1 구성

```markdown
## 즉시 조치 (버전)     ← PHP/그누보드 패치. 코드보다 우선
## 요약                  ← 등급별 건수
## 발견 항목             ← 확정 취약점
## 확인 필요             ← 증거 부족 (추측 금지)
## 강화 권고             ← 취약점은 아니지만 개선 권장
```

### 6.2 항목별 필드

| 필드 | 의미 |
|---|---|
| 위치 | `file:line` — 클릭해서 바로 확인 가능 |
| 유형 | CWE 번호 포함 |
| 데이터 흐름 | source → 변환 → sink |
| 도달 조건 | 비인증 / 일반 사용자 / 관리자 전용 |
| 영향 | 기밀성·무결성·가용성 관점 |
| 재현 시나리오 | 요청 형태 수준 (실제 공격 페이로드 남용 금지) |
| 패치 | before/after 코드 |
| 재검증 | `php -l` + 흐름 재추적 결과 |

### 6.3 "확인 필요"를 무시하지 마세요

증거가 부족해 확정하지 못한 항목입니다. 다음 중 하나입니다.

- 코드 일부만 보고 판단 불가 (동적 include, 설정 의존)
- 방어 코드가 있으나 우회 가능성 확인 필요
- 프레임워크 규약 확인 필요

**"확인 필요"는 "안전"이 아닙니다.** 필요하면 해당 파일을 열어 추가 확인하세요.

### 6.4 심각도 재조정

보고서의 심각도는 **도달 가능성**에 따라 달라집니다.

| 상황 | 조정 |
|---|---|
| 관리자만 접근 가능 | Critical → High |
| 인증 필요 + CSRF 토큰 있음 | High → Medium |
| 데이터가 이미 이스케이프됨 | XSS 후보 → 제외 |
| `display_errors`만 켜짐 | Medium 유지 (경로 노출) |

---

## 7. 오탐 처리

스캐너는 휴리스틱이므로 오탐이 나옵니다. 대표적인 패턴:

| 후보 | 오탐인 경우 | 확인 방법 |
|---|---|---|
| `SQLI-CONCAT` | 값이 `(int)` 캐스팅됨 | 캐스팅이 문자열 컬럼에도 적용되는지 |
| `XSS-ROW-ECHO` | 이전에 `htmlspecialchars` 적용 | 같은 변수에 방어가 있는지 |
| `LFI-INCLUDE` | 경로가 화이트리스트 맵 | `$map[$key]` 형태인지 |
| `WEAK-HASH` | 비밀번호가 아닌 캐시 키 | 용도 확인 |
| `G5-SQL-VAR` | 그누보드 코어의 `addslashes` 관행 | 코어 함수 내부 확인 |
| `HARDCODED-SECRET` | 예제/테스트 값 | 실제 사용 여부 |
| `BACKTICK-EXEC` | SQL 식별자 백틱 | 실행 컨텍스트인지 |

오탐을 줄이는 방법:

1. `-MinSeverity High`로 좁힌다
2. `-MaxPerRule 5`로 규칙당 노이즈를 제한한다
3. 커스텀 디렉터리만 스캔한다
4. CSV에서 규칙별로 필터한다
5. 근본적으로는 **데이터 흐름 추적**으로 판정한다

---

## 8. 규칙 추가

`scripts/scan.ps1`의 `$rules` 배열에 항목을 추가합니다.

```powershell
@{ Id='MY-RULE'; Severity='High'; Note='설명'
   Rx='(?i)패턴' }
```

예: 위험한 함수 `proc_open` 탐지

```powershell
@{ Id='PROC-OPEN'; Severity='Critical'; Note='proc_open 에 변수 전달'
   Rx='(?i)proc_open\s*\([^)]*\$' }
```

주의:

- `Rx`는 **PowerShell 정규식**입니다. `$`는 이스케이프(`\$`)해야 합니다.
- 파일은 **UTF-8 BOM**으로 저장해야 PowerShell 5.1에서 한글이 깨지지 않습니다.
- 규칙을 추가하면 `README.md`의 규칙 표도 갱신하세요.

---

## 9. 자동화 (CI)

스캐너는 **종료 코드로 결과를 반환하지 않습니다.** CSV를 파싱해 판정하세요.

```powershell
$S = "C:\tools\php-security-review\skills\php-security-review\scripts"
$csv = "$env:TEMP\scan.csv"

powershell -ExecutionPolicy Bypass -File "$S\scan.ps1" `
  -Path . -MinSeverity High -Csv $csv | Out-Null

$rows = @(Import-Csv $csv)
$critical = @($rows | Where-Object Severity -eq 'Critical').Count
$high     = @($rows | Where-Object Severity -eq 'High').Count

"Critical: $critical / High: $high"

if ($critical -gt 0) {
    Write-Error "Critical 취약점 후보 $critical 건 — 배포 중단"
    exit 1
}
```

GitHub Actions(Windows runner) 예:

```yaml
name: php-security-scan
on: [pull_request]
jobs:
  scan:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/checkout@v4
        with:
          repository: 1clickmake/php-security-review
          path: .psr
      - shell: pwsh
        run: |
          $csv = "$env:TEMP\scan.csv"
          .\.psr\skills\php-security-review\scripts\scan.ps1 -Path . -MinSeverity High -Csv $csv
          $rows = @(Import-Csv $csv)
          $crit = @($rows | Where-Object Severity -eq 'Critical').Count
          if ($crit -gt 0) { throw "Critical: $crit" }
```

> CI에서는 후보를 **차단 조건**으로 쓰지 말고, 리뷰 트리거로 쓰는 것을 권합니다. 오탐이 있으면 빌드가 불안정해집니다.

---

## 10. 치트시트

```powershell
# 경로
$S = "$env:USERPROFILE\.config\opencode\skills\php-security-review\scripts"

# 전체 High 이상
powershell -ExecutionPolicy Bypass -File "$S\scan.ps1" -Path . -MinSeverity High

# 커스텀 테마만, 규칙당 5건, CSV
powershell -ExecutionPolicy Bypass -File "$S\scan.ps1" -Path .\theme -MinSeverity High -MaxPerRule 5 -Csv "$env:TEMP\t.csv"

# CP949 강제
powershell -ExecutionPolicy Bypass -File "$S\scan.ps1" -Path . -Encoding Default

# 버전 + 도메인
powershell -ExecutionPolicy Bypass -File "$S\version-check.ps1" -Path . -Domain example.com

# 버전 + PHP 버전
powershell -ExecutionPolicy Bypass -File "$S\version-check.ps1" -Path . -PhpVersion 8.3.12

# 오프라인
powershell -ExecutionPolicy Bypass -File "$S\version-check.ps1" -Path . -SkipLatest

# CSV에서 Critical만
Import-Csv "$env:TEMP\t.csv" | Where-Object Severity -eq 'Critical' | Format-Table -Wrap
```

### 안전 수칙

1. 검수는 **읽기 중심**. 운영 서버에 공격 트래픽을 보내지 않습니다.
2. PoC가 필요하면 **로컬 사본**에서만, 사용자 승인 후.
3. 코어 파일(`lib/`, `bbs/`, `adm/`)은 직접 패치하지 않고 **버전 업데이트**로 처리합니다.
4. `extend/` 의심 파일은 삭제하지 말고 **내용을 제시해 확인**받습니다.
5. 패치는 **취약 지점 단위 최소 diff**로, 동작 변경 가능성을 먼저 알립니다.
