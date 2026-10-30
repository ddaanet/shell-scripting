---
name: bats-gotchas
description: "Catalogs bats pitfalls: tests that pass while asserting nothing, and lint traps. This skill should be used when writing, editing, reviewing, or debugging `.bats` files or bats tests — `@test` bodies, `run` assertions, `$status`/`$output` checks, or shared test helpers."
---

# Bats Gotchas

Bats traps that make a test look green while it asserts nothing, plus the `run`,
errexit and lint facts that decide whether an assertion is reached. Probed on
Bats 1.11.1 and 1.14.0 and ShellCheck 0.10.0 (2026); version floors come from
the bats-core docs. A green test is evidence only if you have seen it fail for
the right reason: delete the implementation or the guard, and confirm the test
goes red.

## What a Bats Suite Gets Wrong Silently

| Trap | Symptom | Fix |
|---|---|---|
| A bare `! cmd` line in a `@test` | Asserts nothing: the command runs; when non-final, nothing aborts on it (`$?` still holds the inverted status; ShellCheck SC2314; a final `! cmd` propagates its status) | `run ! cmd` (needs bats >= 1.5.0; on bats >= 1.7.0 declare `bats_require_minimum_version 1.5.0` first; bats < 1.7.0: see [`run-semantics.md`](references/run-semantics.md)) |
| A flag on `run` (`!`, `-N`, `--separate-stderr`) without the version declaration | Warning `BW02` (flags still work) | On bats >= 1.7.0 declare `bats_require_minimum_version 1.5.0` (a `load`ed helper counts; bats < 1.7.0: see [`run-semantics.md`](references/run-semantics.md)); read `$stderr` before the next `run` (a plain `run` unsets it) |
| `run missing_function` then `[ "$status" -ne 0 ]` | Exit 127 satisfies the negative assertion, so the test is green before any implementation exists | Give every predicate at least one positive `[ "$status" -eq 0 ]` assertion; negative cases only refine it |
| Helper default `${2:-$DEFAULT}` | An empty argument silently runs the populated case; the test stays green with the guard deleted | `${2-$DEFAULT}` (no colon) wherever the empty value is meaningful |
| `grep -qF "$multiline"` | Matches if any ONE line of the pattern is present; green when reordered, split or mostly dropped | `[[ "$output" == *"$EXPECTED"* ]]`; shape the fixture after the real multi-line value |
| `grep -c` over raw `jq` output; `jq -r .key` on an absent key | A multi-line string is one JSON line, so a doubled block counts 1; the string `null` passes a non-empty check | Decode first: `jq -r .systemMessage \| grep -c …`; `jq -r '.key // empty'` (also empties `false`; use `has` for booleans) or `jq -e 'has("key")'` |
| Reading a function's out-param after `run f` | `run` is a subshell: the status assertion passes, only the message assertion fails, on an empty variable | A helper prints what the callee set and returns its status (assert on `$output`); call the function bare only on success paths, where the variables are needed (a non-zero return aborts the test) |
| A helper defined in a `@test` body, called as `run helper`, reads the test's variables | `<var>: unbound variable` on bats 1.11.1 (not reproduced on 1.14.0); the surrounding assertion fails on a missing artifact | Recompute inside the helper; use `$BATS_TEST_TMPDIR` for a sentinel file; shadowing a sourced function this way works |
| Guarding mid-body assertions with `\|\| return 1` against "masked failures" | Not a defect on bash >= 4.1: a failing `[ … ]`, `[[ … ]]`, `(( … ))`, pipeline or `jq -e` already aborts the test | Skip the guard (style only); on bash < 4.1 (macOS `/bin/bash` 3.2) a failing mid-body `[[ … ]]` or `(( … ))` does not abort, so append `\|\| false` there (`[ … ]` is unaffected); only `if`/`while`/`until` conditions, the left of `&&`/`\|\|`, `! cmd`, a command substitution used as an argument (`[ -z "$(false)" ]`) and non-final pipeline stages swallow a failure; probe before accepting the claim |
| The inherited stdin of a test | under Claude Code's Bash tool fd 0 is `/dev/null` or a socket, not what production gives the subject; a read hangs or sees EOF | Give the subject its production stdin explicitly (`printf '%s' "$json" \|`, `</dev/null`); see [`environments.md`](../shell-gotchas/references/environments.md), Claude Code specifics |
| A comment opening with `# shellcheck` in a `.bats` file | ShellCheck parses it as a directive: SC1072/SC1073, lint fails | Reword so the comment does not open with the tool name; `.bats` is linted natively, so keep it in the lint command |
| A GNU-only spelling (`stat -c`) in a `@test` body or helper | A PATH stub never shadows the test process's own commands, so no Linux run can fail on it | Add a static per-file `grep -rl … --include='*.bats'` check that a BSD spelling exists; see "Locking fixes in" in [`portability.md`](../shell-gotchas/references/portability.md) |

## References

Explanations, examples and observed incidents behind the rows:

- [`references/vacuous-passes.md`](references/vacuous-passes.md) — `! cmd`,
  `run` of a missing function, a helper's `${n:-default}`, multi-line
  `grep -qF`, `jq` output.
- [`references/run-semantics.md`](references/run-semantics.md) — what crosses
  the `run` subshell (out-params, test variables), `BW02` and `$stderr`, errexit
  in a `@test`.
- [`references/linting.md`](references/linting.md) — ShellCheck on `.bats` files
  and the directive-comment trap.
