#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031 # bats runs each @test in a subshell by design
# Tests for hooks/scripts/bash32-lint.sh and its wiring into the PostToolBatch
# hook (plans/2026-11-01-bash32-lint.md).
#
# The repo's own hook lints this file on every edit, so no line below spells a
# trigger pattern literally: the fixtures are assembled from parts in setup
# (PF, LCA, LNG, LCT, and the non-ASCII bytes as octal escapes) and written to
# files under BATS_TEST_TMPDIR.
#
# Fixture layout: line 1 is a shebang, line 2 a filler, the line under test is
# line 3 (lint_one). Every "not flagged" case runs twice (assert_clean): alone,
# expecting empty output, and followed by an unguarded format-%b sentinel on
# line 4, expecting exactly that one finding. The second run proves the lint
# read the file, so a script that prints nothing at all cannot pass.

setup() {
  HOOK_DIR="$BATS_TEST_DIRNAME/../hooks/scripts"
  LINT="$HOOK_DIR/bash32-lint.sh"
  HOOK="$HOOK_DIR/shellcheck-on-edit.sh"
  SH_BIN=$(command -v sh)
  f="$BATS_TEST_TMPDIR/t.sh"

  PF='printf'
  LCA=LC_ALL
  LNG=LANG
  LCT=LC_CTYPE
  RSQ=$(printf '\342\200\231') # U+2019 right single quotation mark
  EAC=$(printf '\303\251')     # U+00E9 e acute

  SID="bats-$BATS_TEST_NUMBER-$$"
  export TMPDIR="$BATS_TEST_TMPDIR/tmp"
  mkdir -p "$TMPDIR"
}

# --- helpers ----------------------------------------------------------------

# fixture <path> <line>...: write the lines to the file, one per line.
fixture() {
  local path=$1
  shift
  mkdir -p "$(dirname "$path")"
  printf '%s\n' "$@" >"$path"
}

# lint_one <text> [path]: file (default $f) = shebang, filler, <text> (line 3);
# run the lint on it.
lint_one() {
  local target=${2-$f}
  fixture "$target" '#!/bin/sh' ':' "$1"
  run sh "$LINT" "$target"
}

# finding_in <file> <line> <n>: some output line is a bash32-<n> finding for
# <file>:<line>, in the gcc shape file:line:col: warning: message [bash32-n].
finding_in() {
  local want_file=$1 want_line=$2 n=$3 l rest re
  re="^[0-9]+: warning: .+ \\[bash32-$n\\]\$"
  for l in "${lines[@]}"; do
    case $l in
      "$want_file:$want_line:"*)
        rest=${l#"$want_file:$want_line:"}
        if [[ $rest =~ $re ]]; then
          return 0
        fi
        ;;
    esac
  done
  return 1
}

# assert_finding <line> <n>: exit 0 and exactly one finding, for $f:<line>.
assert_finding() {
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  finding_in "$f" "$1" "$2" || {
    printf 'no bash32-%s finding at %s:%s in:\n%s\n' "$2" "$f" "$1" "$output" >&2
    false
  }
}

# assert_output_has <substring>: the combined output contains it verbatim.
assert_output_has() {
  [[ $output == *"$1"* ]] || {
    printf 'output lacks %s:\n%s\n' "$1" "$output" >&2
    false
  }
}

# assert_clean <text>: <text> alone draws nothing; with a sentinel after it the
# sentinel is the only finding.
assert_clean() {
  lint_one "$1"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  fixture "$f" '#!/bin/sh' ':' "$1" "$PF -v s '%b' \"\$sv\""
  run sh "$LINT" "$f"
  assert_finding 4 3
}

# --- pattern 1: unbraced name followed by a byte >= 0x80 ---------------------

@test "bash32-1: quoted unbraced name then a curly quote is flagged" {
  lint_one "echo \"\$p$RSQ\""
  assert_finding 3 1
}

@test "bash32-1: message names the braced fix" {
  lint_one "echo \"\$p$RSQ\""
  [[ $output == *"\${p}"* || $output == *"\${name}"* ]] || false
}

