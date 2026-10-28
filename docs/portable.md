# 다른 AI 에이전트에서 사용하기 (Portable)

`php-security-review`는 **Agent Skills 오픈 표준**(`SKILL.md` + `references/` + `scripts/`)을 따릅니다.
같은 폴더를 각 에이전트의 스킬 경로에 복사하면 됩니다.

- [호환성 한눈에 보기](#호환성-한눈에-보기)
- [자동 설치 스크립트](#자동-설치-스크립트)
- [에이전트별 설치](#에이전트별-설치)
- [스킬을 지원하지 않는 환경](#스킬을-지원하지-않는-환경)
- [공통 주의사항](#공통-주의사항)

---

## 호환성 한눈에 보기

| 에이전트 | 스킬 지원 | 설치 경로 (전역 / 프로젝트) | 호출 |
|---|---|---|---|
| **OpenCode** | ✅ | `~/.config/opencode/skills/` / `.opencode/skills/` | `@php-security-review`, `/phpsec` |
| **Claude Code** | ✅ | `~/.claude/skills/` / `.claude/skills/` | 자동 또는 `/phpsec` |
| **Codex CLI / ChatGPT 데스크톱** | ✅ | `~/.agents/skills/` / `.agents/skills/` | `/skills`, `$php-security-review` |
| **Google Antigravity** | ✅ | `~/.gemini/config/skills/` / `.agents/skills/` | 스킬 목록에서 선택 |
| **Cursor** | ✅ | `~/.cursor/skills/` / `.cursor/skills/`, `.agents/skills/` | `/php-security-review` |
| **GitHub Copilot** | ✅ | `~/.copilot/skills/` / `.github/skills/`, `.agents/skills/` | 자동 또는 스킬 패널 |
| **Gemini CLI** (레거시) | ✅ | `~/.gemini/skills/` / `.gemini/skills/` | 자동 |
| **ChatGPT 웹** | △ | 스킬 직접 설치 불가 | Custom GPT / Project에 지침+지식 파일 |
| **Claude 웹 / Gemini 웹** | △ | 스킬 직접 설치 불가 | 프롬프트에 요약 붙여넣기 |

> `.agents/skills/` 는 Codex · Cursor · Copilot · Antigravity가 공통으로 읽는 경로입니다. 한 번만 복사하면 여러 에이전트에서 사용할 수 있습니다.

---

## 자동 설치 스크립트

### Windows (PowerShell)

```powershell
git clone https://github.com/1clickmake/php-security-review.git "$env:TEMP\psr"
cd "$env:TEMP\psr"

# 전체 에이전트에 전역 설치
.\scripts\install.ps1 -Target all -Scope global

# 특정 에이전트 + 슬래시 커맨드까지
.\scripts\install.ps1 -Target opencode,claude -Scope global -WithCommand

# 특정 프로젝트에 설치
.\scripts\install.ps1 -Target cursor -Scope project -ProjectPath C:\work\my-site

# 설치 경로만 미리 확인
.\scripts\install.ps1 -List -Target all -Scope global
```

### macOS / Linux

```bash
git clone https://github.com/1clickmake/php-security-review.git /tmp/psr
cd /tmp/psr

./scripts/install.sh --target all --scope global
./scripts/install.sh --target cursor --scope project --project /path/to/site --with-command
./scripts/install.sh --list --target all --scope global
```

### 대상 이름

| `-Target` | 설치 위치 |
|---|---|
| `opencode` | `~/.config/opencode/skills/` 또는 `.opencode/skills/` |
| `claude` | `~/.claude/skills/` 또는 `.claude/skills/` |
| `codex` | `~/.agents/skills/` 또는 `.agents/skills/` |
| `cursor` | `~/.cursor/skills/` 또는 `.cursor/skills/` |
| `copilot` | `~/.copilot/skills/` 또는 `.github/skills/` |
| `antigravity` | `~/.gemini/config/skills/` 또는 `.agents/skills/` |
| `all` | 위 6개 전부 |

---

## 에이전트별 설치

### 1. OpenCode

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.config\opencode\skills" | Out-Null
Copy-Item ".\skills\php-security-review" "$env:USERPROFILE\.config\opencode\skills\" -Recurse -Force

New-Item -ItemType Directory -Force "$env:USERPROFILE\.config\opencode\commands" | Out-Null
Copy-Item ".\commands\phpsec.md" "$env:USERPROFILE\.config\opencode\commands\" -Force
```

```text
/phpsec C:\work\my-site
@php-security-review
```

`metadata.opencode/autoinvoke: false` 로 자동 호출을 끕니다. 명시 호출하세요.

### 2. Claude Code

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\skills" | Out-Null
Copy-Item ".\skills\php-security-review" "$env:USERPROFILE\.claude\skills\" -Recurse -Force

New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\commands" | Out-Null
Copy-Item ".\commands\phpsec.md" "$env:USERPROFILE\.claude\commands\" -Force
```

```text
/phpsec C:\work\my-site
```

> Claude Code는 `description` 기반으로 **자동 로드**될 수 있습니다. 원치 않으면 프로젝트 설정에서 스킬 호출 정책을 조정하세요.

### 3. Codex CLI / ChatGPT 데스크톱 앱

```powershell
# 프로젝트에 설치
New-Item -ItemType Directory -Force ".agents\skills" | Out-Null
Copy-Item ".\skills\php-security-review" ".agents\skills\" -Recurse -Force

# 또는 사용자 전역
New-Item -ItemType Directory -Force "$env:USERPROFILE\.agents\skills" | Out-Null
Copy-Item ".\skills\php-security-review" "$env:USERPROFILE\.agents\skills\" -Recurse -Force
```

```text
/skills
$php-security-review 이 프로젝트 보안 검수해줘
```

- Codex는 `.agents/skills/` 를 현재 디렉터리부터 저장소 루트까지 스캔합니다.
- `~/.codex/skills/` 도 레거시 경로로 지원됩니다.
- `agents/openai.yaml` 의 `policy.allow_implicit_invocation: false` 로 자동 호출을 끕니다.
- ChatGPT **데스크톱 앱**은 사이드바의 **Skills**에서 확인합니다. `@` 로 스킬을 선택할 수 있습니다.

### 4. Google Antigravity

```powershell
# 워크스페이스
New-Item -ItemType Directory -Force ".agents\skills" | Out-Null
Copy-Item ".\skills\php-security-review" ".agents\skills\" -Recurse -Force

# 전역
New-Item -ItemType Directory -Force "$env:USERPROFILE\.gemini\config\skills" | Out-Null
Copy-Item ".\skills\php-security-review" "$env:USERPROFILE\.gemini\config\skills\" -Recurse -Force
```

- Antigravity 2.0 / CLI / IDE 모두 `SKILL.md` 오픈 표준을 지원합니다.
- 레거시 경로 `.agent/skills/`, `~/.gemini/antigravity/skills/` 도 인식됩니다.
- 규칙 파일은 `AGENTS.md`, `GEMINI.md`, `.agents/rules/*.md` 입니다.
- 에이전트가 셸 명령을 실행할 때 승인 정책이 있으므로, 첫 실행 시 `scan.ps1` 실행을 허용해야 합니다.

### 5. Cursor

```powershell
# 프로젝트
New-Item -ItemType Directory -Force ".cursor\skills" | Out-Null
Copy-Item ".\skills\php-security-review" ".cursor\skills\" -Recurse -Force

# 전역
New-Item -ItemType Directory -Force "$env:USERPROFILE\.cursor\skills" | Out-Null
Copy-Item ".\skills\php-security-review" "$env:USERPROFILE\.cursor\skills\" -Recurse -Force
```

```text
/php-security-review
```

- Cursor는 `.cursor/skills/`, `.agents/skills/`, `~/.cursor/skills/` 를 읽습니다.
- `.claude/skills/`, `.codex/skills/` 도 호환 경로로 읽습니다.
- 저장소에 포함된 `.cursor/rules/php-security-review.mdc` 는 PHP 파일 작업 시 규칙을 주입합니다.

### 6. GitHub Copilot

```powershell
# 프로젝트 (Copilot code review / cloud agent 포함)
New-Item -ItemType Directory -Force ".github\skills" | Out-Null
Copy-Item ".\skills\php-security-review" ".github\skills\" -Recurse -Force

# 개인 전역
New-Item -ItemType Directory -Force "$env:USERPROFILE\.copilot\skills" | Out-Null
Copy-Item ".\skills\php-security-review" "$env:USERPROFILE\.copilot\skills\" -Recurse -Force
```

- Copilot은 `.github/skills/`, `.claude/skills/`, `.agents/skills/` 를 읽습니다.
- `.github/copilot-instructions.md` 는 항상 적용되는 저장소 지침입니다.

### 7. Gemini CLI (레거시)

```powershell
New-Item -ItemType Directory -Force ".gemini\skills" | Out-Null
Copy-Item ".\skills\php-security-review" ".gemini\skills\" -Recurse -Force
```

> 2026-06-18 이후 Gemini CLI는 Antigravity CLI로 대체되었습니다. 신규 환경은 Antigravity 경로를 사용하세요.

---

## 스킬을 지원하지 않는 환경

### ChatGPT 웹 (chatgpt.com)

ChatGPT **웹**은 로컬 스킬 폴더를 직접 읽지 못합니다. 두 가지 방법이 있습니다.

**① Custom GPT / Project (권장)**

1. ChatGPT → **Explore GPTs → Create** (또는 **Projects → New project**)
2. **Instructions** 에 [`portable/chatgpt-instructions.md`](../portable/chatgpt-instructions.md) 내용을 붙여넣기
3. **Knowledge** 에 다음 파일 업로드
   - `skills/php-security-review/SKILL.md`
   - `skills/php-security-review/references/checklist.md`
   - `skills/php-security-review/references/gnuboard.md`
   - `skills/php-security-review/references/advisories.md`
   - `skills/php-security-review/references/php8-hardening.md`
4. 대화에서 코드/파일을 첨부해 검수 요청

**② 프롬프트 붙여넣기**

[`portable/chat-prompt.md`](../portable/chat-prompt.md) 를 코드와 함께 붙여넣습니다.

> ChatGPT 웹은 PowerShell을 실행할 수 없습니다. `scan.ps1`을 실행한 것처럼 말하지 않도록 지침에 명시되어 있습니다. 스캔이 필요하면 로컬에서 실행한 CSV를 붙여넣으세요.

### Claude 웹 / Gemini 웹

같은 방식으로 `portable/chat-prompt.md` 를 붙여넣거나, Project/대화 지침에 `chatgpt-instructions.md` 내용을 넣습니다.

### 에이전트 없이

```powershell
powershell -ExecutionPolicy Bypass -File ".\skills\php-security-review\scripts\scan.ps1" -Path C:\work\my-site -MinSeverity High
powershell -ExecutionPolicy Bypass -File ".\skills\php-security-review\scripts\version-check.ps1" -Path C:\work\my-site -PhpVersion 8.3.12
```

---

## 공통 주의사항

### 1. 폴더명 = 스킬 ID

`SKILL.md`의 `name`이 아니라 **폴더명**이 스킬 ID입니다. 반드시 `php-security-review` 를 유지하세요.

```text
skills/php-security-review/SKILL.md      ✅
skills/PHP Security Review/SKILL.md      ❌ (공백/대문자)
```

### 2. PowerShell 의존

스캐너와 버전 대조는 PowerShell 스크립트입니다.

| OS | 필요 |
|---|---|
| Windows | PowerShell 5.1+ (기본 탑재) |
| macOS / Linux | PowerShell 7 (`pwsh`) |
| CP949 레거시 사이트 | Windows PowerShell 5.1 권장 |

PowerShell이 없으면 스킬의 **워크플로와 체크리스트**만 사용할 수 있습니다.

### 3. 자동 호출 정책

| 에이전트 | 설정 |
|---|---|
| OpenCode | `metadata.opencode/autoinvoke: false` |
| Codex / ChatGPT 데스크톱 | `agents/openai.yaml` → `policy.allow_implicit_invocation: false` |
| Claude Code / Cursor / Copilot / Antigravity | 에이전트 설정에서 호출 정책 확인 |

### 4. 업데이트

```powershell
cd C:\path\to\php-security-review
git pull
.\scripts\install.ps1 -Target all -Scope global
```

### 5. 문제 해결

| 증상 | 조치 |
|---|---|
| 스킬 목록에 안 보임 | 폴더 깊이 확인 (`skills/<name>/SKILL.md` 정확히 2단계) |
| 스킬은 보이나 호출 안 됨 | 명시 호출 (`/phpsec`, `$php-security-review`, `@php-security-review`) |
| 스크립트 실행 거부 | 에이전트 승인 정책에서 PowerShell 허용 |
| 한글 깨짐 | Windows PowerShell 5.1 + `-Encoding Auto` |
