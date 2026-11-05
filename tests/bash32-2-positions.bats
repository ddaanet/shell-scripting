#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031,SC2154 # bats runs each @test in a subshell by design; setup assigns f
# Tests for where the bash32-2 rule sees a command position (the keywords that
# open one) and for the lint's handling of an operand it cannot read. Helpers
# and the fixture layout are in bash32-helpers.bash.

load bash32-helpers

# --- keywords that open a command position -----------------------------------

@test "bash32-2: prefix after while is flagged" {
  lint_one "while $LCA=C read -r l; do :; done"
  assert_finding 3 2
}

@test "bash32-2: prefix after until is flagged" {
  lint_one "until $LCA=C read -r l; do :; done"
  assert_finding 3 2
}

@test "bash32-2: prefix after a negation is flagged" {
  lint_one "! $LCA=C read -r l"
  assert_finding 3 2
}

@test "bash32-2: prefix after an opening brace is flagged" {
  lint_one "{ $LCA=C read -r l; }"
  assert_finding 3 2
}

@test "bash32-2: prefix after do is flagged" {
  lint_one "for i in 1; do $LCA=C read -r l; done"
  assert_finding 3 2
}

@test "bash32-2: prefix after else is flagged" {
  lint_one "if false; then :; else $LCA=C read -r l; fi"
  assert_finding 3 2
}

@test "bash32-2: prefix after elif is flagged" {
  lint_one "if false; then :; elif $LCA=C read -r l; then :; fi"
  assert_finding 3 2
}

@test "bash32-2: prefix after if is flagged" {
  lint_one "if $LCA=C read -r l; then :; fi"
  assert_finding 3 2
}

# --- an operand that cannot be read ------------------------------------------

@test "lint: an absent file is skipped silently and the next file is still linted" {
  fixture "$f" '#!/bin/sh' ':' "$PF -v x '%b' \"\$v\""
  run sh "$LINT" "$BATS_TEST_TMPDIR/absent.sh" "$f"
  assert_finding 3 3
}

@test "lint: an absent file alone gives exit 0 and empty output" {
  run sh "$LINT" "$BATS_TEST_TMPDIR/absent.sh"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
