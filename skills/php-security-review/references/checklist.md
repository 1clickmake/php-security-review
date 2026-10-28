# PHP 보안 체크리스트 (PHP 8+, 순수 PHP)

각 항목: **탐지 신호 → 판단 기준 → 안전 패턴**. 탐지 신호는 후보일 뿐이며, 데이터 흐름 추적으로 확정한다.

## 1. 인젝션

### 1.1 SQL Injection (CWE-89)
- 탐지: 문자열 결합 SQL, `PDO::query`, `mysqli_query`, `->exec`, `ORDER BY $col`, `LIMIT $n`
- 판단: 값이 prepared statement 바인딩이 아닌 **문자열로** 들어가는가? 컬럼명/정렬 방향은 화이트리스트인가?
- 안전:
```php
$pdo->setAttribute(PDO::ATTR_EMULATE_PREPARES, false);
$stmt = $pdo->prepare('SELECT * FROM posts WHERE slug = :slug AND status = :st');
$stmt->execute([':slug' => $slug, ':st' => 'published']);
```
- 주의: `ATTR_EMULATE_PREPARES=true`(기본값일 수 있음)는 다중 statement 위험을 남긴다. `ORDER BY` 는 바인딩 불가 → 맵 사용.

### 1.2 Command Injection (CWE-78)
- 탐지: `system`, `exec`, `shell_exec`, `passthru`, `popen`, `proc_open`, 백틱, `escapeshellcmd` 단독 사용
- 판단: 인자에 사용자 입력이 들어가는가? 명령/서브커맨드 자체를 입력이 고르는가?
- 안전: 고정 바이너리 + `escapeshellarg`, 가능하면 PHP 내장 함수로 대체(`mkdir`, `copy`, `unlink`, GD/Imagick)

### 1.3 Code Injection / eval (CWE-94/95)
- 탐지: `eval`, `assert($var)`, `preg_replace` 의 `/e`(PHP7 제거, 잔존 코드 확인), `create_function`(제거)
- 판단: 입력이 코드로 해석되는가? 템플릿 엔진이 `eval` 을 쓰는가?
- 안전: 데이터는 데이터로. 템플릿은 명시적 치환(`strtr`, `sprintf`)으로.

### 1.4 LDAP / XPath / NoSQL — 해당 라이브러리 사용 시
- 탐지: `ldap_search` 필터 문자열 결합, `DOMXPath` 쿼리 결합
- 안전: `ldap_escape($v, '', LDAP_ESCAPE_FILTER)`, XPath 변수 바인딩

## 2. 출력 / XSS

### 2.1 Reflected / Stored XSS (CWE-79)
- 탐지: `echo $_GET`, `<?= $_POST`, `print $row['body']` (이스케이프 없음), `innerHTML` 에 PHP 변수
- 판단: HTML 컨텍스트(본문/속성/URL/JS)별로 방어가 다른가?
- 안전:
```php
function e(?string $v): string {
    return htmlspecialchars($v ?? '', ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}
// JS 컨텍스트
<script>const cfg = <?= json_encode($cfg, JSON_HEX_TAG|JSON_HEX_AMP|JSON_HEX_APOS|JSON_HEX_QUOT) ?>;</script>
// URL 파라미터
<a href="/p?q=<?= rawurlencode($q) ?>">…</a>
```
- 주의: `strip_tags` 는 속성 내 이벤트 핸들러를 막지 못한다. 리치 텍스트는 HTML Purifier 같은 화이트리스트 파서 사용.

### 2.2 헤더/쿠키 인젝션 (CWE-113)
- 탐지: `header("...$v")`, `setcookie(..., $v)`, `Location: $v`
- 안전: CR/LF 제거(`preg_replace('/[\r\n]+/', '', $v)`), 리다이렉트는 경로 화이트리스트

## 3. 파일

