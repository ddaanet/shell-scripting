#!/bin/sh
# PostToolUse hook: shellcheck any shell file Claude just wrote or edited.
# Exit 0 = silent pass (not a shell file, tool missing, or clean).
# Exit 2 = findings on stderr, fed back to Claude.
# Missing shellcheck on a shell file = one-time systemMessage notice per session.

input=$(cat)

command -v jq >/dev/null 2>&1 || exit 0

file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')
[ -n "$file" ] && [ -f "$file" ] || exit 0

case "$file" in
  *.sh|*.bash) ;;
  *)
    # No shell extension: sniff the shebang. Misses "#!/bin/sh -eu" style
    # option suffixes only when the interpreter name itself is unusual.
    shebang=$(head -n 1 "$file" 2>/dev/null)
    case "$shebang" in
      '#!'*/sh|'#!'*/bash|'#!'*/dash|'#!'*/ksh) ;;
      '#!'*' sh'|'#!'*' bash'|'#!'*' dash'|'#!'*' ksh') ;;
      '#!'*/sh\ *|'#!'*/bash\ *|'#!'*/dash\ *|'#!'*/ksh\ *) ;;
      '#!'*' sh '*|'#!'*' bash '*|'#!'*' dash '*|'#!'*' ksh '*) ;;
      *) exit 0 ;;
    esac
    ;;
esac

if ! command -v shellcheck >/dev/null 2>&1; then
  sid=$(printf '%s' "$input" | jq -r '.session_id // "global"')
  marker="${TMPDIR:-/tmp}/shell-scripting-no-shellcheck.$sid"
  if [ ! -e "$marker" ]; then
    : > "$marker" 2>/dev/null || :
    printf '{"systemMessage":"shell-scripting plugin: shellcheck is not installed — automatic lint feedback is inactive."}\n'
  fi
  exit 0
fi

if findings=$(shellcheck "$file" 2>/dev/null); then
  exit 0
fi
# non-zero with no findings = shellcheck operational error, not lint results
[ -n "$findings" ] || exit 0

{
  printf 'shellcheck findings for %s (fix or justify with an inline disable):\n' "$file"
  printf '%s\n' "$findings" | head -n 60
} >&2
exit 2
