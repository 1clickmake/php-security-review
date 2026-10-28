# PHP 보안 검수 결과 — example-shop (2026-10-28)

> 예시 보고서입니다. 실제 사이트 정보는 포함되어 있지 않습니다.

## 즉시 조치 (버전)

| 항목 | 현재 | 필요 | 판정 | 조치 |
|---|---|---|---|---|
| PHP | 8.2.30 | **8.2.35** | 🔴 Critical | PHP2Shell (CVE-2026-109618/109619) 미패치. 호스팅에 즉시 패치 요청 |
| 그누보드 | 5.5.8.2.3 | **5.6.43** | 🟠 High | 보안패치 다수 누락. 백업 후 업데이트 검토 |
| `install/` | 존재 | 삭제/차단 | 🟠 High | `gnuboard5.sql` 200 응답 확인 |

## 요약

| 등급 | 건수 |
|---|---|
| Critical | 1 |
| High | 2 |
| Medium | 1 |
| Low | 2 |
| 확인 필요 | 1 |

## 발견 항목

### [C-1] 상품 상세 조회 SQL Injection (Critical)

- **위치**: `theme/basic/shop/item.php:38`
- **유형**: SQL Injection (CWE-89)
- **데이터 흐름**:
  ```text
  $_GET['it_id']
    → $it_id = $_GET['it_id']            (검증 없음)
    → $sql = "SELECT * FROM shop_item WHERE it_id = '$it_id'"
    → sql_query($sql)
  ```
- **도달 조건**: 비인증, `?it_id=` 파라미터
- **영향**: DB 전체 읽기. `UNION` 기반으로 회원 테이블(해시 포함) 추출 가능
- **재현 시나리오**: `it_id` 에 따옴표를 포함한 값을 전달했을 때 SQL 오류 또는 추가 row 반환
- **패치**:
  ```php
  // before
  $it_id = $_GET['it_id'];
  $sql = "SELECT * FROM shop_item WHERE it_id = '$it_id'";

  // after (그누보드 코어 헬퍼 사용)
  $it_id = preg_replace('/[^a-z0-9_\-]/i', '', $_GET['it_id']);
  $sql = "SELECT * FROM shop_item WHERE it_id = '" . sql_real_escape_string($it_id) . "'";
  ```
  > 가능하면 PDO prepared statement로 전환하는 것이 최선입니다.
- **재검증**: `php -l` 통과, 동일 흐름 재추적 시 싱크 직전 이스케이프 확인

### [H-1] 게시판 목록 반사형 XSS (High)

- **위치**: `theme/basic/skin/board/gallery/list.skin.php:52`
- **유형**: Reflected XSS (CWE-79)
- **데이터 흐름**:
  ```text
  $_GET['q']
    → echo $_GET['q']                    (이스케이프 없음)
    → HTML 본문 출력
  ```
- **도달 조건**: 비인증, `?q=` 파라미터
- **영향**: 피해자 브라우저에서 임의 스크립트 실행. 세션 쿠키가 `HttpOnly`가 아니면 탈취 가능
- **패치**:
  ```php
  // before
  echo $_GET['q'];

  // after
  echo htmlspecialchars($_GET['q'], ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
  ```
- **재검증**: `php -l` 통과, `get_search_string()` 등 코어 헬퍼가 이미 이스케이프하는지 확인

### [H-2] 결제 정보 역직렬화 (High)

- **위치**: `theme/basic/shop/orderinquiryview.php:554`
- **유형**: Insecure Deserialization (CWE-502)
- **데이터 흐름**:
  ```text
  DB: od_cash_info
    → unserialize($od['od_cash_info'])
    → 객체/배열 복원
  ```
- **도달 조건**: 인증 사용자(본인 주문 조회). DB 쓰기 경로가 있으면 저장형 공격 가능
- **영향**: DB 조작이 가능한 공격자가 임의 객체 주입 시 코드 실행 가능
- **패치**:
  ```php
  // before
  $cash = unserialize($od['od_cash_info']);

  // after
  $cash = unserialize($od['od_cash_info'], ['allowed_classes' => false]);
  if (!is_array($cash)) { $cash = []; }
  ```
- **재검증**: `php -l`, 주문 조회 화면 동작 확인 (배열 접근 키 유지)

### [M-1] 세션 쿠키 플래그 누락 (Medium)

- **위치**: `theme/basic/head.php:12` (또는 `php.ini`)
- **유형**: Session Cookie without HttpOnly/Secure/SameSite (CWE-1004/614)
- **현황**: `session.cookie_httponly=0`, `session.cookie_secure=0`, `session.cookie_samesite` 미설정
- **영향**: XSS 성공 시 세션 탈취, CSRF 방어 약화
- **패치** (`php.ini` 또는 부트스트랩):
  ```php
  ini_set('session.cookie_httponly', '1');
  ini_set('session.cookie_secure', '1');
  ini_set('session.cookie_samesite', 'Lax');
  ini_set('session.use_strict_mode', '1');
  ```

### [L-1] 디버그 출력 잔존 (Low)

- **위치**: `theme/basic/shop/item.php:71`
- **유형**: Information Exposure (CWE-200)
- **현황**: `print_r($item);` 주석 처리되지 않은 상태
- **패치**: 삭제 또는 `if (defined('_DEBUG')) { ... }` 로 감싸기

### [L-2] 약한 난수 (Low)

- **위치**: `theme/basic/shop/coupon.php:23`
- **유형**: Insufficient Randomness (CWE-338)
- **현황**: `mt_rand()` 로 쿠폰 번호 생성
- **패치**:
  ```php
  // before
  $code = 'CP' . mt_rand(100000, 999999);

  // after
  $code = 'CP' . bin2hex(random_bytes(4));
  ```
  > 보안 목적이 아니면 Low. 쿠폰 추측이 가능하면 High로 상향.

## 확인 필요 (증거 부족)

### [Q-1] `lib/common.lib.php` 최근 수정

- **위치**: `lib/common.lib.php` (mtime 2026-10-26)
- **현황**: 코어 파일이 최근 수정됨. 공식 5.5.8.2.3 원본과 diff 필요
- **가능성**: ① 정상 패치 ② 커스텀 수정 ③ 변조
- **조치**: 공식 배포본과 `git diff --no-index` 비교 후 판정

## 강화 권고 (취약점 아님)

| 항목 | 내용 |
|---|---|
| 보안 헤더 | `X-Frame-Options: SAMEORIGIN`, `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin` |
| `display_errors` | 운영에서 `Off`, `log_errors=On` |
| `install/` | 삭제 또는 웹 접근 차단 |
| `data/` | `.htaccess` 또는 서버 deny 규칙 확인 |
| 파일 업로드 | 웹루트 밖 저장 + 실행 불가 확장자 차단 |
| 의존성 | `composer audit` 정기 실행 |

## 검수 범위와 한계

- 대상: `theme/` 250개 PHP 파일 (코어 제외)
- 스캐너: 37개 규칙, `-MinSeverity High`
- 확인: 후보 17건 중 6건 데이터 흐름 추적, 5건 확정 / 1건 확인 필요
- 미수행: 실제 HTTP 공격 트래픽, 동적 분석(DAST), 코어 전체 diff
- CVE 정보 기준일: 2026-10-28
