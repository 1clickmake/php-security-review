# AGENTS.md — php-security-review

이 저장소는 **PHP 8+ / 그누보드5 보안 검수 스킬**입니다.
이 파일은 `AGENTS.md`를 읽는 에이전트(Codex, Cursor, Copilot, Antigravity 등)를 위한 진입점입니다.

## 정본 위치

| 자산 | 경로 |
|---|---|
| 스킬 본체 | `skills/php-security-review/SKILL.md` |
| 취약점 카탈로그 | `skills/php-security-review/references/checklist.md` |
| PHP 8 하드닝 | `skills/php-security-review/references/php8-hardening.md` |
| 그누보드 프로필 | `skills/php-security-review/references/gnuboard.md` |
| CVE 스냅샷 | `skills/php-security-review/references/advisories.md` |
| 스캐너 | `skills/php-security-review/scripts/scan.ps1` |
| 버전 대조 | `skills/php-security-review/scripts/version-check.ps1` |

## 작업 지시

PHP 보안 검수 요청을 받으면:

1. `skills/php-security-review/SKILL.md` 를 읽고 워크플로를 따른다.
2. 그누보드 구조(`lib/`, `bbs/`, `adm/`, `skin/`, `extend/`, `data/`, `install/`)가 보이면 `references/gnuboard.md` 를 추가로 읽는다.
3. **Step 0.5(버전·CVE 대조)를 코드 검수보다 먼저** 수행한다.
4. 스캐너를 실행할 수 있으면 실행하고, 결과는 **후보**로만 취급한다.
5. 각 후보의 `source → sink` 를 실제 코드로 확인한 뒤 판정한다.
6. 보고서는 `즉시 조치(버전) → 요약 → 항목별 → 확인 필요 → 강화 권고` 순으로 쓴다.

## 절대 규칙

- 증거 없는 항목을 "취약"으로 단정하지 않는다. `확인 필요`로 분류한다.
- 방어 함수가 **해당 싱크에 맞는지** 따진다 (`intval`은 HTML 출력에 무의미, `htmlspecialchars`는 SQL에 무의미).
- 검수 중 코드 수정, DB 쓰기, 외부 공격 트래픽 전송을 하지 않는다.
- 그누보드 코어(`lib/`, `bbs/`, `adm/`, `shop/`)는 직접 패치하지 말고 **버전 업데이트**를 권고한다.
- `extend/` 의심 파일은 삭제하지 말고 내용을 제시해 확인받는다.
- 패치는 취약 지점 단위 최소 diff로 제시하고, 동작 변경 가능성을 먼저 알린다.

## 설치

```powershell
# 이 저장소를 받은 뒤, 원하는 에이전트에 스킬 복사
.\scripts\install.ps1 -Target all -Scope global
```

에이전트별 경로와 사용법: `docs/portable.md`

## 라이선스

MIT
