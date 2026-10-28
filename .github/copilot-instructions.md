# GitHub Copilot instructions — php-security-review

PHP 보안 검수 요청이 들어오면 이 저장소의 스킬을 사용한다.

## 진입점

- 스킬: `skills/php-security-review/SKILL.md`
- 그누보드 프로필: `skills/php-security-review/references/gnuboard.md`
- 스캐너: `skills/php-security-review/scripts/scan.ps1`
- 버전 대조: `skills/php-security-review/scripts/version-check.ps1`

> Copilot 프로젝트 스킬로 설치했다면 경로는 `.github/skills/php-security-review/` 입니다.

## 순서

1. 버전·CVE 대조 (Step 0.5) — 코드보다 먼저
2. 정적 스캔 — 결과는 후보
3. `source → sink` 데이터 흐름 확인
4. 심각도 판정 + 패치 코드 제시
5. 보고서: 즉시 조치(버전) → 요약 → 항목별 → 확인 필요 → 강화 권고

## 금지

- 증거 없는 Critical 판정
- 그누보드 코어 직접 패치 (버전 업데이트 권고)
- 검수 중 코드 수정·DB 쓰기·공격 트래픽 전송
- 스캐너를 실행하지 않았는데 실행했다고 말하기
