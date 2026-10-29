# Vacuous Passes in Bats Tests

Independent mechanical facts sharing one trigger surface: writing or reviewing
bats tests. Probed on Bats 1.11.1 and 1.14.0 and ShellCheck 0.10.0 (2026);
version floors come from the bats-core docs.

Six of these are ways a bats test can look green while testing nothing: a bare
`!` asserts nothing, a `run` of a missing function exits 127 so a negative
assertion passes vacuously, `grep -qF` over a multi-line pattern asserts only
that some one line of it is present, a helper's `${n:-default}` substitutes
the default for the empty argument the test meant to pass, `grep -c` over raw
`jq` output counts encoded lines, and `jq -r .key` prints `null` for an absent
key.

The errexit fact points the **opposite** way and exists to refute the
"masked failures" reading — a failing mid-body assertion *aborts* the test
rather than being silently swallowed. Do not file it alongside the other six;
it lives in
[`run-semantics.md`](run-semantics.md#test-bodies-run-under-errexit).

The general rule underneath the vacuous-pass cluster: **a green test is evidence
only if you have seen it fail for the right reason.** A predicate covered only
by cases that expect failure has no red phase at all, and stays green if the
function under test is deleted or renamed. Delete the implementation, or the
guard, and confirm the test goes red before trusting it.

## A non-final bare `! cmd` in a `@test` does not fail the test

A top-level `! command` line inside a `@test` body that is not the last line
does **not** make the test fail. `@test` bodies run under errexit, so a
failing mid-body command normally aborts the test, but bash exempts a
`!`-negated command from errexit (and the ERR trap): it still runs, side
effects included, and `$?` holds the inverted status, but nothing aborts on
it. As the last line its status propagates as usual (per the bats-core gotchas
page and 1.14.0). So a non-final `! grep -qF 'x' file` reads like "assert x is
absent" but asserts nothing. ShellCheck flags it **SC2314** (error when
non-final, style when last, 0.10.0).

Use `run ! command` (bats >= 1.5.0; declare `bats_require_minimum_version
1.5.0` on bats >= 1.7.0), which runs the command and asserts it failed — the
real negative assertion (for bats before 1.7.0, see the `BW02` section of
[`run-semantics.md`](run-semantics.md#run-flags-need-bats_require_minimum_version-bw02)).

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

## Asserting on `jq` output: two silent passes

`grep -c` counts matching *lines*, and `jq` emits a multi-line `systemMessage`
as one JSON string (newlines as `\n`), so a block doubled inside it still
counts 1. Decode before counting: `jq -r .systemMessage | grep -c …`
(verified: raw 1, decoded 2). And `jq -r .key` prints the string `null` for an
absent key, which a non-empty check accepts: use `jq -r '.key // empty'` (note
it also empties `false`), or assert presence with `jq -e 'has("key")'`.
