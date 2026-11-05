#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031,SC2154 # bats runs each @test in a subshell by design; setup assigns f
# Tests for which files hooks/scripts/shellcheck-on-edit.sh lints (FR5, FR6,
# FR8) and for its notice-only output (FR7). Helpers and the fixture layout are
# in bash32-helpers.bash.

load bash32-helpers

# payload_calls <Tool=path>...: a payload with one call per argument.
payload_calls() {
  jq -n -c --arg sid "$SID" '
    {session_id: $sid, tool_calls: ($ARGS.positional | map(
      capture("^(?<t>[^=]*)=(?<p>.*)$")
      | {tool_name: .t, tool_input: {file_path: .p}}))}' --args "$@"
}

# write_bad <path> <first line>: first line, a filler, then a bash32-3 finding
# on line 3, and a clean line after it.
write_bad() {
  fixture "$1" "$2" 'v=abc' "$PF -v x '%b' \"\$v\"" "$PF '%s\\n' \"\$x\""
}

# assert_linted: the last run printed one object whose context holds the finding.
assert_linted() {
  assert_one_object
  [[ $(jqo '.hookSpecificOutput.additionalContext // empty') == *"[bash32-3]"* ]] || {
    printf 'not linted:\n%s\n' "$output" >&2
    false
  }
}

# assert_silent: the last run printed nothing.
assert_silent() {
  [ "$status" -eq 0 ]
  [ -z "$output" ] || {
    printf 'not silent:\n%s\n' "$output" >&2
    false
  }
}

# is_linted: the last run printed an object holding the finding. A predicate,
# so a caller can name the case in a loop without an assertion function in a
# condition, where errexit is off.
is_linted() {
  [ "$status" -eq 0 ] && [[ $(jqo '.hookSpecificOutput.additionalContext // empty') == *"[bash32-3]"* ]]
}

# assert_shebang_linted <line1>...: each first line, on a file without an
# extension, draws the finding.
assert_shebang_linted() {
  local first
  for first in "$@"; do
    write_bad "$BATS_TEST_TMPDIR/noext" "$first"
    run run_hook "$BATS_TEST_TMPDIR/noext"
    if ! is_linted; then
      printf 'shebang not detected: %s\n%s\n' "$first" "$output" >&2
      false
    fi
  done
}

# run_calls <Tool=path>...: the hook on a payload with one call per argument.
run_calls() {
  local p
  p=$(payload_calls "$@")
  # shellcheck disable=SC2016 # the script is for the inner shell to expand
  run "$SH_BIN" -c 'printf "%s" "$1" | "$2" "$3"' _ "$p" "$SH_BIN" "$HOOK"
}

# --- FR6: shell files are detected by extension or shebang -------------------

@test "FR6: the .sh extension marks a shell file without a shebang" {
  write_bad "$BATS_TEST_TMPDIR/a.sh" '# no shebang'
  run run_hook "$BATS_TEST_TMPDIR/a.sh"
  assert_linted
}

@test "FR6: the .bash extension marks a shell file without a shebang" {
  write_bad "$BATS_TEST_TMPDIR/a.bash" '# no shebang'
  run run_hook "$BATS_TEST_TMPDIR/a.bash"
  assert_linted
}

@test "FR6: the .bats extension marks a shell file without a shebang" {
  write_bad "$BATS_TEST_TMPDIR/a.bats" '# no shebang'
  run run_hook "$BATS_TEST_TMPDIR/a.bats"
  assert_linted
}

@test "FR6: a file with neither a shell extension nor a shell shebang is not linted" {
  write_bad "$BATS_TEST_TMPDIR/noext" '#!/bin/bash'
  run run_hook "$BATS_TEST_TMPDIR/noext"
  assert_linted
  write_bad "$BATS_TEST_TMPDIR/a.txt" '# no shebang'
  run run_hook "$BATS_TEST_TMPDIR/a.txt"
  assert_silent
}

@test "FR6: an sh shebang, in each of its four forms, marks a shell file" {
  assert_shebang_linted '#!/bin/sh' '#!/usr/bin/env sh' '#!/bin/sh -eu' '#!/usr/bin/env sh -eu'
}

@test "FR6: a bash shebang, in each of its four forms, marks a shell file" {
  assert_shebang_linted '#!/bin/bash' '#!/usr/bin/env bash' '#!/bin/bash -eu' '#!/usr/bin/env bash -eu'
}

@test "FR6: a dash shebang, in each of its four forms, marks a shell file" {
  assert_shebang_linted '#!/bin/dash' '#!/usr/bin/env dash' '#!/bin/dash -eu' '#!/usr/bin/env dash -eu'
}

@test "FR6: a ksh shebang, in each of its four forms, marks a shell file" {
  assert_shebang_linted '#!/bin/ksh' '#!/usr/bin/env ksh' '#!/bin/ksh -eu' '#!/usr/bin/env ksh -eu'
}

