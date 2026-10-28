---
name: php-security-review
description: >-
  PHP 8+ 순수 PHP(프레임워크 없음)와 그누보드5/영카트 코드베이스 보안 검수 워크플로.
  SQL 인젝션, XSS, LFI/RFI, 파일 업로드, 역직렬화, 커맨드 인젝션, SSRF, 세션/인증 결함,
  CSRF, 시크릿 하드코딩을 사용자 입력에서 싱크까지 데이터 흐름으로 추적하고, PHP/그누보드
  버전과 알려진 CVE를 대조해 심각도·재현 시나리오·최소 패치를 보고서로 정리한다.
  Triggers: PHP 보안 검수, 그누보드 보안 점검, 취약점 점검, 보안 감사, security review,
  vulnerability audit, 코드 안전성 점검, 배포 전 보안 확인, php security check.
metadata:
  opencode/autoinvoke: false
  author: cmake
  version: "1.1.0"
  php: ">=8.0"
  scope: vanilla-php, gnuboard5
  license: MIT
  repository: https://github.com/1clickmake/php-security-review
---

# PHP Security Review (PHP 8+, 순수 PHP)

## 적용 범위

- 대상: PHP 8.0 이상, 프레임워크 없는 순수 PHP (자체 라우팅, `include` 기반 템플릿, PDO/mysqli).
- **그누보드5 계열이면 `references/gnuboard.md` 를 반드시 함께 읽고** 그 프로필을 우선 적용한다 (코어 수정 금지, `addslashes` 관행 오탐 주의, `data/`·`install/` 점검 등).
- 예외: Laravel/Symfony/WordPress 등이 발견되면 **먼저 보고**하고, 해당 프레임워크 규약(ORM 바인딩, Blade 이스케이프, nonce 등)에 맞춰 규칙을 조정한다. 프레임워크 방어를 무시한 채 "취약"으로 단정하지 않는다.
- 검수는 **읽기 중심**. 코드 수정은 사용자가 요청했을 때만, 최소 diff로.

## 절대 규칙

1. **증거 기반.** source → sink 경로를 실제 코드로 확인하지 못한 항목은 "취약"이 아니라 "확인 필요"로 분류한다.
2. **방어의 적합성을 검사.** `intval()`은 SQL/SHELL에 도움되지만 HTML 출력엔 무의미하다. `htmlspecialchars()`는 SQL 인젝션을 막지 못한다. 방어 함수가 **해당 싱크에 맞는지** 따진다.
3. **한 번의 이스케이프 원칙.** 저장 시 이스케이프 + 출력 시 이스케이프를 중복 적용하면 이중 인코딩/데이터 손상이 생긴다. 어디서 방어하는지 명시한다.
4. **추측 금지.** 파일:라인 근거 없는 항목은 보고서에 넣지 않는다.
5. **실행 부작용 금지.** 검수 중 임의 코드 실행, DB 쓰기, 외부 요청, 대량 파일 변경을 하지 않는다. PoC가 필요하면 로컬 사본에서만, 사용자 승인 후.
6. **자동 전체 리라이트 금지.** 패치는 취약 지점 단위로 제시하고, 동작 변경 가능성이 있으면 먼저 알린다.

## 워크플로

### Step 0 — 준비

```powershell
php -v
composer audit            # composer.json 이 있으면
php -l <파일>              # 수정 후 문법 확인
```

후보 수집(휴리스틱 스캐너, 결과는 확정이 아님):

```powershell
powershell -ExecutionPolicy Bypass -File "<skill-dir>\scripts\scan.ps1" -Path . -Csv scan-report.csv
```

주요 옵션:

| 옵션 | 용도 |
|---|---|
| `-MinSeverity High` | High 이상만 (노이즈 큰 사이트) |
| `-MaxPerRule 5` | 규칙당 출력 제한 |
| `-Encoding Auto` | 기본값. UTF-8/CP949(EUC-KR) 자동 감지. 그누보드 구버전은 CP949인 경우가 많음 |
| `-Exclude` | 추가 제외 디렉터리 |
| `-Csv <경로>` | 결과 CSV 저장 (프로젝트 폴더 밖 권장) |