@test "bash32-1: bare unbraced name then a curly quote is flagged" {
  lint_one "echo \$p$RSQ"
  assert_finding 3 1
}

@test "bash32-1: name with underscore and digit then a curly quote is flagged" {
  lint_one "echo \"\$my_var1$RSQ\""
  assert_finding 3 1
}

@test "bash32-1: name then an accented letter is flagged" {
  lint_one "echo \"\$p$EAC\""
  assert_finding 3 1
}

@test "bash32-1: name at the end of the line before a high byte is flagged" {
  lint_one "x=\$name$EAC"
  assert_finding 3 1
}

@test "bash32-1 not flagged: braced name then a curly quote" {
  assert_clean "echo \"\${p}$RSQ\""
}

@test "bash32-1 not flagged: positional parameter then a curly quote" {
  assert_clean "echo \"\$1$RSQ\""
}

@test "bash32-1 not flagged: name then ASCII" {
  assert_clean "echo \"\$p-x \$p. \$p\""
}

@test "bash32-1 not flagged: non-ASCII text after a space or braces" {
  assert_clean "echo \"\$p $RSQ \${q}$EAC\""
}

# --- pattern 2: temporary locale assignment in front of a builtin ------------

@test "bash32-2: LC_ALL prefix on printf %q is flagged" {
  lint_one "$LCA=C $PF %q \"\$x\""
  assert_finding 3 2
}

@test "bash32-2: message mentions SC2030 and the subshell fix" {
  lint_one "$LCA=C $PF %q \"\$x\""
  assert_finding 3 2
  assert_output_has "SC2030"
  assert_output_has "\$($LCA=C;"
}

@test "bash32-2: LC_ALL prefix on read is flagged" {
  lint_one "$LCA=C read -r a"
  assert_finding 3 2
}

@test "bash32-2: LC_ALL prefix on printf -v with %s is flagged as 2 only" {
  lint_one "$LCA=C $PF -v x '%s' \"\$y\""
  assert_finding 3 2
}

@test "bash32-2: LC_ALL prefix on another builtin (echo) is flagged" {
  lint_one "$LCA=C echo hi"
  assert_finding 3 2
}

@test "bash32-2: LC_ALL prefix on builtin printf is flagged" {
  lint_one "$LCA=C builtin $PF %q \"\$x\""
  assert_finding 3 2
}

@test "bash32-2: LANG prefix is flagged" {
  lint_one "$LNG=C $PF %q \"\$x\""
  assert_finding 3 2
}

@test "bash32-2: LC_CTYPE prefix is flagged" {
  lint_one "$LCT=C.UTF-8 $PF %q \"\$x\""
  assert_finding 3 2
}

@test "bash32-2: prefix after another assignment is flagged" {
  lint_one "FOO=1 $LCA=C $PF %q \"\$x\""
  assert_finding 3 2
}

@test "bash32-2: prefix before another assignment is flagged" {
  lint_one "$LCA=C FOO=1 $PF %q \"\$x\""
  assert_finding 3 2
}

@test "bash32-2: prefix after a semicolon is flagged" {
  lint_one "true; $LCA=C $PF %q \"\$x\""
  assert_finding 3 2
}

@test "bash32-2: prefix after && is flagged" {
  lint_one "true && $LCA=C $PF %q \"\$x\""
  assert_finding 3 2
}

@test "bash32-2: prefix after then is flagged" {
  lint_one "if true; then $LCA=C $PF %q \"\$x\"; fi"
  assert_finding 3 2
}

@test "bash32-2: prefix inside a quoted command substitution is flagged" {
  lint_one "[ \"\$($LCA=C $PF %q \"\$x\")\" = y ]"
  assert_finding 3 2
}

@test "bash32-2: prefix inside an assigned command substitution is flagged" {
  lint_one "v=\$($LCA=C $PF %q \"\$x\")"
  assert_finding 3 2
}

@test "bash32-2: indented prefix at the start of a line is flagged" {
  lint_one "    $LCA=C $PF %q \"\$x\""
  assert_finding 3 2
}

