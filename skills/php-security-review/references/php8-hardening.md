# PHP 8 하드닝 레퍼런스 (순수 PHP)

## 1. php.ini / 런타임

```ini
display_errors = Off
display_startup_errors = Off
log_errors = On
error_log = /var/log/php/error.log
expose_php = Off
allow_url_include = Off
allow_url_fopen = Off          ; 필요 시에만 On, SSRF 표면 축소
open_basedir = /var/www/site:/tmp
session.use_strict_mode = 1
session.use_only_cookies = 1
session.cookie_httponly = 1
session.cookie_secure = 1
session.cookie_samesite = Lax
```

런타임에서 강제할 수 있는 항목:

```php
declare(strict_types=1);

ini_set('display_errors', '0');
error_reporting(E_ALL);
set_error_handler(static function (int $no, string $str, string $file, int $line): bool {
    throw new ErrorException($str, 0, $no, $file, $line);
});
```

## 2. 세션

```php
session_set_cookie_params([
    'lifetime' => 0,
    'path'     => '/',
    'domain'   => '',
    'secure'   => true,
    'httponly' => true,
    'samesite' => 'Lax',
]);
session_start();

// 로그인 성공 직후
session_regenerate_id(true);
$_SESSION['uid'] = $user['id'];
$_SESSION['fp']  = hash('sha256', $_SERVER['HTTP_USER_AGENT'] ?? '');
```

로그아웃:

```php
$_SESSION = [];
if (ini_get('session.use_cookies')) {
    $p = session_get_cookie_params();
    setcookie(session_name(), '', time() - 42000, $p['path'], $p['domain'], $p['secure'], $p['httponly']);
}
session_destroy();
```

## 3. 인증 / 인가

```php
// 공통 부트스트랩에서 강제
function require_login(): array {
    if (empty($_SESSION['uid'])) {
        header('Location: /login.php', true, 303);
        exit;
    }
    return ['id' => (int) $_SESSION['uid']];
}

// 소유자 검사는 쿼리 조건으로 강제 (IDOR 방지)
$stmt = $pdo->prepare('UPDATE posts SET title = :t WHERE id = :id AND owner_id = :me');
$stmt->execute([':t' => $title, ':id' => (int) $id, ':me' => $me['id']]);
if ($stmt->rowCount() === 0) { http_response_code(404); exit; }
```

## 4. 비밀번호 / 토큰

```php
$hash = password_hash($password, PASSWORD_DEFAULT);
if (!password_verify($password, $row['password_hash'])) { /* 실패 */ }
if (password_needs_rehash($row['password_hash'], PASSWORD_DEFAULT)) { /* 재해시 후 저장 */ }

$token = bin2hex(random_bytes(32));                 // 세션/리셋 토큰
$code  = (string) random_int(100000, 999999);       // OTP
if (!hash_equals($expected, $given)) { /* 거부 */ }
```

## 5. PDO

```php
$pdo = new PDO($dsn, $user, $pass, [
    PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    PDO::ATTR_EMULATE_PREPARES   => false,
    PDO::ATTR_STRINGIFY_FETCHES  => false,
]);
```

식별자(컬럼/정렬)는 바인딩 불가 → 맵:

```php
$sortMap = ['new' => 'created_at DESC', 'old' => 'created_at ASC'];
$order = $sortMap[$_GET['sort'] ?? 'new'] ?? $sortMap['new'];
$sql = "SELECT id, title FROM posts ORDER BY $order LIMIT 50";
```

## 6. 출력 이스케이프

```php
function e(null|string|int|float $v): string {
    return htmlspecialchars((string) ($v ?? ''), ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}
```

- HTML 본문: `e($v)`
- HTML 속성: `e($v)` (항상 따옴표로 감쌀 것)
- URL 쿼리: `rawurlencode($v)`
- JS: `json_encode($v, JSON_HEX_TAG|JSON_HEX_AMP|JSON_HEX_APOS|JSON_HEX_QUOT)`
- CSS: 사용자 입력 직접 삽입 금지

