#!/bin/sh
# PostToolBatch hook: shellcheck every shell file this batch wrote or edited.
# PostToolBatch fires once per turn (single or parallel calls) carrying every
# tool call in .tool_calls, so each file's final settled content is linted
# exactly once -- no per-edit duplicates, no debounce.
# Exit 0 always: silent (no shell file touched, tool missing, or clean) or JSON.
# Findings: full output goes to the model via additionalContext; the user sees
# only a one-line "shellcheck failed (N lines)" summary via systemMessage.
# Missing shellcheck with a shell file in the batch = one-time per-session notice.

input=$(cat)

command -v jq >/dev/null 2>&1 || exit 0

sid=$(printf '%s' "$input" | jq -r '.session_id // "global"')

# Deduped file paths from this batch's Write/Edit calls. A read-only batch
# yields nothing here and exits silently.
files=$(printf '%s' "$input" | jq -r '
  .tool_calls[]? | select(.tool_name == "Write" or .tool_name == "Edit")
  | .tool_input.file_path // empty' | sort -u)
[ -n "$files" ] || exit 0

if ! command -v shellcheck >/dev/null 2>&1; then
  marker="${TMPDIR:-/tmp}/shell-scripting-no-shellcheck.$sid"
  if [ ! -e "$marker" ]; then
    : > "$marker" 2>/dev/null || :
    printf '{"systemMessage":"shell-scripting plugin: shellcheck is not installed — automatic lint feedback is inactive."}\n'
  fi
  exit 0
fi

# Detect shell files by extension, else by shebang sniff. Only sh/bash/dash/ksh/
# bats interpreters: a loose match would feed fish/zsh to shellcheck and produce
# noise. Misses "#!/bin/sh -eu" option suffixes only when the interpreter name
# itself is unusual.
is_shell_file() {
  case "$1" in
    *.sh|*.bash|*.bats) return 0 ;;
  esac
  shebang=$(head -n 1 "$1" 2>/dev/null)
  case "$shebang" in
    '#!'*/sh|'#!'*/bash|'#!'*/dash|'#!'*/ksh|'#!'*/bats) return 0 ;;
    '#!'*' sh'|'#!'*' bash'|'#!'*' dash'|'#!'*' ksh'|'#!'*' bats') return 0 ;;
    '#!'*/sh\ *|'#!'*/bash\ *|'#!'*/dash\ *|'#!'*/ksh\ *) return 0 ;;
    '#!'*' sh '*|'#!'*' bash '*|'#!'*' dash '*|'#!'*' ksh '*) return 0 ;;
  esac
  return 1
}

# Collect existing shell files into the positional parameters. set -f disables
# pathname expansion so the newline split is literal (a path containing a glob
# char is not expanded); Write/Edit file_path values never contain newlines.
set --
set -f
IFS='
'
# shellcheck disable=SC2086 # deliberate newline split; globbing disabled above
for file in $files; do
  [ -n "$file" ] || continue
  [ -f "$file" ] || continue
  is_shell_file "$file" || continue
  set -- "$@" "$file"
done
unset IFS
set +f
[ "$#" -gt 0 ] || exit 0

# -f gcc: one finding per line ("file:line:col: severity: message [SCxxxx]"),
# self-identifying by path so findings across multiple files aggregate cleanly.
# -x: follow `source`/`.` directives into external files so sourced helpers are
# checked in context instead of flagged unresolved (SC1091). Clean -> exit 0.
if findings=$(shellcheck -x -f gcc "$@" 2>/dev/null); then
  exit 0
fi
# non-zero with no output = shellcheck operational error, not lint results
[ -n "$findings" ] || exit 0

count=$(printf '%s\n' "$findings" | wc -l | tr -d '[:space:]')
context=$(printf 'shellcheck findings (fix or justify with an inline disable):\n%s' "$findings")

jq -n -c \
  --arg msg "shellcheck failed ($count lines)" \
  --arg ctx "$context" \
  '{systemMessage: $msg, suppressOutput: true, hookSpecificOutput: {hookEventName: "PostToolBatch", additionalContext: $ctx}}'
exit 0