@test "bash32-2: prefix inside a double-quoted assigned substitution is flagged" {
  lint_one "v=\"\$($LCA=C $PF %q \"\$x\")\""
  assert_finding 3 2
}

@test "bash32-2: prefix inside a double-quoted local substitution is flagged" {
  lint_one "local v=\"\$($LCA=C $PF %q \"\$x\")\""
  assert_finding 3 2
}

@test "bash32-2: prefix inside a substitution mid-word is flagged" {
  lint_one "echo a\"\$($LCA=C $PF %q \"\$x\")\""
  assert_finding 3 2
}

@test "bash32-2: prefix inside a substitution after an option equals is flagged" {
  lint_one "f --o=\$($LCA=C $PF %q \"\$x\")"
  assert_finding 3 2
}

@test "bash32-2: prefix inside a process substitution (input) is flagged" {
  lint_one "cat <($LCA=C $PF %q \"\$x\")"
  assert_finding 3 2
}

@test "bash32-2: prefix inside a process substitution (output) is flagged" {
  lint_one "tee >($LCA=C $PF %q \"\$x\")"
  assert_finding 3 2
}

@test "bash32-2: prefix inside backticks is flagged" {
  lint_one "v=\`$LCA=C $PF %q \"\$x\"\`"
  assert_finding 3 2
}

@test "bash32-2: prefix inside an assigned local substitution is flagged" {
  lint_one "local v=\$($LCA=C $PF %q \"\$x\")"
  assert_finding 3 2
}

@test "bash32-2: prefix inside a subshell is flagged" {
  lint_one "($LCA=C $PF %q \"\$x\")"
  assert_finding 3 2
}

@test "bash32-2: prefix inside a substitution after a path prefix is flagged" {
  lint_one "p=\"\$dir/\$($LCA=C $PF %q \"\$f\")\""
  assert_finding 3 2
}

@test "bash32-2: prefix inside a substitution in a parameter default is flagged" {
  lint_one "v=\${x:-\$($LCA=C $PF %q y)}"
  assert_finding 3 2
}

@test "bash32-2: prefix inside the second of two assigned backtick words is flagged" {
  lint_one "a=\`date +%s\` b=\`$LCA=C $PF %q x\`"
  assert_finding 3 2
}

@test "bash32-2: prefix inside a backtick word after a closed one is flagged" {
  lint_one "echo \`date\` \`$LCA=C $PF %q x\`"
  assert_finding 3 2
}

@test "bash32-2: prefix after a space inside a double-quoted substitution is flagged" {
  lint_one "x=\"\$( $LCA=C $PF %q \"\$y\" )\""
  assert_finding 3 2
}

@test "bash32-2: prefix after a space inside an assigned substitution is flagged" {
  lint_one "x=\$( $LCA=C $PF %q \"\$y\" )"
  assert_finding 3 2
}

@test "bash32-2: prefix after a space inside backticks is flagged" {
  lint_one "x=\` $LCA=C $PF %q \"\$y\" \`"
  assert_finding 3 2
}

@test "bash32-2: prefix after an assignment with a closed backtick is flagged" {
  lint_one "FOO=\`date\` $LCA=C $PF %q x"
  assert_finding 3 2
}

@test "bash32-2 not flagged: prefix before an external command" {
  assert_clean "$LCA=C sed 's/a/b/' file"
}

@test "bash32-2 not flagged: other prefix before an external command" {
  assert_clean "FOO=1 $LCA=C sort file"
}

@test "bash32-2 not flagged: standalone assignment then printf" {
  assert_clean "$LCA=C; $PF %q \"\$x\""
}

@test "bash32-2 not flagged: export of the assignment" {
  assert_clean "export $LCA=C"
}

@test "bash32-2 not flagged: assignment inside a command substitution" {
  assert_clean "y=\$($LCA=C; $PF %q \"\$x\")"
}

@test "bash32-2 not flagged: prefix before exec of an external command" {
  assert_clean "$LCA=C exec sort \"\$@\""
}

