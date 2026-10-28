#!/usr/bin/env bash
# php-security-review installer for macOS / Linux
#
# Usage:
#   ./scripts/install.sh --target all --scope global
#   ./scripts/install.sh --target cursor --scope project --project /path/to/site --with-command
#   ./scripts/install.sh --list --target all --scope global

set -euo pipefail

TARGET="opencode"
SCOPE="global"
PROJECT="."
WITH_COMMAND=0
LIST=0

while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    --scope) SCOPE="$2"; shift 2 ;;
    --project) PROJECT="$2"; shift 2 ;;
    --with-command) WITH_COMMAND=1; shift ;;
    --list) LIST=1; shift ;;
    -h|--help)
      sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC="$REPO_DIR/skills/php-security-review"
PROJ="$(cd "$PROJECT" && pwd)"

[ -d "$SRC" ] || { echo "skill not found: $SRC" >&2; exit 1; }

dest_for() {
  case "$1" in
    opencode)
      [ "$SCOPE" = "global" ] && echo "$HOME/.config/opencode/skills/php-security-review" || echo "$PROJ/.opencode/skills/php-security-review" ;;
    claude)
      [ "$SCOPE" = "global" ] && echo "$HOME/.claude/skills/php-security-review" || echo "$PROJ/.claude/skills/php-security-review" ;;
    codex)
      [ "$SCOPE" = "global" ] && echo "$HOME/.agents/skills/php-security-review" || echo "$PROJ/.agents/skills/php-security-review" ;;
    cursor)
      [ "$SCOPE" = "global" ] && echo "$HOME/.cursor/skills/php-security-review" || echo "$PROJ/.cursor/skills/php-security-review" ;;
    copilot)
      [ "$SCOPE" = "global" ] && echo "$HOME/.copilot/skills/php-security-review" || echo "$PROJ/.github/skills/php-security-review" ;;
    antigravity)
      [ "$SCOPE" = "global" ] && echo "$HOME/.gemini/config/skills/php-security-review" || echo "$PROJ/.agents/skills/php-security-review" ;;
    *) echo "unknown target: $1" >&2; exit 1 ;;
  esac
}

command_for() {
  case "$1" in
    opencode)
      [ "$SCOPE" = "global" ] && echo "$HOME/.config/opencode/commands/phpsec.md" || echo "$PROJ/.opencode/commands/phpsec.md" ;;
    claude)
      [ "$SCOPE" = "global" ] && echo "$HOME/.claude/commands/phpsec.md" || echo "$PROJ/.claude/commands/phpsec.md" ;;
    *) echo "" ;;
  esac
}

if [ "$TARGET" = "all" ]; then
  TARGETS="opencode claude codex cursor copilot antigravity"
else
  TARGETS="$TARGET"
fi

echo ""
echo "php-security-review install ($SCOPE)"
echo "source: $SRC"
echo ""

SEEN=""
for t in $TARGETS; do
  dest="$(dest_for "$t")"
  if echo "$SEEN" | grep -qxF "$dest"; then
    printf '%-12s %-8s %-7s %s\n' "$t" "$SCOPE" "shared" "$dest"
    continue
  fi
  SEEN="$SEEN
$dest"

  if [ "$LIST" -eq 1 ]; then
    printf '%-12s %-8s %-7s %s\n' "$t" "$SCOPE" "planned" "$dest"
    continue
  fi

  mkdir -p "$dest"
  cp -R "$SRC/." "$dest/"
  printf '%-12s %-8s %-7s %s\n' "$t" "$SCOPE" "copied" "$dest"

  if [ "$WITH_COMMAND" -eq 1 ]; then
    cmd="$(command_for "$t")"
    if [ -n "$cmd" ] && [ -f "$REPO_DIR/commands/phpsec.md" ]; then
      mkdir -p "$(dirname "$cmd")"
      cp "$REPO_DIR/commands/phpsec.md" "$cmd"
      printf '%-12s %-8s %-7s %s\n' "$t" "$SCOPE" "command" "$cmd"
    fi
  fi
done

echo ""
if [ "$LIST" -eq 1 ]; then
  echo "list mode: nothing copied."
else
  echo "done. restart your agent and look for 'php-security-review'."
  echo "see docs/portable.md"
fi