@test "FR6: a bats shebang, in each of its four forms, marks a shell file" {
  assert_shebang_linted '#!/usr/bin/bats' '#!/usr/bin/env bats' '#!/usr/bin/bats -t' '#!/usr/bin/env bats -t'
}

@test "FR6: shebangs of other interpreters are not linted" {
  local first
  write_bad "$BATS_TEST_TMPDIR/noext" '#!/bin/bash'
  run run_hook "$BATS_TEST_TMPDIR/noext"
  assert_linted
  for first in '#!/bin/zsh' '#!/usr/bin/env zsh' '#!/bin/zsh -f' '#!/usr/bin/env zsh -f' \
    '#!/usr/bin/fish' '#!/usr/bin/env fish' '#!/usr/bin/env python3' '#!/bin/ash' \
    '#!/usr/bin/env ash -e' '#!/bin/bashful' '#!/bin/shell'; do
    write_bad "$BATS_TEST_TMPDIR/noext" "$first"
    run run_hook "$BATS_TEST_TMPDIR/noext"
    if [ -n "$output" ]; then
      printf 'linted: %s\n' "$first" >&2
      false
    fi
  done
}

# --- FR5: only Write and Edit calls name the files to lint --------------------

@test "FR5: an Edit call is linted" {
  write_bad "$BATS_TEST_TMPDIR/a.sh" '#!/bin/bash'
  run_calls "Edit=$BATS_TEST_TMPDIR/a.sh"
  assert_linted
}

@test "FR5: a batch of reads and commands over a shell file is silent" {
  write_bad "$BATS_TEST_TMPDIR/a.sh" '#!/bin/bash'
  run_calls "Read=$BATS_TEST_TMPDIR/a.sh" "Bash=$BATS_TEST_TMPDIR/a.sh" "Grep=$BATS_TEST_TMPDIR/a.sh"
  assert_silent
}

@test "FR5: in a mixed batch only the Write and Edit targets are linted" {
  write_bad "$BATS_TEST_TMPDIR/read.sh" '#!/bin/bash'
  write_bad "$BATS_TEST_TMPDIR/edit.sh" '#!/bin/bash'
  run_calls "Read=$BATS_TEST_TMPDIR/read.sh" "Edit=$BATS_TEST_TMPDIR/edit.sh"
  assert_linted
  [ "$(jqo .systemMessage)" = "shell lint: 1 findings" ]
  ctx=$(jqo '.hookSpecificOutput.additionalContext')
  [[ $ctx == *"$BATS_TEST_TMPDIR/edit.sh:3:"* ]] || false
  [[ $ctx != *"read.sh"* ]] || false
}

# --- FR8: a file is linted once per batch -------------------------------------

@test "FR8: a file written and edited in one batch is reported once" {
  write_bad "$BATS_TEST_TMPDIR/a.sh" '#!/bin/bash'
  run_calls "Write=$BATS_TEST_TMPDIR/a.sh" "Edit=$BATS_TEST_TMPDIR/a.sh" "Edit=$BATS_TEST_TMPDIR/a.sh"
  assert_linted
  [ "$(jqo .systemMessage)" = "shell lint: 1 findings" ]
  [ "$(jqo .hookSpecificOutput.additionalContext | grep -c 'bash32-3')" -eq 1 ]
}

@test "FR8: two files each edited twice are reported once each" {
  write_bad "$BATS_TEST_TMPDIR/a.sh" '#!/bin/bash'
  write_bad "$BATS_TEST_TMPDIR/b.sh" '#!/bin/bash'
  run_calls "Edit=$BATS_TEST_TMPDIR/a.sh" "Edit=$BATS_TEST_TMPDIR/b.sh" "Edit=$BATS_TEST_TMPDIR/a.sh" "Edit=$BATS_TEST_TMPDIR/b.sh"
  assert_linted
  [ "$(jqo .systemMessage)" = "shell lint: 2 findings" ]
}

# --- FR7: the notice alone ----------------------------------------------------

@test "FR7: a clean file without shellcheck yields the notice alone, once" {
  build_nosc_path
  fixture "$f" '#!/bin/sh' 'v=abc' "$PF '%s\\n' \"\$v\""

  run run_hook_nosc "$f"
  assert_one_object
  [[ $(jqo .systemMessage) == *"shellcheck is not installed"* ]] || false
  [ "$(jqo 'has("hookSpecificOutput")')" = false ]
  [[ $(jqo .systemMessage) != *"shell lint"* ]] || false

  run run_hook_nosc "$f"
  assert_silent
}

@test "FR7: a clean file with shellcheck is silent" {
  fixture "$f" '#!/bin/sh' 'v=abc' "$PF '%s\\n' \"\$v\""
  run shellcheck -x -f gcc "$f"
  [ -z "$output" ]

  run run_hook "$f"
  assert_silent
}