@test "bash32-2 not flagged: prefix before command running an external one" {
  assert_clean "$LCA=C command grep x"
}

@test "bash32-2 not flagged: external command in a double-quoted substitution" {
  assert_clean "v=\"\$($LCA=C sort f)\""
}

@test "bash32-2 not flagged: external command in an assigned substitution" {
  assert_clean "v=\$($LCA=C sort f)"
}

@test "bash32-2 not flagged: external command in a process substitution" {
  assert_clean "cat <($LCA=C sort f)"
}

@test "bash32-2 not flagged: external command in backticks" {
  assert_clean "v=\`$LCA=C sort f\`"
}

@test "bash32-2 not flagged: standalone assignment then printf in backticks" {
  assert_clean "v=\`$LCA=C; $PF %q \"\$x\"\`"
}

@test "bash32-2 not flagged: words after a closing backtick are arguments" {
  assert_clean "echo \`date\` $LCA=C $PF %q x"
}

@test "bash32-2 not flagged: words after a closing paren are arguments" {
  assert_clean "echo \"\$(date)\" $LCA=C $PF %q x"
}

@test "bash32-2 not flagged: a backtick closed in another word than its opener" {
  assert_clean "echo \`date +%s\` $LCA=C $PF %q x"
}

@test "bash32-2 not flagged: words after a command that is a backtick substitution" {
  assert_clean "\`date\` $LCA=C $PF %q x"
}

@test "bash32-2 not flagged: prefix of an external command with a substitution value" {
  assert_clean "$LCA=C FOO=\$($PF x) make"
}

@test "bash32-2 not flagged: prefix of an external command with a backtick value" {
  assert_clean "$LCA=C FOO=\`$PF x\` make"
}

# --- pattern 3: a %b format stored into a variable ---------------------

@test "bash32-3: single-quoted %b is flagged" {
  lint_one "$PF -v x '%b' \"\$v\""
  assert_finding 3 3
}

@test "bash32-3: message names the guard" {
  lint_one "$PF -v x '%b' \"\$v\""
  assert_finding 3 3
  assert_output_has "guard"
}

@test "bash32-3: double-quoted %b is flagged" {
  lint_one "$PF -v x \"%b\" \"\$v\""
  assert_finding 3 3
}

@test "bash32-3: unquoted %b is flagged" {
  lint_one "$PF -v x %b \"\$v\""
  assert_finding 3 3
}

@test "bash32-3: %b among other format text is flagged" {
  lint_one "$PF -v x 'a=%s b=%b;' \"\$u\" \"\$v\""
  assert_finding 3 3
}

@test "bash32-3: indented line is flagged" {
  lint_one "      $PF -v x '%b' \"\$v\""
  assert_finding 3 3
}

@test "bash32-3: a guard on an earlier line does not count" {
  fixture "$f" '#!/bin/sh' "[ -n \"\$v\" ]" "$PF -v x '%b' \"\$v\""
  run sh "$LINT" "$f"
  assert_finding 3 3
}

@test "bash32-3: inverted guard, -n then ||, is flagged" {
  lint_one "[ -n \"\$v\" ] || $PF -v x '%b' \"\$v\""
  assert_finding 3 3
}

@test "bash32-3: inverted guard, -z then &&, is flagged" {
  lint_one "[ -z \"\$v\" ] && $PF -v x '%b' \"\$v\""
  assert_finding 3 3
}

@test "bash32-3 not flagged: guarded with [[ -z ]] || on the same line" {
  assert_clean "[[ -z \$v ]] || $PF -v x '%b' \"\$v\""
}

@test "bash32-3 not flagged: guarded with || on the same line" {
  assert_clean "[ -z \"\$v\" ] || $PF -v x '%b' \"\$v\""
}

@test "bash32-3 not flagged: guarded with && on the same line" {
  assert_clean "[ -n \"\$v\" ] && $PF -v x '%b' \"\$v\""
}

@test "bash32-3 not flagged: %s format" {
  assert_clean "$PF -v x '%s' \"\$v\""
}

@test "bash32-3 not flagged: %b without -v" {
  assert_clean "$PF '%b' \"\$v\""
}

