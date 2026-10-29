# Linting Bats Files

## ShellCheck lints `.bats` natively

Verified empirically with ShellCheck 0.10.0 on 2026-06-08. It parses
`@test "…" {`, `setup()`, `teardown()`, and `run` with no syntax errors,
descends *into* test bodies (caught a real SC2086 inside an `@test`), and
understands bats' scope model (no false `referenced-but-not-assigned` for vars
shared from `setup()` into a test or teardown, no false positive on `load`ed
`assert_output`). Auto-detected by the `.bats` extension (the 0.10.0 man page
lists `.bash`/`.bats`/`.dash`/`.ksh` plus shell directive/shebang); landed in
ShellCheck 0.7.0 (2019).

So `shellcheck scripts/*.sh tests/*.{sh,bats}` just works — the common
"adopting bats loses `shellcheck -x tests/*.sh` coverage" objection is wrong
for any modern toolchain. The `run`/`$status`/`$output`/`$lines` ergonomics are
bats-core itself; `bats-assert`/`bats-support` are optional sugar, not required.

## A comment whose first token is the linter's name is parsed as a directive

ShellCheck treats any comment beginning with `#` followed by its own name as a
directive, not prose. A descriptive comment like
`# shellcheck missing on a shell file = ...` triggers SC1072/SC1073
("Expected '=' after directive key") and fails the lint. Reword so the comment
does not open with that word (e.g. "Missing shellcheck ...") — it is otherwise
a self-inflicted lint error. Applies to `.bats` files too, since they are
linted.