**대규모 CMS 주의**: 그누보드/영카트처럼 코어가 큰 사이트는 코어 포함 전체 스캔 시 후보가 수천 건 나온다(1,600파일 → 5,000+). 실무 순서는 다음과 같다.

1. **커스텀 영역 우선**: `theme/`, `skin/`, `mobile/`, `extend/`, `page/`, 루트 커스텀 파일
2. 코어(`lib/`, `bbs/`, `adm/`, `shop/`, `plugin/`)는 **버전 확인 + 공식 업데이트**로 처리하고, 코어 수정 이력만 확인
3. `-MinSeverity High` 로 좁혀서 실제 조치 대상만 본다

### Step 0.5 — 버전·패치 대조 (코드 검수보다 먼저)

**"버전이 낡아서 생기는 구멍"은 코드 검사로 잡히지 않는다.** 코드를 보기 전에 이 단계를 먼저 수행하고, 결과를 보고서 맨 앞 "즉시 조치" 섹션에 배치한다.

```powershell
# 1) 로컬 버전 파싱 + 최신 그누보드 대조
powershell -ExecutionPolicy Bypass -File "<skill-dir>\scripts\version-check.ps1" -Path <루트>

# 2) PHP 버전을 알면 함께 판정 (PHP2Shell 등)
powershell -ExecutionPolicy Bypass -File "<skill-dir>\scripts\version-check.ps1" -Path <루트> -PhpVersion 8.2.30

# 3) 도메인만 있으면 HTTP 로 PHP 버전 추정 (헤더 → /install/ 페이지)
powershell -ExecutionPolicy Bypass -File "<skill-dir>\scripts\version-check.ps1" -Path <루트> -Domain example.com
```

절차:

1. **PHP 버전 확인** — 우선순위: 호스팅 관리자 페이지 > `X-Powered-By` 헤더 > `/install/` 페이지 > FTP 프로브(파일 1개 업로드 후 즉시 삭제, 사용자 승인 필요)
2. **최소 패치 버전 대조** — `references/advisories.md` 의 PHP2Shell 표와 비교. 미달이면 Critical로 보고
3. **그누보드 버전 대조** — `G5_GNUBOARD_VER` vs 최신 릴리스. 뒤처지면 "보안패치 누락" 으로 보고하되, **코어 직접 패치 금지 / 업데이트 권고**
4. **의존성** — `composer audit` (해당 시)
5. **최신 CVE 조회** — `advisories.md` 는 스냅샷이므로, 검수 시점에 PHP 공식 보안 공지와 그누보드 릴리스 노트를 웹으로 확인한다

주의:
- PHP 코어 CVE(예: PHP2Shell)는 **애플리케이션 코드로 완화 불가**. 서버 패치만이 해결책이다.
- 버전 정보를 확인할 수 없으면 "확인 필요"로 남기고 추측하지 않는다.
- FTP 접속 정보를 요구하지 않는다. 도메인/관리자 페이지로 확인하고, 불가능할 때만 사용자에게 선택지를 제시한다.

### Step 1 — 공격 표면 매핑

다음을 찾아 목록화한다.

- **입력점**: `$_GET`, `$_POST`, `$_REQUEST`, `$_COOKIE`, `$_FILES`, `$_SERVER['HTTP_*']`, `php://input`, `file_get_contents('php://input')`
- **인증 경계**: 로그인/세션 시작 지점, 관리자 페이지 진입 조건, `require login.php` 패턴이 실제로 모든 엔드포인트에 있는지
- **싱크**: SQL, HTML 출력, `include/require`, 파일 시스템, 커맨드, HTTP 클라이언트, 헤더/쿠키, `unserialize`

### Step 2 — 데이터 흐름 추적

각 후보에 대해 다음을 기록한다.

```
source($_GET['id'])
  → 변환(intval / filter_var / preg_match / 없음)
  → sink(PDO::query 문자열 결합)
  → 도달 조건(로그인 필요? 파라미터 존재?)
  → 판정(취약 / 확인 필요 / 안전)
```

중간에 검증이 있어도 **검증 실패 시 흐름이 차단되는지**, **검증 후 값을 싱크에 다시 쓰는지** 확인한다. 검증 결과를 버리고 원본을 쓰는 코드가 흔한 실수다.