# --- the script as a whole ---------------------------------------------------

@test "lint: a clean file gives exit 0 and empty output" {
  fixture "$f" '#!/bin/sh' 'v=abc' "$PF '%s\\n' \"\$v\""
  run sh "$LINT" "$f"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  # Liveness: the same script on a flagged file is not silent.
  lint_one "$PF -v x '%b' \"\$v\""
  assert_finding 3 3
}

@test "lint: a path containing spaces is reported verbatim" {
  spaced="$BATS_TEST_TMPDIR/dir with space/a b.sh"
  lint_one "$PF -v x '%b' \"\$v\"" "$spaced"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  finding_in "$spaced" 3 3 || false
}

@test "lint: three patterns in one file give three findings with their lines" {
  fixture "$f" '#!/bin/sh' \
    "echo \"\$p$RSQ\"" \
    "$LCA=C $PF %q \"\$x\"" \
    "$PF -v x '%b' \"\$v\""
  run sh "$LINT" "$f"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 3 ]
  finding_in "$f" 2 1 || false
  finding_in "$f" 3 2 || false
  finding_in "$f" 4 3 || false
}

@test "lint: several files are each reported under their own path" {
  g="$BATS_TEST_TMPDIR/g.sh"
  fixture "$f" '#!/bin/sh' ':' "$PF -v x '%b' \"\$v\""
  fixture "$g" '#!/bin/sh' "$LCA=C $PF %q \"\$x\""
  run sh "$LINT" "$f" "$g"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]
  finding_in "$f" 3 3 || false
  finding_in "$g" 2 2 || false
}

@test "lint: an awk failure is reported as a bash32-0 finding on line 1" {
  stub="$BATS_TEST_TMPDIR/stub-bin"
  mkdir -p "$stub"
  printf '#!/bin/sh\nexit 2\n' >"$stub/awk"
  chmod +x "$stub/awk"
  fixture "$f" '#!/bin/sh' 'v=abc'
  PATH="$stub:$PATH" run sh "$LINT" "$f"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  finding_in "$f" 1 0 || false
  assert_output_has "awk exit 2"
}

# --- hook level --------------------------------------------------------------

# payload <file>: a PostToolBatch payload with one Write call on <file>.
payload() {
  jq -n -c --arg sid "$SID" --arg f "$1" \
    '{session_id: $sid, tool_calls: [{tool_name: "Write", tool_input: {file_path: $f}}]}'
}

# run_hook <file>: the hook on the real PATH.
run_hook() {
  payload "$1" | "$SH_BIN" "$HOOK"
}

# run_hook_nosc <file>: the hook on a PATH that has no shellcheck.
run_hook_nosc() {
  payload "$1" | PATH="$NOSC_BIN" "$SH_BIN" "$HOOK"
}

# build_nosc_path: NOSC_BIN holds symlinks to the tools the hook and the lint
# may need, and nothing else. shellcheck is deliberately absent.
#   required: sh jq cat sort head wc tr dirname grep sed awk
#   optional (linked when present): tail cut expr uniq basename printf mkdir rm
# The hook itself uses sh, jq, cat, sort, head, wc, tr and dirname; grep, sed
# and awk are for whatever the lint script plausibly uses. Then assert the
# result has no shellcheck and does have jq, so a PATH that still resolves it
# cannot let the missing-shellcheck tests pass for the wrong reason.
build_nosc_path() {
  local tool src
  NOSC_BIN="$BATS_TEST_TMPDIR/nosc-bin"
  mkdir -p "$NOSC_BIN"
  for tool in sh jq cat sort head wc tr dirname grep sed awk \
    tail cut expr uniq basename printf mkdir rm; do
    src=$(type -P "$tool" || true)
    if [ -z "$src" ]; then
      case $tool in
        tail | cut | expr | uniq | basename | printf | mkdir | rm) continue ;;
      esac
      printf 'required tool missing on this box: %s\n' "$tool" >&2
      return 1
    fi
    ln -s "$src" "$NOSC_BIN/$tool"
  done
  [ ! -e "$NOSC_BIN/shellcheck" ]
  run env PATH="$NOSC_BIN" "$SH_BIN" -c 'command -v shellcheck; command -v jq'
  [ "$output" = "$NOSC_BIN/jq" ]
}