## 7. 파일 업로드

```php
final class Uploader {
    private const ALLOW = ['image/jpeg' => 'jpg', 'image/png' => 'png', 'image/webp' => 'webp'];

    public static function store(array $file, string $dir): string {
        if (($file['error'] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_OK) {
            throw new RuntimeException('upload failed');
        }
        if ($file['size'] > 5 * 1024 * 1024) { throw new RuntimeException('too large'); }
        if (!is_uploaded_file($file['tmp_name'])) { throw new RuntimeException('invalid'); }

        $mime = (new finfo(FILEINFO_MIME_TYPE))->file($file['tmp_name']);
        if (!isset(self::ALLOW[$mime])) { throw new RuntimeException('bad type'); }

        $name = bin2hex(random_bytes(16)) . '.' . self::ALLOW[$mime];
        $dest = rtrim($dir, '/\\') . DIRECTORY_SEPARATOR . $name;
        if (!move_uploaded_file($file['tmp_name'], $dest)) { throw new RuntimeException('move failed'); }
        @chmod($dest, 0640);
        return $name;
    }
}
```

서버 설정(업로드 디렉터리 PHP 실행 차단):

```apache
<Directory "/var/www/site/storage/uploads">
    php_flag engine off
    <FilesMatch "\.(php|phtml|phar|php[0-9])$">
        Require all denied
    </FilesMatch>
</Directory>
```

nginx:

```nginx
location ^~ /storage/uploads/ {
    location ~ \.(php|phtml|phar)$ { deny all; }
}
```

## 8. HTTP 클라이언트 (SSRF 방지)

```php
function safe_fetch(string $url): string {
    $p = parse_url($url);
    if (!in_array($p['scheme'] ?? '', ['http', 'https'], true)) { throw new RuntimeException('bad scheme'); }
    $host = $p['host'] ?? '';
    $ip = gethostbyname($host);
    if (filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_NO_PRIV_RANGE | FILTER_FLAG_NO_RES_RANGE) === false) {
        throw new RuntimeException('blocked host');
    }
    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_FOLLOWLOCATION => false,
        CURLOPT_PROTOCOLS      => CURLPROTO_HTTP | CURLPROTO_HTTPS,
        CURLOPT_TIMEOUT        => 5,
        CURLOPT_CONNECTTIMEOUT => 3,
    ]);
    $body = curl_exec($ch);
    curl_close($ch);
    return (string) $body;
}
```

## 9. 보안 헤더

```php
header("Content-Security-Policy: default-src 'self'; img-src 'self' data: https:; script-src 'self'; style-src 'self' 'unsafe-inline'; frame-ancestors 'none'; base-uri 'self'");
header('X-Content-Type-Options: nosniff');
header('Referrer-Policy: strict-origin-when-cross-origin');
header('Strict-Transport-Security: max-age=31536000; includeSubDomains'); // HTTPS 필수
```

## 10. CSRF

```php
function csrf_token(): string {
    $_SESSION['csrf'] ??= bin2hex(random_bytes(32));
    return $_SESSION['csrf'];
}

function csrf_check(): void {
    $given = $_POST['_csrf'] ?? '';
    if (!is_string($given) || !hash_equals($_SESSION['csrf'] ?? '', $given)) {
        http_response_code(403);
        exit('invalid request');
    }
}
```

폼:

```php
<form method="post" action="/save.php">
  <input type="hidden" name="_csrf" value="<?= e(csrf_token()) ?>">
</form>
```

## 11. 배포 체크

- [ ] `.env`, `composer.json`, `.git/`, `storage/` 웹 접근 차단
- [ ] `vendor/` 웹루트 밖 또는 접근 차단
- [ ] 디렉터리 리스팅 off (`Options -Indexes` / `autoindex off`)
- [ ] HTTPS 강제 + HSTS
- [ ] 업로드 디렉터리 PHP 실행 차단
- [ ] `composer audit` 무경고
- [ ] 에러 로그에 민감정보(비밀번호, 토큰) 미기록
