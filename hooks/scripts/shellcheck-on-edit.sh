#!/bin/sh
# PostToolUse hook: shellcheck any shell file Claude just wrote or edited.
# Exit 0 = silent pass (not a shell file, tool missing, or clean) or JSON output.
# Findings: full output goes to the model via additionalContext; the user sees
# only a one-line "shellcheck failed (N lines)" summary via systemMessage.
# Missing shellcheck on a shell file = one-time systemMessage notice per session.

input=$(cat)

command -v jq >/dev/null 2>&1 || exit 0

file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')
[ -n "$file" ] && [ -f "$file" ] || exit 0

case "$file" in
  *.sh|*.bash|*.bats) ;;
  *)
    # No shell extension: sniff the shebang. Misses "#!/bin/sh -eu" style
    # option suffixes only when the interpreter name itself is unusual.
    shebang=$(head -n 1 "$file" 2>/dev/null)
    case "$shebang" in
      '#!'*/sh|'#!'*/bash|'#!'*/dash|'#!'*/ksh|'#!'*/bats) ;;
      '#!'*' sh'|'#!'*' bash'|'#!'*' dash'|'#!'*' ksh'|'#!'*' bats') ;;
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

# -f gcc: one finding per line ("file:line:col: severity: message [SCxxxx]"),
# no carets/source echoes/wiki blocks — terse and directly model-readable.
if findings=$(shellcheck -f gcc "$file" 2>/dev/null); then
  exit 0
fi
# non-zero with no findings = shellcheck operational error, not lint results
[ -n "$findings" ] || exit 0

count=$(printf '%s\n' "$findings" | wc -l | tr -d '[:space:]')
context=$(printf 'shellcheck findings for %s (fix or justify with an inline disable):\n%s' "$file" "$findings")

jq -n -c \
  --arg msg "shellcheck failed ($count lines)" \
  --arg ctx "$context" \
  '{systemMessage: $msg, suppressOutput: true, hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $ctx}}'
exit 0
