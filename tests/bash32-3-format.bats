#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031 # bats runs each @test in a subshell by design
# Tests for how the bash32-3 rule reads the format of a printf into a variable:
# the %% escape, the flags between % and b, and a second call on the same line.
# Helpers and the fixture layout are in bash32-helpers.bash.

load bash32-helpers

# --- the %% escape is not a conversion ---------------------------------------

@test "bash32-3 not flagged: an escaped percent before a literal b" {
  assert_clean "$PF -v x '%%b' \"\$v\""
}

@test "bash32-3: an escaped percent before a real %b conversion is flagged" {
  lint_one "$PF -v x '%%%b' \"\$v\""
  assert_finding 3 3
}

# --- flags, width and precision between % and b ------------------------------

@test "bash32-3: a minus flag before b is flagged" {
  lint_one "$PF -v x '%-b' \"\$v\""
  assert_finding 3 3
}

@test "bash32-3: a plus flag before b is flagged" {
  lint_one "$PF -v x '%+b' \"\$v\""
  assert_finding 3 3
}

@test "bash32-3: a space flag before b is flagged" {
  lint_one "$PF -v x '% b' \"\$v\""
  assert_finding 3 3
}

@test "bash32-3: a hash flag before b is flagged" {
  lint_one "$PF -v x '%#b' \"\$v\""
  assert_finding 3 3
}

@test "bash32-3: a zero flag before b is flagged" {
  lint_one "$PF -v x '%0b' \"\$v\""
  assert_finding 3 3
}

@test "bash32-3: a width before b is flagged" {
  lint_one "$PF -v x '%5b' \"\$v\""
  assert_finding 3 3
}

@test "bash32-3: a width ending in 9 before b is flagged" {
  lint_one "$PF -v x '%9b' \"\$v\""
  assert_finding 3 3
}

@test "bash32-3: a precision before b is flagged" {
  lint_one "$PF -v x '%.3b' \"\$v\""
  assert_finding 3 3
}

@test "bash32-3 not flagged: a width before another conversion" {
  assert_clean "$PF -v x '%5s' \"\$v\""
}

# --- a second printf on the same line ----------------------------------------

@test "bash32-3: a guarded call then an unguarded one is flagged at the second" {
  first="[ -z \"\$u\" ] || $PF -v a '%b' \"\$u\"; "
  lint_one "$first$PF -v b '%b' \"\$v\""
  assert_finding 3 3
  assert_output_has ":3:$((${#first} + 1)):"
}

@test "bash32-3 not flagged: two guarded calls on one line" {
  assert_clean "[ -z \"\$u\" ] || $PF -v a '%b' \"\$u\"; [ -z \"\$v\" ] || $PF -v b '%b' \"\$v\""
}
