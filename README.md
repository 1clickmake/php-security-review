# php-security-review

**PHP 8+ / 그누보드5 보안 검수 스킬** — 코드·버전·의존성 3축 검수
*Security review skill for PHP 8+ and Gnuboard5 — code, version, and dependency checks*

[한국어](#한국어) · [English](#english)

---

## 한국어

### 한 줄 소개

AI 코딩 에이전트(OpenCode · Claude Code)에 설치하는 **PHP 보안 검수 워크플로**입니다.
정적 스캐너로 후보를 뽑고, **source → sink 데이터 흐름을 실제 코드로 추적**해 판정하며,
**PHP/그누보드 버전과 알려진 CVE를 대조**해 "지금 당장 패치해야 할 것"을 맨 앞에 보여줍니다.

> 단순 grep이 아닙니다. 후보를 **증거 기반으로 확정/기각**하고, 방어 코드가 싱크 직전에 있는지까지 봅니다.

### 무엇을 잡는가

| 축 | 내용 |
|---|---|
| **코드** | SQLi, XSS, LFI/RFI, 파일 업로드, 역직렬화, 커맨드 인젝션, SSRF, XXE, CSRF, 세션/인증 결함, 오픈 리다이렉트, 시크릿 하드코딩, 약한 해시/난수 |
| **버전** | PHP 코어 CVE(예: PHP2Shell), 그누보드/영카트 보안패치 누락, `install/`·`data/` 노출 |
| **의존성** | `composer audit` 연동 (해당 시) |

### 일반 스캐너와 다른 점

1. **데이터 흐름 판정** — `$_GET`에서 시작해 싱크까지 추적하고, 중간 검증이 실제로 흐름을 차단하는지 확인합니다. 검증 결과를 버리고 원본을 쓰는 코드를 잡습니다.
2. **싱크별 방어 적합성** — `intval()`을 HTML 출력에 쓴 코드, `htmlspecialchars()`를 SQL에 쓴 코드를 "안전"으로 오판하지 않습니다.
3. **버전 축** — 코드가 아무리 깨끗해도 PHP 코어가 패치되지 않았으면 뚫립니다. 이 부분을 별도 단계(Step 0.5)로 강제합니다.
4. **그누보드 프로필** — 코어와 커스텀을 분리하고, 코어 직접 수정 대신 버전 업데이트를 권고합니다. `addslashes` 관행 같은 코어 특유의 오탐을 줄입니다.
5. **오탐 억제** — 그누보드 1,600파일 전체 스캔 시 5,000건대 후보가 나오는 것을 커스텀 영역 + `-MinSeverity` 필터로 실무 수준까지 좁힙니다.

### 저장소 구조

```text
php-security-review/
├── README.md
├── LICENSE                      # MIT
├── CHANGELOG.md
├── skills/
│   └── php-security-review/     # ← 스킬 본체 (디렉터리명 = 스킬 ID)
│       ├── SKILL.md             # 워크플로 Step 0 ~ 6 + Step 0.5
│       ├── references/
│       │   ├── checklist.md         # CWE 매핑 취약점 카탈로그
│       │   ├── php8-hardening.md    # PDO/세션/업로드/CSRF/SSRF/헤더 하드닝 코드
│       │   ├── gnuboard.md          # 그누보드5 프로필 (코어 vs 커스텀)
│       │   └── advisories.md        # CVE 스냅샷 (PHP2Shell, 그누보드 KVE)
│       └── scripts/
│           ├── scan.ps1             # 휴리스틱 스캐너 (37개 규칙)
│           └── version-check.ps1    # 버전·CVE 대조
├── commands/
│   └── phpsec.md                # /phpsec 슬래시 커맨드
├── docs/
│   ├── install.md               # 설치 상세 (OpenCode / Claude Code / 수동)
│   └── usage.md                 # 사용법 상세 (시나리오별)
└── examples/
    └── report-sample.md         # 보고서 출력 예시
```

### 요구사항

| 항목 | 필수 | 비고 |
|---|---|---|
| Windows PowerShell **5.1+** | ✅ | Windows 10/11 기본 탑재. PowerShell 7(`pwsh`)도 가능 |
| OpenCode 또는 Claude Code | ✅ | 스킬을 지원하는 에이전트. 스크립트만 단독 사용도 가능 |
| PHP CLI | ⬜ | `php -l` 문법 검사용. 없어도 검수 가능 |
| Git | ⬜ | 저장소 설치 시 |
| **선행 스킬** | ❌ | **없음.** 독립 실행형입니다 (아래 참고) |

#### 필수 선행 스킬은 없습니다

이 스킬은 **다른 스킬에 의존하지 않습니다.** 체크리스트·하드닝 코드·스캐너·CVE 스냅샷이 모두 저장소 안에 포함되어 있습니다.

혹시 함께 설치된 `frontend-design`, `taste-skill` 같은 스킬이 보여도 **무관**합니다(UI/디자인용). 이 스킬은 그것들을 읽지 않습니다.

필요한 것은 "스킬"이 아니라 **도구**입니다:

```powershell
# 확인
powershell -Command "$PSVersionTable.PSVersion"   # 5.1 이상
php -v                                            # 선택
git --version                                     # 선택
```

### 설치

#### 방법 1 — OpenCode 전역 설치 (권장)

```powershell
# 1) 저장소 받기
git clone https://github.com/1clickmake/php-security-review.git "$env:TEMP\php-security-review"

# 2) 스킬 복사 (전역)
New-Item -ItemType Directory -Force "$env:USERPROFILE\.config\opencode\skills" | Out-Null
Copy-Item "$env:TEMP\php-security-review\skills\php-security-review" `
          "$env:USERPROFILE\.config\opencode\skills\" -Recurse -Force

# 3) 슬래시 커맨드 복사
New-Item -ItemType Directory -Force "$env:USERPROFILE\.config\opencode\commands" | Out-Null
Copy-Item "$env:TEMP\php-security-review\commands\phpsec.md" `
          "$env:USERPROFILE\.config\opencode\commands\" -Force

# 4) 정리
Remove-Item "$env:TEMP\php-security-review" -Recurse -Force
```

설치 결과:

```text
%USERPROFILE%\.config\opencode\
├── skills\php-security-review\
│   ├── SKILL.md
│   ├── references\...
│   └── scripts\...
└── commands\phpsec.md
```

> **중요**: 스킬 ID는 frontmatter의 `name`이 아니라 **디렉터리 이름**입니다. 반드시 `php-security-review` 폴더명을 유지하세요.

#### 방법 2 — 프로젝트별 설치

해당 프로젝트 루트에서:

```powershell
New-Item -ItemType Directory -Force ".opencode\skills" | Out-Null
Copy-Item "C:\path\to\php-security-review\skills\php-security-review" ".opencode\skills\" -Recurse -Force
New-Item -ItemType Directory -Force ".opencode\commands" | Out-Null
Copy-Item "C:\path\to\php-security-review\commands\phpsec.md" ".opencode\commands\" -Force
```

프로젝트별 설치가 전역 설치보다 우선합니다.

#### 방법 3 — Claude Code

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\skills" | Out-Null
Copy-Item "C:\path\to\php-security-review\skills\php-security-review" `
          "$env:USERPROFILE\.claude\skills\" -Recurse -Force

New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\commands" | Out-Null
Copy-Item "C:\path\to\php-security-review\commands\phpsec.md" `
          "$env:USERPROFILE\.claude\commands\" -Force
```

#### 방법 4 — 스킬 없이 스크립트만

에이전트 없이 스캐너만 쓰려면 저장소를 아무 곳에 두고 바로 실행하면 됩니다.

```powershell
git clone https://github.com/1clickmake/php-security-review.git C:\tools\php-security-review
powershell -ExecutionPolicy Bypass -File "C:\tools\php-security-review\skills\php-security-review\scripts\scan.ps1" -Path C:\work\my-site
```

#### 설치 확인

```powershell
Test-Path "$env:USERPROFILE\.config\opencode\skills\php-security-review\SKILL.md"
Test-Path "$env:USERPROFILE\.config\opencode\commands\phpsec.md"
```

둘 다 `True`가 나오면 설치 완료입니다. 에이전트를 재시작하면 `/phpsec` 커맨드가 보입니다.

### 사용법

#### 1) `/phpsec` — 가장 간단

```text
/phpsec C:\work\my-site
```

버전 대조(Step 0.5) → 스캔 → 데이터 흐름 추적 → 보고서 순으로 자동 진행합니다.

```text
/phpsec C:\work\my-site High 이상만, theme/ 중심으로
```

처럼 범위를 자연어로 덧붙여도 됩니다.

#### 2) 스킬 직접 호출

```text
@php-security-review
이 프로젝트 PHP 8.3이야. 배포 전 보안 검수 해줘.
```

> 이 스킬은 `metadata.opencode/autoinvoke: false` 로 설정되어 **자동 호출되지 않습니다.**
> 자연어로만 요청하면 로드되지 않을 수 있으므로 `@php-security-review` 또는 `/phpsec` 로 명시 호출하세요.

#### 3) 스캐너 단독 실행

```powershell
$scan = "$env:USERPROFILE\.config\opencode\skills\php-security-review\scripts\scan.ps1"

powershell -ExecutionPolicy Bypass -File $scan `
  -Path C:\work\my-site `
  -MinSeverity High `
  -MaxPerRule 10 `
  -Csv "$env:TEMP\scan-report.csv"
```

| 옵션 | 기본값 | 설명 |
|---|---|---|
| `-Path` | `.` | 검수 대상 루트 |
| `-Exclude` | `vendor,node_modules,.git,tests,...` | 제외 디렉터리명 배열 |
| `-MaxPerRule` | `30` | 규칙당 최대 출력 건수 (노이즈 제어) |
| `-Csv` | 없음 | 결과를 CSV로 저장 (프로젝트 밖 권장) |
| `-Encoding` | `Auto` | `Auto` / `UTF8` / `Default`(CP949) / `OEM` |
| `-MinSeverity` | `All` | `Critical` / `High` / `Medium` / `Low` / `All` |

출력 예:

```text
소스 인코딩: UTF8

대상: C:\work\my-site
PHP 파일: 250개 / 후보: 17건

Severity Rule             File                          Line Code
-------- ----             ----                          ---- ----
Critical DESERIALIZE      theme\shop\item.php             27 $info = unserialize($row['meta']);
High     XSS-ECHO         theme\board\view.php            41 echo $_GET['q'];
```

> 스캐너 결과는 **후보**입니다. 확정은 에이전트(또는 사람)가 데이터 흐름을 추적해 내립니다.

#### 4) 버전·CVE 대조 단독 실행

```powershell
$vc = "$env:USERPROFILE\.config\opencode\skills\php-security-review\scripts\version-check.ps1"

# 로컬 그누보드 버전 + 최신 릴리스 대조
powershell -ExecutionPolicy Bypass -File $vc -Path C:\work\my-site

# PHP 버전까지 판정 (PHP2Shell 등)
powershell -ExecutionPolicy Bypass -File $vc -Path C:\work\my-site -PhpVersion 8.2.30

# 도메인만으로 PHP 버전 추정 (HTTP 헤더 → /install/ 페이지)
powershell -ExecutionPolicy Bypass -File $vc -Path C:\work\my-site -Domain example.com

# 오프라인 / GitHub API 레이트리밋 회피
powershell -ExecutionPolicy Bypass -File $vc -Path C:\work\my-site -SkipLatest
```

| 옵션 | 설명 |
|---|---|
| `-Path` | 그누보드 루트 (`version.php` 가 있는 곳) |
| `-PhpVersion` | 서버 PHP 버전. 호스팅 관리자 페이지에서 확인한 값 |
| `-Domain` | 도메인. `X-Powered-By` 헤더와 `/install/` 페이지로 PHP 버전 추정 |
| `-SkipLatest` | GitHub 최신 릴리스 조회 생략 |

출력 예:

```text
== 1. 로컬 버전 ==
그누보드      : 5.5.8.2.3
영카트        : 5.4.5.5.1

== 2. PHP 버전 / PHP2Shell ==
PHP 버전      : 8.4.27  (출처: HTTP 헤더)
판정          : [양호] 8.4.27 이상 (해당 브랜치 패치됨)

== 3. 그누보드 최신 버전 대조 ==
최신 릴리스   : 5.6.43 (2026-10-14)
판정          : [위험] 5.6.43 버전 뒤처짐 — 보안패치 누락 가능
```

### 보고서 형식

```markdown
## 즉시 조치 (버전)
| 항목 | 현재 | 필요 | 판정 |
|---|---|---|---|
| PHP | 8.2.30 | 8.2.35 | Critical |
| 그누보드 | 5.5.8.2.3 | 5.6.43 | High |

## 요약
| 등급 | 건수 |
|---|---|
| Critical | 1 |
| High | 3 |

## 발견 항목
### [C-1] 제목 (Critical)
- 위치: `path/file.php:42`
- 유형: SQL Injection (CWE-89)
- 데이터 흐름: `$_GET['id']` → 문자열 결합 → `PDO::query`
- 도달 조건: 비인증, `?id=` 파라미터
- 영향: DB 전체 읽기/쓰기
- 패치: (before/after 코드)
- 재검증: `php -l` + 흐름 재추적
```

전체 예시: [`examples/report-sample.md`](examples/report-sample.md)

### 심각도 기준

| 등급 | 기준 |
|---|---|
| Critical | 비인증 원격 코드 실행 / 파일 쓰기 / 인증 우회 / DB 전체 유출 |
| High | 인증 후 권한 상승, 저장형 XSS, 제한적 SQLi, LFI, 실서비스 하드코딩 시크릿 |
| Medium | 반사형 XSS, CSRF, 정보 노출, 세션 쿠키 플래그 누락 |
| Low | 강화 권고, 디버그 출력 잔존, 보안 용도가 아닌 약한 난수 |

### 한계 (정직하게)

- **휴리스틱입니다.** 스캐너는 후보를 뽑을 뿐, 확정하지 않습니다. 오탐/누락이 모두 가능합니다.
- **코어 CVE는 코드 검사로 잡히지 않습니다.** PHP 코어·그누보드 코어 취약점은 버전 대조와 업데이트로만 해결됩니다.
- **`advisories.md` 는 스냅샷입니다.** 2026-10-28 기준이며, 검수 시점에 웹으로 최신 정보를 확인해야 합니다.
- **동적 분석이 아닙니다.** 실제 요청을 보내는 DAST가 아닙니다.
- **자동 수정하지 않습니다.** 패치 코드는 제시만 하고, 적용은 사용자 승인 후 최소 diff로 합니다.
- **CP949 레거시 사이트**는 Windows PowerShell 5.1 사용을 권장합니다. PowerShell 7은 `Default` 인코딩 의미가 달라 한글이 깨질 수 있습니다.

### 업데이트

```powershell
cd C:\path\to\php-security-review
git pull
Copy-Item ".\skills\php-security-review" "$env:USERPROFILE\.config\opencode\skills\" -Recurse -Force
Copy-Item ".\commands\phpsec.md" "$env:USERPROFILE\.config\opencode\commands\" -Force
```

CVE 스냅샷 갱신 주기: **분기 1회** 또는 검수 시점. 절차는 `references/advisories.md` 5장 참고.

### 기여

- 버그/오탐 제보: GitHub Issues
- 규칙 추가: `scripts/scan.ps1` 의 `$rules` 배열에 `Id` / `Severity` / `Note` / `Rx` 추가
- Linux/macOS용 bash 스캐너 PR 환영 (현재 PowerShell 우선)

### 라이선스

[MIT](LICENSE) © 2026 cmake

---

## English

### What this is

A **security review skill** for AI coding agents (OpenCode / Claude Code) targeting **PHP 8+** and **Gnuboard5** codebases.

It combines three layers:

1. **Code** — a 37-rule heuristic scanner plus a mandatory source → sink data-flow verification workflow.
2. **Version** — PHP core CVE and Gnuboard5 patch-level checks (`version-check.ps1`).
3. **Dependencies** — `composer audit` integration when available.

It does not just grep. Every candidate is either confirmed with a concrete data-flow path or downgraded to "needs verification".

### Requirements

| Item | Required | Notes |
|---|---|---|
| Windows PowerShell 5.1+ | ✅ | Preinstalled on Windows 10/11. PowerShell 7 works too |
| OpenCode or Claude Code | ✅ | Any agent supporting skills. Scripts can also run standalone |
| PHP CLI | ⬜ | Only for `php -l` |
| Git | ⬜ | Only for cloning |
| **Prerequisite skills** | ❌ | **None.** Fully self-contained |

### Install (OpenCode, global)

```powershell
git clone https://github.com/1clickmake/php-security-review.git "$env:TEMP\php-security-review"

New-Item -ItemType Directory -Force "$env:USERPROFILE\.config\opencode\skills" | Out-Null
Copy-Item "$env:TEMP\php-security-review\skills\php-security-review" `
          "$env:USERPROFILE\.config\opencode\skills\" -Recurse -Force

New-Item -ItemType Directory -Force "$env:USERPROFILE\.config\opencode\commands" | Out-Null
Copy-Item "$env:TEMP\php-security-review\commands\phpsec.md" `
          "$env:USERPROFILE\.config\opencode\commands\" -Force

Remove-Item "$env:TEMP\php-security-review" -Recurse -Force
```

For Claude Code, use `$env:USERPROFILE\.claude\skills\` and `$env:USERPROFILE\.claude\commands\`.
Project-local install: `.opencode\skills\` and `.opencode\commands\`.

> The skill ID comes from the **directory name** (`php-security-review`), not the frontmatter `name`.

### Usage

```text
/phpsec C:\work\my-site
```

or invoke explicitly:

```text
@php-security-review
Review this PHP project before deployment.
```

Auto-invocation is disabled (`metadata.opencode/autoinvoke: false`), so call it explicitly.

Standalone scanner:

```powershell
powershell -ExecutionPolicy Bypass -File ".\skills\php-security-review\scripts\scan.ps1" `
  -Path C:\work\my-site -MinSeverity High -MaxPerRule 10 -Csv "$env:TEMP\scan.csv"
```

Standalone version check:

```powershell
powershell -ExecutionPolicy Bypass -File ".\skills\php-security-review\scripts\version-check.ps1" `
  -Path C:\work\my-site -PhpVersion 8.2.30 -Domain example.com
```

### Scanner options

| Option | Default | Description |
|---|---|---|
| `-Path` | `.` | Target root |
| `-Exclude` | vendor, node_modules, .git, ... | Directory names to skip |
| `-MaxPerRule` | `30` | Max findings per rule |
| `-Csv` | none | Save results as CSV |
| `-Encoding` | `Auto` | `Auto` / `UTF8` / `Default` (CP949) / `OEM` |
| `-MinSeverity` | `All` | `Critical` / `High` / `Medium` / `Low` / `All` |

### Limitations

- Heuristic scanner: candidates only, not proof. False positives and false negatives are possible.
- Core CVEs (PHP interpreter, Gnuboard5 core) cannot be found by source inspection — use the version gate and update.
- `references/advisories.md` is a dated snapshot (2026-10-28). Re-check upstream advisories when you run a review.
- Not a DAST. No live attack traffic is sent.
- No automatic fixes. Patches are proposed, applied only on request.
- Windows-first. Legacy CP949 sites should use Windows PowerShell 5.1.

### License

[MIT](LICENSE) © 2026 cmake
