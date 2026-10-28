# Changelog

All notable changes to this project are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/), versioning follows [SemVer](https://semver.org/).

## [1.0.0] - 2026-10-28

### Added

- **Skill**: `php-security-review` with a 7-step workflow (Step 0 → 6) and a mandatory version gate (Step 0.5).
- **Scanner** `scripts/scan.ps1`
  - 37 heuristic rules covering SQLi, XSS, command injection, code execution, deserialization, LFI/RFI, file read/write, uploads, SSRF, header/cookie injection, open redirect, weak hashing/randomness, loose comparison, superglobal usage, hardcoded secrets, debug leftovers, session handling, XXE, and Gnuboard5-specific patterns.
  - `-Encoding Auto` detection for UTF-8 / CP949 (EUC-KR) mixed codebases.
  - `-MinSeverity` filter and `-MaxPerRule` cap to control noise on large CMS codebases.
  - CSV export via `-Csv`.
- **Version checker** `scripts/version-check.ps1`
  - Parses `G5_GNUBOARD_VER` / `G5_YOUNGCART_VER` from `version.php`.
  - Compares against the latest Gnuboard5 GitHub release.
  - Compares the PHP version against the PHP2Shell (CVE-2026-109618 / CVE-2026-109619) fixed-version table.
  - `-Domain` mode: estimates the PHP version from `X-Powered-By` and the `/install/` page.
- **References**
  - `checklist.md` — CWE-mapped vulnerability catalog.
  - `php8-hardening.md` — PDO, session, upload, CSRF, SSRF, header hardening snippets.
  - `gnuboard.md` — Gnuboard5 profile (core vs. custom, `data/`, `install/`, `extend/`).
  - `advisories.md` — dated CVE snapshot and update procedure.
- **Command** `commands/phpsec.md` — `/phpsec` slash command that forces the version gate before code review.
- **Docs** — bilingual README, installation guide, usage guide, sample report.
- **License** — MIT.

### Notes

- The scanner reports candidates only; confirmation requires source → sink data-flow tracing.
- `references/advisories.md` is a snapshot (2026-10-28) and must be refreshed periodically.
