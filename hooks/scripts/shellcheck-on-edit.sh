#!/bin/sh
# PostToolBatch hook: lint every shell file this batch wrote or edited, with
# the usual linter and with bash32-lint.sh (bash 3.2 traps it cannot see).
# PostToolBatch fires once per turn (single or parallel calls) carrying every
# tool call in .tool_calls, so each file's final settled content is linted
# exactly once -- no per-edit duplicates, no debounce.
# Exit 0 always: silent (no shell file touched, jq missing, or clean) or one JSON
# object.
# Findings: full output goes to the model via additionalContext; the user sees
# only a one-line "shell lint: N findings" summary via systemMessage.
# Missing shellcheck with a shell file in the batch = one-time per-session notice
# in the same systemMessage; the bash 3.2 pass still runs.

input=$(cat)

command -v jq >/dev/null 2>&1 || exit 0

sid=$(printf '%s' "$input" | jq -r '.session_id // "global"')

# Deduped file paths from this batch's Write/Edit calls. A read-only batch
# yields nothing here and exits silently.
files=$(printf '%s' "$input" | jq -r '
  .tool_calls[]? | select(.tool_name == "Write" or .tool_name == "Edit")
  | .tool_input.file_path // empty' | sort -u)
[ -n "$files" ] || exit 0

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

notice=
have_sc=
if command -v shellcheck >/dev/null 2>&1; then
  have_sc=1
else
  marker="${TMPDIR:-/tmp}/shell-scripting-no-shellcheck.$sid"
  if [ ! -e "$marker" ]; then
    ( : > "$marker" ) 2>/dev/null || :
    notice='shell-scripting plugin: shellcheck is not installed — shellcheck feedback is inactive; the bash 3.2 checks still run.'
  fi
fi

# The linter runs with -f gcc: one finding per line ("file:line:col: severity:
# message [SCxxxx]"), self-identifying by path so findings across multiple files
# aggregate cleanly. -x: follow `source`/`.` directives into external files so
# sourced helpers are checked in context instead of flagged unresolved (SC1091).
# Its status is not read: it exits 1 when it has findings.
# The bash 3.2 pass runs on the same file list, with or without it. Each tool's
# output ends in a newline, so the two concatenate line by line. bash32-lint.sh
# always exits 0, so a non-zero status (a missing or unparsable script) is
# itself a finding, on the first file.
findings=$({
  [ -z "$have_sc" ] || shellcheck -x -f gcc "$@" 2>/dev/null
  sh "$(dirname "$0")/bash32-lint.sh" "$@" 2>/dev/null
})
lint_rc=$?
if [ "$lint_rc" -ne 0 ]; then
  findings=$(
    [ -z "$findings" ] || printf '%s\n' "$findings"
    printf '%s:1:1: warning: bash 3.2 checks could not run (lint exit %s) [bash32-0]' "$1" "$lint_rc"
  )
fi

if [ -z "$findings" ]; then
  [ -n "$notice" ] || exit 0
  jq -n -c --arg msg "$notice" '{systemMessage: $msg}'
  exit 0
fi

count=$(printf '%s\n' "$findings" | wc -l | tr -d '[:space:]')
summary="shell lint: $count findings"
if [ -n "$notice" ]; then
  summary="$notice $summary"
fi

printf 'shell lint findings (fix, or justify a shellcheck finding with an inline disable):\n%s' "$findings" |
  jq -Rs -c --arg msg "$summary" \
    '{systemMessage: $msg, suppressOutput: true, hookSpecificOutput: {hookEventName: "PostToolBatch", additionalContext: .}}'
exit 0
