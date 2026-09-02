# Bats Test Suites: Vacuous Passes and Linting

Independent mechanical facts sharing one trigger surface: writing or reviewing
bats tests, and shellchecking them. Verified against Bats 1.11.1 and ShellCheck
0.10.0 (2026).

Four of these are ways a bats test can look green while testing nothing: a bare
`!` asserts nothing, a `run` of a missing function exits 127 so a negative
assertion passes vacuously, `grep -qF` over a multi-line pattern asserts only
that some one line of it is present, and a helper's `${n:-default}` substitutes
the default for the empty argument the test meant to pass.

The errexit fact points the **opposite** way and exists to refute the
"masked failures" reading — a failing mid-body assertion *aborts* the test
rather than being silently swallowed. Do not file it alongside the other four.

The general rule underneath the vacuous-pass cluster: **a green test is evidence
only if you have seen it fail for the right reason.** A predicate covered only
by cases that expect failure has no red phase at all, and stays green if the
function under test is deleted or renamed. Delete the implementation, or the
guard, and confirm the test goes red before trusting it.

## A bare `! cmd` in a `@test` does not fail the test

A top-level `! command` line inside a `@test` body does **not** make the test
fail. Bash's `!` inverts the exit status, but bats only inspects the last
command's status, and under `set -e`-like semantics a `!`-negated line is
treated as deliberately-ignored: a non-final one is skipped entirely, and even
as the last line it silently passes on bats < 1.5. So `! grep -qF 'x' file`
reads like "assert x is absent" but asserts nothing. ShellCheck flags it
**SC2314** (error when non-final, note when last).

Use `run ! command` (bats >= 1.5.0, after `bats_require_minimum_version 1.5.0`),
which runs the command and asserts it failed — the real negative assertion.

Observed 2026-07-21: a plan's test code carried four `! grep -qF` negative
assertions; two would have passed unconditionally, including the one meant to
prove the behavior the change was about. The linter caught it before the tests
ran, not the author's review.

## `run missing_function` exits 127, so negative assertions pass vacuously

```bash
run some_predicate <<< "input"
[ "$status" -ne 0 ]     # expecting "false"
```

passes when `some_predicate` **does not exist**: `run` captures the 127
"command not found" status, which satisfies `-ne 0`. Observed 2026-07-20 while
TDD-ing a predicate — two of three tests went green during the RED phase,
before a line of implementation was written.

**Why it matters:** it defeats the point of watching the test fail. A predicate
covered *only* by false-cases has no RED phase at all, and would stay green if
the function were later deleted or renamed.

**How to apply:** every predicate needs at least one **positive** assertion
(`[ "$status" -eq 0 ]`) — that is the one that pins existence and behavior.
Treat negative cases as refinements around it, not as coverage on their own.
The same trap applies to any `run`-based check keyed on non-zero exit,
including `run !` forms.

## `run` is a subshell, so a function's out-params never reach the test

`run` captures status and output by running the command in a **subshell**. Any
variable the callee sets for its caller — the shell idiom for returning
structured data, since a function's own exit status is one integer — is gone
by the time the assertions run:

```bash
run parse_the_file "$f"        # sets PARSE_ERR for its caller
[ "$status" -ne 0 ]            # fine
[[ "$PARSE_ERR" == *"..."* ]]  # empty: the assignment died with the subshell
```

The symptom is specific and easy to misread: the status assertion passes and
only the message assertion fails, so it looks like the *message* is wrong
rather than unreachable. Two ways out, and a suite usually wants both — have
a test helper print what the callee set and return its status, so `run helper`
gives `$output` for the message; and call the function **bare** (not under
`run`) in the tests that need the variables it populates, where bats' errexit
makes a non-zero return the failure.

Observed 2026-07-30 on a validator reporting through an out-param variable:
eight shape-matrix tests asserted on `$output` and all eight failed with an
empty one.

## A helper's `${n:-default}` erases the empty-argument case

A test helper that defaults its optional parameters with `${2:-$DEFAULT}`
cannot be passed an empty string: the colon form substitutes the default for
unset **and** empty alike, so `run_thing "$dir" ""` — written to exercise the
missing-identifier branch — silently runs the populated case instead. The test
then asserts the guard's effect against input that never reached it, and passes
whether the guard exists or not.

Use `${2-$DEFAULT}` (no colon) in any helper whose parameter has a meaningful
empty value; keep the colon form only where empty and unset genuinely mean the
same thing. The same asymmetry bites `${VAR:-}` fallbacks in a script under
test whenever the empty value is the case being covered.

Review does not catch this one: deleting the guard leaves the test green. It is
the variant where the vacuity lives in the *fixture* rather than the assertion.

## `grep -qF "$multiline"` matches any ONE line of the pattern

`grep` is line-oriented: a multi-line `-F` pattern is a *set* of fixed
strings, and matching any one of them satisfies it. So
`echo "$output" | grep -qF "$EXPECTED"` reads as "the whole thing is present"
and asserts only that some single line of it is — it stays green when the
text is reordered, split across the output, or has most of it dropped.
`grep -q` (BRE) is line-oriented the same way and additionally re-reads the
pattern as a regex; `-z` makes grep NUL-delimited rather than multi-line
aware, so it is not the fix either.

Bash substring matching is the assertion that means it:
`[[ "$output" == *"$EXPECTED"* ]]` — contiguous and verbatim, newlines
included. Frame it to assert structure:
`[[ "$output" == *$'\n\n'"$EXPECTED"$'\n\n'* ]]` says the text stands as its
own blank-line-delimited block rather than being spliced into a sentence.

The fixture is half of it: a single-line stand-in for a value that is
multi-line in production makes the two renderings indistinguishable, so
there is no assertion to write. Shape the fixture after the real value.

## `@test` bodies run under errexit

Verified on Bats 1.11.1 (2026-06-08). A failing mid-body `[ … ]`, `[[ … ]]`,
failing pipeline (`echo x | grep -q NOMATCH`), or `jq -e '…' >/dev/null`
evaluating false each **aborts the test** — they are NOT "masked/swallowed".
`>/dev/null` redirects stdout only, never the exit status.

So guarding non-final assertions with `|| return 1` / `|| fail` is a
style/diagnostics choice (bats already prints the failing line and number),
**not** a correctness fix. The genuine errexit exemptions are the usual set:
commands in `if`/`while`/`until` conditions, the left side of `&&`/`||`,
`! cmd`, and non-final elements of a pipeline (without pipefail) — only
assertions hitting those are truly swallowed, and a faithful conversion rarely
produces them.

Context: a code-quality review flagged every non-final assertion in a converted
suite as a correctness HIGH ("masked failures"); a 5-line bats probe disproved
it. Probe before accepting the claim.

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

## A function invoked through `run` does not see the test body's variables

A helper defined inside a `@test` body and invoked as `run helper` fails with
`bats.NN.src: line N: <var>: unbound variable` when its body reads a variable
the test set — under bats 1.11.1, with or without `export`. The failure is
whatever the test's `set -u` does to it, and the surrounding assertion fails on
a missing artifact rather than the real cause, which reads as "the override
never ran".

Recompute inside the helper instead of capturing, and use `$BATS_TEST_TMPDIR`
for a sentinel file — bats sets it in the environment the helper does see:

```bash
helper() {
  probe() { [ -f "$(state_file memory)" ] && echo present > "$BATS_TEST_TMPDIR/seen"; }
  function_under_test
}
run --separate-stderr helper
[ "$(cat "$BATS_TEST_TMPDIR/seen")" = present ]
```

Shadowing a sourced function this way to drive a failure path *does* work — the
override is visible where the test's variables are not.