# jqo <filter>: apply a jq filter to the last output.
jqo() {
  printf '%s\n' "$output" | jq -r "$1"
}

# assert_one_object: the output is exactly one JSON value.
assert_one_object() {
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | jq -s 'length')" = 1 ]
}

@test "hook: a bash32 finding on a shellcheck-clean file yields one JSON object" {
  fixture "$f" '#!/bin/bash' 'v=abc' "$PF -v x '%b' \"\$v\"" "$PF '%s\\n' \"\$x\""
  run shellcheck -x -f gcc "$f"
  [ "$status" -eq 0 ]
  [ -z "$output" ]

  run run_hook "$f"
  assert_one_object
  [ "$(jqo .systemMessage)" = "shell lint: 1 findings" ]
  [ "$(jqo .hookSpecificOutput.hookEventName)" = PostToolBatch ]
  ctx=$(jqo '.hookSpecificOutput.additionalContext // empty')
  [[ $ctx == *"$f:3:"* ]] || false
  [[ $ctx == *"[bash32-3]"* ]] || false
}

@test "hook: missing shellcheck still reports the finding in one object with the notice" {
  build_nosc_path
  fixture "$f" '#!/bin/bash' 'v=abc' "$PF -v x '%b' \"\$v\"" "$PF '%s\\n' \"\$x\""

  run run_hook_nosc "$f"
  assert_one_object
  msg=$(jqo '.systemMessage // empty')
  [[ $msg == *"shellcheck is not installed"* ]] || false
  [[ $msg == *"shell lint: 1 findings"* ]] || false
  ctx=$(jqo '.hookSpecificOutput.additionalContext // empty')
  [[ $ctx == *"$f:3:"* ]] || false
  [[ $ctx == *"[bash32-3]"* ]] || false
}

@test "hook: the missing-shellcheck notice is not repeated in the same session" {
  build_nosc_path
  fixture "$f" '#!/bin/bash' 'v=abc' "$PF -v x '%b' \"\$v\"" "$PF '%s\\n' \"\$x\""

  run run_hook_nosc "$f"
  assert_one_object
  [[ $(jqo '.systemMessage // empty') == *"shellcheck is not installed"* ]] || false
  [[ $(jqo '.hookSpecificOutput.additionalContext // empty') == *"[bash32-3]"* ]] || false

  run run_hook_nosc "$f"
  assert_one_object
  [ "$(jqo '.systemMessage // empty')" = "shell lint: 1 findings" ]
  [[ $(jqo '.hookSpecificOutput.additionalContext // empty') == *"[bash32-3]"* ]] || false
}

@test "hook: shellcheck findings alone use the combined summary wording" {
  fixture "$f" '#!/bin/sh' "echo \$1"
  run shellcheck -x -f gcc "$f"
  [ "${#lines[@]}" -eq 1 ]

  run run_hook "$f"
  assert_one_object
  [ "$(jqo .systemMessage)" = "shell lint: 1 findings" ]
  ctx=$(jqo '.hookSpecificOutput.additionalContext // empty')
  [[ $ctx == *"SC2086"* ]] || false
  [[ $ctx != *"bash32"* ]] || false
}

@test "hook: shellcheck and bash32 findings are counted and reported together" {
  fixture "$f" '#!/bin/bash' "echo \$1" "$PF -v x '%b' \"\$1\"" "$PF '%s\\n' \"\$x\""

  run run_hook "$f"
  assert_one_object
  [ "$(jqo .systemMessage)" = "shell lint: 2 findings" ]
  ctx=$(jqo '.hookSpecificOutput.additionalContext // empty')
  [[ $ctx == *"SC2086"* ]] || false
  [[ $ctx == *"$f:3:"* ]] || false
  [[ $ctx == *"[bash32-3]"* ]] || false
}