### 3.1 LFI/RFI (CWE-98)
- 탐지: `include/require` 에 변수, `?page=`, `?lang=`
- 안전:
```php
$pages = ['home' => __DIR__.'/pages/home.php', 'about' => __DIR__.'/pages/about.php'];
$key = $_GET['page'] ?? 'home';
include $pages[$key] ?? $pages['home'];
```

### 3.2 Path Traversal (CWE-22)
- 탐지: `file_get_contents`, `readfile`, `fopen`, `unlink`, `rename`, `copy` 에 변수 경로
- 안전:
```php
$base = realpath(__DIR__.'/uploads');
$target = realpath($base.'/'.basename($name));
if ($target === false || !str_starts_with($target, $base.DIRECTORY_SEPARATOR)) {
    throw new RuntimeException('invalid path');
}
```
- 주의: `str_replace('../', '', $v)` 는 우회된다(`....//`). `realpath` + prefix 검사가 기준.

### 3.3 파일 업로드 (CWE-434)
- 탐지: `move_uploaded_file`, `$_FILES['type']`, 원본 파일명 저장
- 안전:
```php
$allow = ['image/jpeg' => 'jpg', 'image/png' => 'png', 'image/webp' => 'webp'];
$finfo = new finfo(FILEINFO_MIME_TYPE);
$mime  = $finfo->file($_FILES['f']['tmp_name']);
if (!isset($allow[$mime]) || !is_uploaded_file($_FILES['f']['tmp_name'])) { http_response_code(400); exit; }
$name = bin2hex(random_bytes(16)).'.'.$allow[$mime];
move_uploaded_file($_FILES['f']['tmp_name'], __DIR__.'/../storage/uploads/'.$name);
```
- 필수: 웹루트 **밖** 저장, 업로드 디렉터리 PHP 실행 차단, 크기 제한, 이미지 재인코딩 권장

### 3.4 안전하지 않은 임시 파일 (CWE-377)
- 탐지: `tempnam` 후 권한 미설정, 예측 가능 파일명
- 안전: `tmpfile()`, `tempnam()` + `chmod 0600`, `random_bytes` 기반 이름

## 4. 직렬화 / 세션 / 인증

### 4.1 Insecure Deserialization (CWE-502)
- 탐지: `unserialize($_COOKIE[...])`, `unserialize(base64_decode(...))`
- 안전: `json_decode(..., true)` 로 교체. 불가피하면 `['allowed_classes' => false]`, 서명(HMAC) 검증
```php
$data = unserialize($raw, ['allowed_classes' => ['CartItem']]);
```

### 4.2 세션 (CWE-384/613)
- 확인: `session_start()` 전 `session_set_cookie_params(['httponly'=>true,'secure'=>true,'samesite'=>'Lax'])`, 로그인 성공 후 `session_regenerate_id(true)`, 로그아웃 시 `session_destroy()` + 쿠키 만료
- 탐지: 로그인 폼 처리 코드에 `session_regenerate_id` 없음, 세션 ID를 URL로 전달

### 4.3 인증/인가 결함 (CWE-287/639)
- 확인: 모든 상태 변경 엔드포인트에 권한 검사가 있는가? **IDOR**: `?id=123` 이 소유자 검사 없이 조회/수정되는가?
- 안전: 라우터 진입점에서 공통 인증 + 리소스 소유자 조건을 SQL `WHERE owner_id = :me` 로 강제

### 4.4 비밀번호 (CWE-916)
- 탐지: `md5`, `sha1`, `crypt` 고정 salt, 평문 비교
- 안전: `password_hash($p, PASSWORD_DEFAULT)`, `password_verify`, `password_needs_rehash`

### 4.5 토큰/난수 (CWE-338)
- 탐지: `rand`, `mt_rand`, `uniqid`, `time()` 로 토큰/코드 생성
- 안전: `bin2hex(random_bytes(32))`, 6자리 코드는 `random_int(100000, 999999)` + 시도 횟수 제한 + 만료

