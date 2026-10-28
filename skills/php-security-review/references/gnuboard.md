# 그누보드5 보안 검수 프로필

> 전제: PHP 8.x + 그누보드5 계열. **그누보드6 이상은 구조가 다르므로** 이 프로필을 그대로 적용하지 말고 먼저 확인한다.

## 1. 버전 / 구조 확인

```powershell
Select-String -Path .\**\*.php -Pattern "G5_VERSION" -List
Get-ChildItem -Directory | Select-Object Name
```

기대 디렉터리: `adm/ bbs/ lib/ skin/ mobile/ extend/ plugin/ theme/ data/ js/ css/ install/`

- `G5_VERSION` 값 확인 → 공식 패치노트와 대조 (코어 취약점은 **직접 패치하지 말고 업데이트**)
- `theme/` 사용 시 스킨이 `theme/<name>/` 아래에 있을 수 있음 → 검수 대상 경로에 포함

## 2. 수정 원칙 (가장 중요)

| 대상 | 원칙 |
|---|---|
| 코어 (`lib/`, `bbs/`, `adm/` 일부) | **직접 수정 금지.** 버전 업데이트로 해결. 수정했다면 업데이트 시 덮어써짐 |
| `extend/` | 자동 로드되는 훅. **출처 불명 파일은 백도어로 간주**하고 내용 확인 |
| `skin/`, `mobile/skin/`, `theme/` | 커스텀 코드 → 검수·패치 대상 |
| `plugin/` | 서드파티. 사용 중인 것만, 버전·출처 확인 |
| `data/` | 사용자 업로드/설정. 코드 아님 → 접근 차단·퍼미션 점검 |
| 루트 커스텀 파일 (`index.php`, `_common.php` 등) | `_common.php` 우회 여부 확인 |

## 3. 그누보드特有 위험 패턴

| 패턴 | 위험도 | 판단 기준 |
|---|---|---|
| `sql_query("... " . $_GET[...])` | Critical | 슈퍼글로벌을 **문자열 결합**으로 SQL 에 넣음. g5 관행(`addslashes` 후 전달)과 구분 |
| `sql_query` 에 변수만 전달 | High | 변수가 어디서 조립됐는지 역추적. `addslashes`/`sql_real_escape` 여부 |
| `include $_GET[...]`, `include $bo_table` | Critical | 화이트리스트 없이 경로 조립 |
| `include_once $g5['...']` | Low | g5 설정 배열 기반이면 대체로 안전. 값이 사용자 입력으로 덮어써지는지 확인 |
| `echo $view['wr_content']` | High | HTML 허용 게시판이면 저장형 XSS. `get_text()`/`conv_content()` 처리 여부 확인 |
| `echo $write['wr_subject']` | Medium | 제목 출력 이스케이프 여부 |
| `$_FILES` 처리 (`bbs/write_update.php` 커스텀) | High | 확장자/매직바이트 검증, `data/file/<bo_table>/` 저장, 실행 차단 |
| `unserialize` | Critical | g5 코어에는 드묾 → 커스텀 코드에 있으면 즉시 조사 |
| `extract()` / `parse_str()` (2번째 인자 없음) | High | 변수 오염 |
| `eval`, `assert($var)` | Critical | 커스텀 위젯/플러그인에서 발견되면 조사 |
| `$is_admin` 검사 누락 (`adm/`) | Critical | `adm/` 커스텀 파일이 `admin.lib.php` 로드 + `$is_admin` 검사하는지 |
| 토큰 검증 누락 | High | 폼 처리 파일에서 g5 토큰 함수 호출 여부 (실제 함수명은 코드에서 grep) |

> **오탐 주의**: g5 코어는 `addslashes()` 기반 이스케이프를 관행적으로 사용한다. 코어 파일에서 `addslashes` + `sql_query` 조합은 **정상 패턴**일 수 있으므로, 커스텀 파일과 구분해서 판정한다.

## 4. 배포 전 체크리스트

