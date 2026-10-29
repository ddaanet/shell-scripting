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

Observed on bats 1.11.1: a helper defined inside a `@test` body and invoked as
`run helper` fails with `bats.NN.src: line N: <var>: unbound variable` when its
body reads a variable the test set, with or without `export`. The failure is
whatever the test's `set -u` does to it, and the surrounding assertion fails on
a missing artifact rather than the real cause, which reads as "the override
never ran".

It does not reproduce on bats 1.14.0: the same shape (helper defined in the
`@test` body, `set -u`, plain `run helper` and `run --separate-stderr helper`,
both probed) sees both local and exported test variables there. The rule is
version-dependent, so a suite that runs on more than one bats should not rely on
the helper seeing them.

Recompute inside the helper instead of capturing, and use `$BATS_TEST_TMPDIR`
for a sentinel file — bats sets it in the environment the helper does see:

```bash
helper() {
  probe() { [ -f "$(state_file memory)" ] && echo present > "$BATS_TEST_TMPDIR/seen"; }
  function_under_test
}
run helper
[ "$(cat "$BATS_TEST_TMPDIR/seen")" = present ]
```

Shadowing a sourced function this way to drive a failure path *does* work, on
1.11.1 and on 1.14.0 (probed); only the visibility of the test's variables
differs.

## `run` flags need `bats_require_minimum_version` (BW02)

Any flag on `run` (`!`, `-N`, `--separate-stderr`, `--keep-empty-lines`) needs
`bats_require_minimum_version 1.5.0`; without it bats prints warning `BW02` and
carries on. The declaration function itself exists only from bats 1.7.0: on
1.5–1.6 it fails as unavailable (per the bats(7) manual), so a suite that
spans those versions and newer can load bats-backports
(https://github.com/bats-core/bats-backports), which the manual says makes the
declaration usable; that one running only on 1.5–1.6 may skip the declaration
is not verified (unprobed, not from the manual).
Treat `BW02` in the warnings block as a to-fix, not noise: which behaviours the
fallback keeps is a bats-version matter, so a suite can be green on one machine
and red on another with no change to the code under test. A declaration in a
`load`ed helper counts (verified, bats 1.14.0). A plain `run` after `run
--separate-stderr` unsets `$stderr` (1.14.0), so read `$stderr` before the next
`run`.

## `@test` bodies run under errexit

Probed on Bats 1.11.1 (2026-06-08) and, for `(( ))`, on 1.14.0 with bash 5.2;
the bash 4.1 boundary below is from the bats-core docs, not a probe. On bash
4.1 or newer a failing mid-body `[ … ]`, `[[ … ]]`, `(( … ))`, failing
pipeline (`echo x | grep -q NOMATCH`), or `jq -e '…' >/dev/null` evaluating
false each **aborts the test** — they are NOT "masked/swallowed".
`>/dev/null` redirects stdout only, never the exit status.

So on bash >= 4.1, guarding non-final assertions with `|| return 1` / `|| fail`
is a style/diagnostics choice (bats already prints the failing line and number),
**not** a correctness fix. The exception is older bash: the `set -e` handling of
`[[ ]]` and `(( ))` changed in bash 4.1, and on 3.2 (macOS `/bin/bash`) a
failing one does not abort the test unless it is the last command. bats-core's
own gotchas page prescribes appending `|| false`, which works everywhere; `[ ]`
is unaffected. The genuine errexit exemptions are the usual set: commands in
`if`/`while`/`until` conditions, the left side of `&&`/`||`, `! cmd`, a command
substitution used as an argument (`[ -z "$(false)" ]` passes on bats 1.14.0: the
substitution's status is discarded, see
[`robustness.md`](../../shell-gotchas/references/robustness.md)), and non-final
elements of a pipeline (without pipefail) — only assertions hitting those are
truly swallowed, and a faithful conversion rarely produces them.

Context: a code-quality review flagged every non-final assertion in a converted
suite as a correctness HIGH ("masked failures"); a 5-line bats probe disproved
it. Probe before accepting the claim.
