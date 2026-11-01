#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031,SC2154 # bats runs each @test in a subshell by design; setup assigns f
# Tests for the other rules of hooks/scripts/bash32-lint.sh and its wiring into
# the hook. Helpers and the fixture layout are in bash32-helpers.bash.

load bash32-helpers

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

# --- pattern 3: a %b format stored into a variable ---------------------

@test "bash32-3: single-quoted %b is flagged" {
  lint_one "$PF -v x '%b' \"\$v\""
  assert_finding 3 3
}

@test "bash32-3: message names the guard" {
  lint_one "$PF -v x '%b' \"\$v\""
  assert_finding 3 3
  assert_output_has "guard"
  # The rewrite resets x first, so an empty v leaves x empty, not the old value;
  # the -n guard is not offered, its status aborts a set -e caller.
  assert_output_has "x=; [ -z \"\$v\" ] || $PF -v x %b \"\$v\""
  [[ $output != *"[ -n"* ]] || false
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

# run_hook_at <hook> <file>: the hook script at another path, on the real PATH.
run_hook_at() {
  payload "$2" | "$SH_BIN" "$1"
}

# run_hook_nosc <file>: the hook on a PATH that has no shellcheck.
run_hook_nosc() {
  payload "$1" | PATH="$NOSC_BIN" "$SH_BIN" "$HOOK"
}

# build_nosc_path: NOSC_BIN holds symlinks to the external tools the hook and the
# lint run, and nothing else. Then assert the result has no shellcheck and does
# have jq, so a PATH that still resolves it cannot let the missing-shellcheck
# tests pass for the wrong reason.
build_nosc_path() {
  local tool
  NOSC_BIN="$BATS_TEST_TMPDIR/nosc-bin"
  mkdir -p "$NOSC_BIN"
  for tool in sh jq cat sort head wc tr dirname awk; do
    ln -s "$(type -P "$tool")" "$NOSC_BIN/$tool"
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

# TMPDIR names a directory that does not exist: the notice marker cannot be
# written. The failed redirect must not end the script.
@test "hook: an unwritable notice marker does not stop the run" {
  build_nosc_path
  fixture "$f" '#!/bin/bash' 'v=abc' "$PF -v x '%b' \"\$v\"" "$PF '%s\\n' \"\$x\""

  TMPDIR="$BATS_TEST_TMPDIR/absent/dir" run run_hook_nosc "$f"
  assert_one_object
  [[ $(jqo '.systemMessage // empty') == *"shellcheck is not installed"* ]] || false
  [[ $(jqo '.hookSpecificOutput.additionalContext // empty') == *"[bash32-3]"* ]] || false
}

# jq --arg fails past about 128KB of argument; the context travels on stdin.
@test "hook: findings past 200KB still yield one object with the last finding" {
  build_nosc_path
  line="$PF -v x '%b' \"\$v\""
  {
    printf '%s\n' '#!/bin/bash'
    for _ in $(seq 1000); do
      printf '%s\n' "$line"
    done
    printf '%s\n' "$line # last"
  } >"$f"

  run run_hook_nosc "$f"
  assert_one_object
  [[ $(jqo '.systemMessage // empty') == *"shell lint: 1001 findings"* ]] || false
  ctx=$(jqo '.hookSpecificOutput.additionalContext // empty')
  [ "${#ctx}" -gt 200000 ]
  [[ $ctx == *"$f:1002:"* ]] || false
}

# The lint script is absent beside the hook: its failure is a finding, not a
# clean file.
@test "hook: a lint that cannot run is reported as a bash32-0 finding" {
  lone="$BATS_TEST_TMPDIR/lone"
  mkdir -p "$lone"
  cp "$HOOK" "$lone/shellcheck-on-edit.sh"
  fixture "$f" '#!/bin/sh' "echo \$1"

  run run_hook_at "$lone/shellcheck-on-edit.sh" "$f"
  assert_one_object
  [ "$(jqo .systemMessage)" = "shell lint: 2 findings" ]
  ctx=$(jqo '.hookSpecificOutput.additionalContext // empty')
  [[ $ctx == *"SC2086"* ]] || false
  [[ $ctx == *"$f:1:1: warning: bash 3.2 checks could not run (lint exit "*") [bash32-0]"* ]] || false
}
