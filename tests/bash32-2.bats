#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031 # bats runs each @test in a subshell by design
# Tests for the bash32-2 rule of hooks/scripts/bash32-lint.sh. Helpers and the
# fixture layout are in bash32-helpers.bash.

load bash32-helpers

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

@test "bash32-2: LC_NUMERIC prefix is flagged" {
  lint_one "$LCN=C $PF '%.2f' 1.5"
  assert_finding 3 2
}

@test "bash32-2: LC_NUMERIC prefix inside a substitution is flagged" {
  lint_one "x=\$($LCN=C $PF '%.2f' 1.5)"
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

@test "bash32-2: prefix after a quoted-backtick assignment is flagged" {
  lint_one "FOO=\"\`date\`\" $LCA=C $PF x"
  assert_finding 3 2
}

@test "bash32-2: prefix after a backtick assignment with a suffix is flagged" {
  lint_one "FOO=\`date\`bar $LCA=C $PF x"
  assert_finding 3 2
}

@test "bash32-2: prefix after a backtick assignment with text on both sides is flagged" {
  lint_one "FOO=a\`date\`/b $LCA=C $PF x"
  assert_finding 3 2
}

@test "bash32-2: prefix before a quoted-backtick assignment is flagged" {
  lint_one "$LCA=C FOO=\"\`date\`\" $PF x"
  assert_finding 3 2
}

@test "bash32-2: locale assignment with a quoted-backtick value is flagged" {
  lint_one "$LCA=\"\`pick\`\" $PF %q x"
  assert_finding 3 2
}

@test "bash32-2: prefix after two backtick assignments is flagged" {
  lint_one "FOO=\`date\` BAR=\"\`date\`\" $LCA=C $PF %q x"
  assert_finding 3 2
}

@test "bash32-2: prefix after a control operator following a closed backtick is flagged" {
  lint_one "v=\"\`date\`\"; $LCA=C $PF %q x"
  assert_finding 3 2
}

@test "bash32-2: prefix after a quoted-substitution assignment is flagged" {
  lint_one "FOO=\"\$(date)\" $LCA=C $PF x"
  assert_finding 3 2
}

@test "bash32-2: prefix after a substitution assignment with a prefix is flagged" {
  lint_one "FOO=x\$(date) $LCA=C $PF x"
  assert_finding 3 2
}

@test "bash32-2: prefix after a substitution assignment is flagged" {
  lint_one "FOO=\$(date) $LCA=C $PF x"
  assert_finding 3 2
}

@test "bash32-2: prefix before a quoted-substitution assignment is flagged" {
  lint_one "$LCA=C FOO=\"\$(date)\" $PF x"
  assert_finding 3 2
}

@test "bash32-2: prefix before a substitution assignment with text on both sides is flagged" {
  lint_one "$LCA=C FOO=x\$(date)y $PF x"
  assert_finding 3 2
}

@test "bash32-2: locale assignment with a quoted-substitution value is flagged" {
  lint_one "$LCA=\"\$(pick)\" $PF %q x"
  assert_finding 3 2
}

@test "bash32-2: prefix before a one-element array literal is flagged" {
  lint_one "$LCA=C a=(x) $PF %q \"\$x\""
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

@test "bash32-2 not flagged: a control operator after a backtick value ends the prefix run" {
  assert_clean "$LCA=C FOO=\"\`date\`\"; $PF %q x"
}

@test "bash32-2 not flagged: a control operator after a substitution value ends the prefix run" {
  assert_clean "$LCA=C FOO=\$(date); $PF %q x"
}

@test "bash32-2 not flagged: assignments after env are arguments of env" {
  assert_clean "env FOO=\"\$(date)\" $LCA=C $PF %q x"
}