### 4.1 노출 / 접근 차단
- [ ] `install/` 디렉터리 잔존 → **삭제 또는 접근 차단** (재설치 공격)
- [ ] `data/dbconfig.php` 웹 접근 차단 (`.htaccess`/nginx deny)
- [ ] `data/` 내 `*.sql`, `*.bak`, 백업 파일 노출 없음
- [ ] `data/file/`, `data/editor/` 에서 PHP 실행 차단
- [ ] `config.php`, `.env`, `composer.json`, `.git/` 접근 차단
- [ ] 디렉터리 리스팅 off
- [ ] `phpinfo.php`, `test.php`, `info.php` 등 임시 파일 없음

### 4.2 인증 / 권한
- [ ] `adm/` 모든 진입 파일이 관리자 검사 수행
- [ ] `bbs/` 상태 변경(글쓰기/수정/삭제/댓글)에서 권한·토큰 검사
- [ ] `_common.php` 를 include 하지 않는 우회 진입 파일 없음
- [ ] 관리자 세션과 일반 세션 분리 정책 확인
- [ ] 비밀번호 해시 방식 확인 (`password_hash` 계열인지, 오래된 `md5` 잔존 여부)

### 4.3 출력 / 입력
- [ ] 스킨의 `$view`, `$write`, `$list` 출력에 이스케이프 적용
- [ ] HTML 허용 게시판의 `wr_content` 필터 정책 확인
- [ ] 커스텀 폼의 `$_GET`/`$_POST` 직접 SQL 결합 없음
- [ ] 에디터 업로드 파일명 랜덤화, 원본명 저장 방식 확인

### 4.4 확장 지점
- [ ] `extend/*.php` 파일 목록 확인 (자동 로드 = 상시 실행)
- [ ] `plugin/` 사용 중 플러그인 버전·출처 확인
- [ ] `theme/` 내 PHP 파일 검수
- [ ] 최근 수정 시각이 비정상인 파일 탐색 (`Get-ChildItem -Recurse -File | Sort-Object LastWriteTime -Descending | Select -First 20`)

### 4.5 설정
- [ ] `display_errors=Off`, `log_errors=On`
- [ ] 세션 쿠키 `httponly`/`secure`/`samesite`
- [ ] HTTPS 강제 + HSTS
- [ ] 업로드 최대 크기·확장자 제한
- [ ] 불필요한 `allow_url_fopen`/`allow_url_include` off

## 5. 스킨/커스텀 출력 패턴

```php
<?php // 안전: 텍스트 컨텍스트
echo htmlspecialchars($view['wr_subject'] ?? '', ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8'); ?>

<?php // HTML 허용이 필요한 경우: 화이트리스트 정화 후 출력
echo conv_content($view['wr_content'], $view['html'] ?? 0); // g5 정화 함수 사용 (버전별 동작 확인)
?>
```

- `strip_tags()` 단독 사용은 속성 내 이벤트 핸들러를 막지 못한다
- `get_text()` 계열 함수가 있는 버전이면 그것을 우선 사용하되, **버전별 동작을 실제 코드로 확인**한 뒤 판단한다

## 6. 패치 가이드

1. 코어 취약점 → 공식 최신 버전으로 업데이트 (백업 후)
2. 커스텀/스킨 취약점 → 해당 파일만 최소 수정
3. `extend/` 의심 파일 → 내용 전문을 사용자에게 보여주고 삭제 여부 확인 (자동 삭제 금지)
4. 수정 후 `php -l` + 페이지 동작 확인
5. 업로드 디렉터리 실행 차단 설정이 실제 적용됐는지 HTTP 요청으로 확인 (사용자 승인 후)

## 7. 보고서 추가 항목

그누보드 검수 보고서에는 다음을 함께 적는다.

- `G5_VERSION` 값과 코어 업데이트 권고 여부
- 코어 수정 이력(있다면) → 업데이트 시 유실 위험 경고
- `extend/` 파일 목록과 판정
- `install/`, `data/dbconfig.php` 노출 여부