### Step 3 — 싱크별 필수 방어

| 싱크 | 올바른 방어 | 흔한 오답 |
|---|---|---|
| SQL | PDO prepared statement (`ATTR_EMULATE_PREPARES=false`), 바인딩 | `addslashes`, 문자열 치환, `intval`만으로 문자열 컬럼 처리 |
| HTML 본문/속성 | `htmlspecialchars($v, ENT_QUOTES \| ENT_SUBSTITUTE, 'UTF-8')` | `strip_tags` 단독, `urlencode` |
| HTML 속성 내 JS/URL | `json_encode($v, JSON_HEX_TAG\|JSON_HEX_AMP\|JSON_HEX_APOS\|JSON_HEX_QUOT)`; URL은 `rawurlencode` | 따옴표 없이 속성 삽입 |
| 커맨드 | `escapeshellarg` + **고정 바이너리·고정 서브커맨드** | `escapeshellcmd` 단독, 사용자 입력으로 명령 선택 |
| `include/require` | 화이트리스트 맵(`['home'=>'/pages/home.php']`) | `basename()`만, 확장자 검사만 |
| 파일 경로 | `realpath()` + 허용 루트 prefix 검사, `basename()` | `str_replace('../')` |
| 파일 업로드 | 확장자 화이트리스트 + MIME/매직바이트 확인 + `is_uploaded_file` + 웹루트 밖 저장 + 실행 불가 확장자 | `$_FILES['type']` 신뢰, 원본 파일명 그대로 저장 |
| 헤더/쿠키 | CR/LF 제거, 고정 값 | 사용자 입력 그대로 `header()` |
| 리다이렉트 | 경로 화이트리스트 또는 상대 경로만 | `header('Location: '.$url)` |
| 역직렬화 | `unserialize($s, ['allowed_classes'=>false])` 또는 `json_decode` | 서명/출처 검증 없는 `unserialize($_COOKIE[...])` |
| 아웃바운드(SSRF) | 스킴/호스트 화이트리스트, 사설 IP 차단, `CURLOPT_PROTOCOLS` 제한 | 사용자 URL 그대로 `curl_init` |
| 비밀번호 | `password_hash(PASSWORD_DEFAULT)`, `password_verify` | `md5`, `sha1`, `crypt` 고정 salt |
| 토큰/난수 | `random_bytes`, `random_int` | `rand`, `mt_rand`, `uniqid`, `time()` |
| 비교 | `hash_equals` (토큰/해시), `===` | `==` (특히 `"0e..."` 매직 해시) |

### Step 4 — 심각도 판정

| 등급 | 기준 |
|---|---|
| Critical | 비인증 원격에서 코드 실행/파일 쓰기/인증 우회/DB 전체 유출 |
| High | 인증 후 권한 상승, 저장형 XSS, SQLi(제한적), LFI, 하드코딩 시크릿(실서비스) |
| Medium | 반사형 XSS(자가 피해), CSRF(민감 동작), 정보 노출, 세션 쿠키 플래그 누락 |
| Low | 강화 권고, 디버그 출력 잔존, 약한 난수(보안 용도 아님) |

판정에는 **도달 가능성**을 함께 적는다: 비인증/일반 사용자/관리자 전용.

### Step 5 — 보고서 형식

```markdown
# PHP 보안 검수 결과 — <대상> (<날짜>)

## 요약
| 등급 | 건수 |
|---|---|
| Critical | n |
| High | n |
...

## 발견 항목

### [C-1] 제목 (Critical)
- **위치**: `path/file.php:42`
- **유형**: SQL Injection (CWE-89)
- **데이터 흐름**: `$_GET['id']` → 문자열 결합 → `PDO::query`
- **도달 조건**: 비인증, `?id=` 파라미터
- **영향**: DB 전체 읽기/쓰기
- **재현 시나리오**: (요청 형태 또는 입력값 수준 설명. 실제 공격 페이로드 남용 금지)
- **패치**:
  ```php
  // before
  $sql = "SELECT * FROM users WHERE id = " . $_GET['id'];
  // after
  $stmt = $pdo->prepare('SELECT * FROM users WHERE id = :id');
  $stmt->execute([':id' => (int) $_GET['id']]);
  ```
- **재검증**: `php -l`, 해당 흐름 재추적 결과

## 확인 필요 (증거 부족)
...

## 강화 권고 (취약점 아님)
...
```

