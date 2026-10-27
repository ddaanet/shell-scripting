# `run` Semantics and Errexit in Bats Tests

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

## `run` flags need `bats_require_minimum_version` (BW02)

Any flag on `run` (`!`, `-N`, `--separate-stderr`, `--keep-empty-lines`) needs
`bats_require_minimum_version 1.5.0`; without it bats prints warning `BW02` and
carries on. Treat `BW02` in the warnings block as a to-fix, not noise: which
behaviours the fallback keeps is a bats-version matter, so a suite can be green
on one machine and red on another with no change to the code under test. A
declaration in a `load`ed helper counts (verified, bats 1.14.0). A plain `run`
after `run --separate-stderr` unsets `$stderr` (1.14.0), so read `$stderr`
before the next `run`.

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
