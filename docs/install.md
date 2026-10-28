# 설치 가이드 (Installation)

이 문서는 `php-security-review` 스킬을 에이전트에 설치하는 전체 절차를 다룹니다.

- [0. 사전 확인](#0-사전-확인)
- [1. OpenCode 전역 설치](#1-opencode-전역-설치)
- [2. OpenCode 프로젝트별 설치](#2-opencode-프로젝트별-설치)
- [3. Claude Code 설치](#3-claude-code-설치)
- [4. 스킬 없이 스크립트만 사용](#4-스킬-없이-스크립트만-사용)
- [5. 설치 확인](#5-설치-확인)
- [6. 업데이트](#6-업데이트)
- [7. 삭제](#7-삭제)
- [8. 문제 해결](#8-문제-해결)

---

## 0. 사전 확인

### 0.1 필수 선행 스킬: 없음

이 스킬은 **독립 실행형**입니다. 다른 스킬을 먼저 설치할 필요가 없습니다.

| 구분 | 필요 여부 | 설명 |
|---|---|---|
| 선행 스킬 | ❌ 없음 | 체크리스트·스캐너·CVE 스냅샷이 저장소에 모두 포함 |
| `frontend-design`, `taste-skill` 등 | ❌ 무관 | UI/디자인용. 이 스킬이 참조하지 않음 |
| MCP 서버 | ❌ 없음 | 외부 MCP 의존 없음 |
| API 키 | ❌ 없음 | GitHub Releases 조회는 익명 API (레이트리밋만 존재) |

### 0.2 도구 확인

Windows PowerShell에서 실행:

```powershell
# PowerShell 버전 (5.1 이상 필요)
$PSVersionTable.PSVersion

# 선택: PHP CLI (문법 검사용)
php -v

# 선택: Git (저장소 clone용)
git --version
```

기대 결과:

```text
Major  Minor  Build  Revision
-----  -----  -----  --------
5      1      ...    ...
```

> PowerShell 7(`pwsh`)도 동작합니다. 단, **CP949(EUC-KR) 레거시 사이트**는 Windows PowerShell 5.1을 권장합니다. PowerShell 7은 `-Encoding Default`가 UTF-8을 의미하므로 한글 주석이 깨질 수 있습니다.

### 0.3 실행 정책

스크립트는 `-ExecutionPolicy Bypass`로 실행하므로 시스템 정책을 변경할 필요가 없습니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\script.ps1
```

---

## 1. OpenCode 전역 설치

모든 프로젝트에서 `/phpsec`와 `@php-security-review`를 쓰려면 전역에 설치합니다.

### 1.1 저장소 받기

```powershell
git clone https://github.com/1clickmake/php-security-review.git "$env:TEMP\php-security-review"
```

Git이 없으면 GitHub에서 ZIP으로 받아 압축을 풀어도 됩니다.

### 1.2 스킬 복사

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.config\opencode\skills" | Out-Null

Copy-Item "$env:TEMP\php-security-review\skills\php-security-review" `
          "$env:USERPROFILE\.config\opencode\skills\" -Recurse -Force
```

복사 후 구조:

```text
%USERPROFILE%\.config\opencode\skills\php-security-review\
├── SKILL.md
├── references\
│   ├── advisories.md
│   ├── checklist.md
│   ├── gnuboard.md
│   └── php8-hardening.md
└── scripts\
    ├── scan.ps1
    └── version-check.ps1
```

> **디렉터리 이름을 바꾸지 마세요.** OpenCode에서 스킬 ID는 frontmatter의 `name`이 아니라 **폴더명**입니다. `php-security-review`가 ID가 됩니다.

### 1.3 슬래시 커맨드 복사

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.config\opencode\commands" | Out-Null

Copy-Item "$env:TEMP\php-security-review\commands\phpsec.md" `
          "$env:USERPROFILE\.config\opencode\commands\" -Force
```

### 1.4 정리

```powershell
Remove-Item "$env:TEMP\php-security-review" -Recurse -Force
```

### 1.5 에이전트 재시작

OpenCode를 재시작하면 `/phpsec` 커맨드가 인식됩니다.

### macOS / Linux (OpenCode)

```bash
git clone https://github.com/1clickmake/php-security-review.git /tmp/php-security-review

mkdir -p ~/.config/opencode/skills ~/.config/opencode/commands
cp -R /tmp/php-security-review/skills/php-security-review ~/.config/opencode/skills/
cp /tmp/php-security-review/commands/phpsec.md ~/.config/opencode/commands/

rm -rf /tmp/php-security-review
```

> 스캐너는 PowerShell 스크립트입니다. macOS/Linux에서는 `pwsh`(PowerShell 7)가 필요합니다. `pwsh`가 없으면 스킬의 워크플로(체크리스트·데이터 흐름 추적)만 사용할 수 있습니다.

---

## 2. OpenCode 프로젝트별 설치

특정 프로젝트에서만 쓰거나, 팀 저장소에 포함해 공유하려면 프로젝트 루트에 설치합니다.

```powershell
cd C:\work\my-project

New-Item -ItemType Directory -Force ".opencode\skills" | Out-Null
New-Item -ItemType Directory -Force ".opencode\commands" | Out-Null

Copy-Item "C:\path\to\php-security-review\skills\php-security-review" `
          ".opencode\skills\" -Recurse -Force

Copy-Item "C:\path\to\php-security-review\commands\phpsec.md" `
          ".opencode\commands\" -Force
```

결과:

```text
my-project\
└── .opencode\
    ├── skills\php-security-review\...
    └── commands\phpsec.md
```

> 프로젝트별 스킬은 전역 스킬보다 우선합니다. 팀원과 공유하려면 `.opencode\`를 git에 커밋하세요.

---

## 3. Claude Code 설치

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\skills" | Out-Null
New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\commands" | Out-Null

Copy-Item "C:\path\to\php-security-review\skills\php-security-review" `
          "$env:USERPROFILE\.claude\skills\" -Recurse -Force

Copy-Item "C:\path\to\php-security-review\commands\phpsec.md" `
          "$env:USERPROFILE\.claude\commands\" -Force
```

프로젝트별로는 `.claude\skills\`, `.claude\commands\`를 사용합니다.

> Claude Code는 `SKILL.md`의 frontmatter를 읽습니다. `metadata.opencode/autoinvoke`는 OpenCode 전용 키이며 Claude Code에서는 무시됩니다.

---

## 4. 스킬 없이 스크립트만 사용

에이전트 없이 스캐너/버전 대조만 쓰는 방법입니다.

```powershell
git clone https://github.com/1clickmake/php-security-review.git C:\tools\php-security-review
```

스캔:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\tools\php-security-review\skills\php-security-review\scripts\scan.ps1" `
  -Path C:\work\my-site `
  -MinSeverity High `
  -Csv "$env:TEMP\scan.csv"
```

버전 대조:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\tools\php-security-review\skills\php-security-review\scripts\version-check.ps1" `
  -Path C:\work\my-site `
  -PhpVersion 8.2.30
```

CSV는 Excel에서 열 수 있습니다. 컬럼: `Severity`, `Rule`, `File`, `Line`, `Code`, `Note`.

---

## 5. 설치 확인

### 5.1 파일 확인

```powershell
$skill = "$env:USERPROFILE\.config\opencode\skills\php-security-review"
@(
  "$skill\SKILL.md",
  "$skill\references\checklist.md",
  "$skill\references\php8-hardening.md",
  "$skill\references\gnuboard.md",
  "$skill\references\advisories.md",
  "$skill\scripts\scan.ps1",
  "$skill\scripts\version-check.ps1",
  "$env:USERPROFILE\.config\opencode\commands\phpsec.md"
) | ForEach-Object { "{0,-6} {1}" -f (Test-Path -LiteralPath $_), $_ }
```

모두 `True`여야 합니다.

### 5.2 스크립트 실행 확인

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.config\opencode\skills\php-security-review\scripts\scan.ps1" -Path . -MaxPerRule 1
```

에러 없이 `대상:` / `PHP 파일:` / 결과 표가 나오면 정상입니다.

### 5.3 커맨드 확인

OpenCode 재시작 후 `/` 를 입력했을 때 `phpsec`가 목록에 보이면 완료입니다.

### 5.4 스킬 호출 확인

```text
@php-security-review
설치 확인용입니다. 이 저장소의 SKILL.md 구조만 요약해 주세요.
```

스킬 내용을 읽고 요약하면 정상 로드된 것입니다.

---

## 6. 업데이트

```powershell
cd C:\path\to\php-security-review
git pull

Copy-Item ".\skills\php-security-review" "$env:USERPROFILE\.config\opencode\skills\" -Recurse -Force
Copy-Item ".\commands\phpsec.md" "$env:USERPROFILE\.config\opencode\commands\" -Force
```

에이전트를 재시작합니다.

CVE 스냅샷(`references/advisories.md`)은 **분기 1회** 또는 검수 시점에 갱신하세요. 절차는 해당 파일 5장에 있습니다.

---

## 7. 삭제

```powershell
Remove-Item "$env:USERPROFILE\.config\opencode\skills\php-security-review" -Recurse -Force
Remove-Item "$env:USERPROFILE\.config\opencode\commands\phpsec.md" -Force
```

프로젝트별 설치였다면 해당 프로젝트의 `.opencode\skills\php-security-review`와 `.opencode\commands\phpsec.md`를 지웁니다.

---

## 8. 문제 해결

### 8.1 `이 시스템에서 스크립트를 실행할 수 없습니다` (ExecutionPolicy)

항상 `-ExecutionPolicy Bypass`를 붙이세요.

```powershell
powershell -ExecutionPolicy Bypass -File .\scan.ps1 -Path .
```

시스템 정책을 영구 변경하지 않아도 됩니다.

### 8.2 한글이 깨져 보인다

- **Windows PowerShell 5.1** + `-Encoding Auto`(기본값)를 사용하세요.
- 콘솔 코드페이지 문제면 먼저 `chcp 65001`을 실행합니다.
- 그래도 깨지면 `-Encoding Default`(CP949) 또는 `-Encoding OEM`을 명시합니다.

```powershell
chcp 65001
powershell -ExecutionPolicy Bypass -File .\scan.ps1 -Path . -Encoding Default
```

### 8.3 `/phpsec`가 보이지 않는다

1. `%USERPROFILE%\.config\opencode\commands\phpsec.md` 존재 확인
2. OpenCode 완전 재시작
3. 프로젝트에 `.opencode\commands\`가 있으면 그쪽이 우선인지 확인

### 8.4 `@php-security-review`가 로드되지 않는다

- 폴더명이 정확히 `php-security-review`인지 확인 (frontmatter `name`이 아님)
- `SKILL.md`가 폴더 **바로 아래**에 있는지 확인
  ```text
  skills\php-security-review\SKILL.md      ✅
  skills\php-security-review\src\SKILL.md  ❌
  ```
- 이 스킬은 `autoinvoke: false`입니다. 자연어 요청만으로는 로드되지 않을 수 있으니 명시 호출하세요.

### 8.5 스캔 결과가 너무 많다

```powershell
# High 이상만, 규칙당 5건
... -MinSeverity High -MaxPerRule 5

# 커스텀 영역만
... -Path C:\work\my-site\theme -MinSeverity High
```

그누보드/영카트 코어는 스캔 대상에서 빼고 버전 업데이트로 처리하는 것이 실무적입니다.

### 8.6 `version-check.ps1`이 최신 버전을 못 가져온다

- GitHub API 익명 레이트리밋(시간당 60회)일 수 있습니다.
- `-SkipLatest`로 조회를 생략하고, 로컬 버전만 확인합니다.
- 사내망/프록시 환경이면 `Invoke-RestMethod`가 차단될 수 있습니다.

### 8.7 `php -l`을 못 쓴다

PHP CLI가 없어도 검수는 가능합니다. 문법 검증 단계만 생략되고, 보고서에 "PHP CLI 미설치로 문법 검증 생략"으로 표시됩니다.

### 8.8 스크립트 파일이 깨졌다 (BOM)

`scan.ps1` / `version-check.ps1`은 **UTF-8 BOM**으로 저장되어 있습니다. Windows PowerShell 5.1이 한글 주석을 잘못 해석하지 않도록 하기 위함입니다.

편집 후 BOM이 사라지면 다시 추가하세요.

```powershell
$p = ".\scan.ps1"
$c = Get-Content -Raw -Encoding UTF8 $p
[System.IO.File]::WriteAllText($p, $c, (New-Object System.Text.UTF8Encoding($true)))
```