### Step 6 — 패치 후 재검증

1. `php -l` 로 문법 확인 (가능하면 변경 파일 전체)
2. 스캐너 재실행 → 동일 규칙 hit 감소 확인
3. 해당 데이터 흐름을 다시 추적해 방어가 **싱크 직전에** 있는지 확인
4. 동작 변경(에러 메시지, 리다이렉트, 파일명 저장 방식 등)을 사용자에게 명시

## PHP 8 특화 체크 (요약)

- `declare(strict_types=1)` 없으면 타입 저글링 위험 → 인증/권한 비교에서 특히 확인
- `==` 비교: `"0e123" == "0e456"` 은 true. 해시/토큰 비교는 `hash_equals` 필수
- `unserialize` 는 PHP 8에서도 여전히 위험. `allowed_classes` 를 반드시 지정
- `assert()` 는 PHP 8에서 문자열 eval 하지 않지만, `assert($userInput)` 형태는 로직 우회 위험
- 에러는 `Throwable` 로 잡고, `display_errors=Off` + 로그로만
- `$_FILES['type']` 은 클라이언트 제공값 → 신뢰 금지

### PHP 8.1 ~ 8.3 추가 체크

| 버전 | 항목 | 보안 판단 포인트 |
|---|---|---|
| 8.0 | `str_contains` / `str_starts_with` | 경로 prefix 검사는 `strpos(...) === 0` 대신 이걸 사용 (오탐 감소) |
| 8.0 | `create_function`, `each()`, `$HTTP_RAW_POST_DATA` 제거 | 레거시 코드에 잔존하면 이미 동작 불가 → 우회 구현 여부 확인 |
| 8.1 | `readonly` 프로퍼티, enum | 보안 설정값의 사후 변경 차단 여부. 문자열 비교 기반 권한 로직은 enum 권장 |
| 8.1 | `never` 반환 타입 | `exit` 누락으로 인한 후속 실행 방지에 활용 |
| 8.1 | `fsync`/`array_is_list` | 파일 저장 무결성, 입력 배열 형태 검증 |
| 8.2 | `readonly class` | 설정/자격증명 객체 불변성 확보 |
| 8.2 | **dynamic property deprecated** | `__set` 남용·mass assignment 흔적. `#[AllowDynamicProperties]` 로 덮은 클래스는 입력 대입 경로 확인 |
| 8.2 | `${var}` 문자열 보간 deprecated | 변수 변수(`$$var`) 사용 여부와 함께 점검 |
| 8.2 | `Random\Randomizer`, `mysqli::execute_query` | 난수는 `Randomizer`/`random_int`, 쿼리는 파라미터 바인딩 유도 |
| 8.3 | **typed class constants** | 권한/역할 상수 오타·타입 불일치 방지 |
| 8.3 | `json_validate()` | `json_decode` 전 구조 검증 → 실패 시 통과 로직 방지 |
| 8.3 | `#[\Override]` | 상속으로 인한 권한 메서드 우회(이름 변경) 사고 방지 |
| 8.3 | dynamic class constant fetch | `constant($userInput)` 형태는 화이트리스트 필수 |

- 위 항목은 "있으면 좋은" 강화가 아니라 **취약 로직을 발견하는 단서**로 사용한다. 예: `#[AllowDynamicProperties]` 가 붙은 사용자 모델은 대입 경로를 반드시 추적.
- 8.4 이상 코드(property hooks 등)가 보이면 버전을 먼저 확인하고, 확인 전에는 판정을 보류한다.

상세 항목: `references/checklist.md`, 하드닝 설정/코드: `references/php8-hardening.md`, 그누보드: `references/gnuboard.md`, 버전/CVE 스냅샷: `references/advisories.md`

## 하지 말 것

- 코드 전체를 "안전 패턴"으로 일괄 치환
- 근거 없는 항목을 Critical로 올려 보고서를 부풀리기
- `composer update` 를 승인 없이 실행
- 검수 목적으로 실제 서비스에 공격 트래픽 전송