### 4.6 비교 (CWE-697)
- 탐지: `==` 로 해시/토큰 비교, `"0e..."` 매직 해시
- 안전: `hash_equals($known, $given)`, `===`

### 4.7 CSRF (CWE-352)
- 확인: 상태 변경 POST에 CSRF 토큰이 있는가? `SameSite=Lax` 만으로 부족한 경우(크로스사이트 POST)가 있는가?
- 안전: 세션 바인딩 토큰 + `hash_equals` 검증 + 실패 시 403

## 5. 서버사이드 요청 / 기타

### 5.1 SSRF (CWE-918)
- 탐지: 사용자 입력 URL 로 `curl_init`, `file_get_contents`, `fopen`, 웹훅/이미지 프록시
- 안전: 스킴(http/https) 제한, 호스트 화이트리스트, 사설/루프백 IP 차단, `CURLOPT_PROTOCOLS => CURLPROTO_HTTP|CURLPROTO_HTTPS`, 리다이렉트 추적 제한(`CURLOPT_FOLLOWLOCATION=false` 또는 재검증)

### 5.2 XXE (CWE-611)
- 탐지: `simplexml_load_string`, `DOMDocument::loadXML`, `SimpleXMLElement` 에 사용자 XML
- 안전: `libxml_set_external_entity_loader(fn() => null)`, `LIBXML_NONET`, PHP 8은 기본 엔티티 로딩 비활성이나 명시 권장

### 5.3 오픈 리다이렉트 (CWE-601)
- 탐지: `header('Location: ' . $_GET['next'])`
- 안전: 내부 경로만 허용, 외부는 화이트리스트 도메인 검사

### 5.4 정보 노출 (CWE-200/209)
- 탐지: `display_errors=On`, `phpinfo()`, `var_dump`, 스택트레이스 출력, `composer.json`/`.env`/`.git` 웹 노출
- 안전: `display_errors=Off`, `log_errors=On`, 에러는 사용자에게 일반 메시지 + `error_log`

### 5.5 시크릿 하드코딩 (CWE-798)
- 탐지: `$dbPass = '...'`, API 키 문자열, 리포지토리에 `.env`
- 안전: 환경변수(`getenv`) + `.env` 는 웹루트 밖, 유출 시 즉시 로테이션

### 5.6 의존성 (CWE-1104)
- 확인: `composer audit`, `composer.lock` 커밋 여부, `vendor/` 웹 노출
- 안전: 패치 버전 고정, 자동 업데이트는 승인 후

### 5.7 보안 헤더 / TLS
- 권장: `Content-Security-Policy`, `X-Content-Type-Options: nosniff`, `Referrer-Policy`, `Strict-Transport-Security`(HTTPS), `X-Frame-Options` 또는 CSP `frame-ancestors`

## 6. PHP 8 코드 품질 함정 (보안 영향)

| 함정 | 영향 | 대응 |
|---|---|---|
| `declare(strict_types=1)` 없음 | 타입 저글링으로 인증 비교 우회 | 인증/권한 파일에 추가 |
| `$_REQUEST` 사용 | 쿠키로 파라미터 덮어쓰기 | `$_GET`/`$_POST` 명시 |
| `filter_input` 반환값 null 미처리 | 검증 실패를 통과로 오인 | null/`false` 분기 |
| `@` 에러 억제 | 실패 원인 은폐 | 예외 처리로 전환 |
| `extract($_POST)` | 변수 덮어쓰기 | 사용 금지 |
| `parse_str($q)` (2번째 인자 없음) | 변수 오염 | `parse_str($q, $out)` |
| `preg_match` 반환값 미확인 | 검증 실패 통과 | `=== 1` 확인 |
| `in_array($v, $list)` (strict 없음) | 타입 저글링 통과 | `in_array($v, $list, true)` |
| `header()` 후 `exit` 없음 | 후속 로직 실행 | `exit` 필수 |
| `settype`/`(int)` 만으로 문자열 컬럼 처리 | SQLi 잔존 | prepared statement |
