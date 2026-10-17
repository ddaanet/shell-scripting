## Brief: errexit is live inside the body of an AND-OR list's final element

2026-09-17

`skills/shell-gotchas/references/robustness.md:30` currently reads:

> - Neither half is visible under plain `set -e`: the substitution sits in a
>   condition (`||`), where errexit is already suspended (see above) — both
>   need `pipefail` to even surface.

That sentence is correct about the case it describes — a command substitution
sitting in the *condition* position. The problem is the unqualified clause
"where errexit is already suspended": a reader carries it across to the
`{ … }` **body** of the final element, which is the opposite of how bash
behaves.

### The fact

POSIX suppresses errexit for the commands in an AND-OR list **other than the
last**. The final element is not suppressed, and neither are the commands
inside it when it is a brace group. So in `cmd || { a; b; c; }`, a failure in
`a` aborts the script immediately — `b` and `c` never run.

Measured on bash 5.2:

```sh
set -euo pipefail
false || { echo before; jq . /nonexistent-file; echo NEVER-REACHED; }
echo NEVER-REACHED-EITHER
```

prints `before`, then jq's error, then exits with jq's own status (2). Neither
`NEVER-REACHED` line prints.

### Why it matters enough to write down

This is the shape of a refusal handler:

```sh
some_check || {
    detail=$(expensive_lookup)          # unguarded
    printf 'hint: %s\n' "$detail" >&2
    die "refusing: <reason>"
}
```

When `expensive_lookup` fails, the script dies with *that command's* status and
neither the hint nor the `die` message ever prints. A decided, well-worded
refusal becomes a bare crash — and the failure is invisible to review by
reading, because the `die` is right there on the page.

It bit `claude-plugin-dev`'s `toolkit/release.sh` twice in one work cycle:

- a `jq` capture reading the marketplace entry inside a
  `check-version.sh || { … }` handler. `check-version.sh` exits non-zero on a
  malformed `marketplace.json`, not only on version drift, so the `jq` failed
  the same way and the run aborted with **rc=5 and no `error:` line at all**,
  where the previous revision gave rc=1 with a hint and an error.
- a `release_tags` capture inside a `git rev-parse … || { … }` handler.
  Measured two ways: `git tag --list` erroring gives rc=128 with no `error:`
  line; a status-2 `grep` inside the filter gives rc=1 with no message.

Three separate opus-level reviews asserted errexit was suspended there before
a probe settled it, which is the evidence that the current wording does not
inoculate a careful reader.

### Suggested change

Qualify the clause at `robustness.md:30`, and add an entry to the same file's
`## Exit status and `set -e`` list — something like:

> - **`set -e` is NOT suspended inside the body of an AND-OR list's final
>   element:** errexit is suppressed for the elements *before* the last, not
>   within the last one. In `cmd || { a; b; die …; }`, a failing `a` aborts the
>   script with `a`'s status and neither `b` nor the `die` message runs — a
>   decided refusal turns into a bare crash. Guard every capture inside a
>   refusal handler. (verified, bash 5.2)

The `SKILL.md` quick-reference table is probably also worth a row, since the
handler shape is common enough to meet without reading the reference.

### Related, possibly worth a line of its own

`exit` inside `$( )` terminates only the subshell, so a `die` helper invoked as
`x=$(f)` cannot stop the run — the caller continues with an empty capture. This
silently neutralises mutation probes: a reviewer's deliberately-broken variant
looked green because its `die` never fired. `robustness.md` covers traps
resetting in subshells (`:24`) and command substitution not inheriting `set -e`
(`:12`), but not this consequence.

### Not in scope

No claim that anything else on the page is wrong. `:12`, `:19`, `:20`, `:21`,
`:24` and the `x=$(pipe || fallback)` entry at `:28-29` all held up against the
same work and were useful.

### Provenance

Found while executing `plans/2026-09-15-first-release-version/runbook.md` in
`/Users/david/code/claude-plugin-dev`. The fix commits are `2e644c4` (the `jq`
capture) and `192b9c6` (the `release_tags` capture); each carries a code-review
report under that plan's `reports/` with the full probe transcripts.
