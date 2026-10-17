## Brief: `[ -z "$(cmd)" ]` converts a failure into "empty"

2026-09-17

Proposed increment to `skills/shell-gotchas/references/robustness.md`,
§"Exit status and `set -e`". Arrived from the `handoff` plugin repo, where the
spelling appeared in a hook guarding a `git add`.

### The gap

The existing entry reads:

> **Command substitution does not inherit `set -e` (bash):** in `var=$(f)`, `f`
> runs with errexit *off* unless `shopt -s inherit_errexit` (bash >= 4.4) or
> POSIX mode. A failing pipeline inside `$(...)` sails through.

That is accurate about failures *inside* the substitution, and it predicts only
that a failure is **missed**. Two things it does not say:

1. A bare `v=$(false)` **does** abort under `set -e`. The assignment's own exit
   status is the substitution's, and errexit sees the assignment. So the entry's
   own example is the case that is not silent.
2. Wrapping the substitution in a test **is** silent, and worse than silent: the
   failure becomes a meaningful-looking answer. `[` never sees an exit status —
   it sees the string, which for a failed command is empty, so `-z` reads the
   failure as "empty" and `-n` as "absent". The script then takes the
   empty-case branch confidently.

`shopt -s inherit_errexit` does not close this one: the status is discarded by
`[`, which is outside the substitution entirely.

### Evidence

Probed on GNU bash 5.2.37:

```bash
#!/bin/bash
set -euo pipefail
[ -z "$(false)" ] && echo "A: reached"      # prints
[ -n "$(false)" ] || echo "B: reached"      # prints
[ -z "$(false)" ]                           # bare statement: exits 0
echo "C: still running"                     # prints; script rc=0
```

All four lines run and the script exits 0. Replacing the first line with
`v=$(false)` aborts the script at that line with rc 1.

### Why it matters in practice

The spelling reads as a natural guard and appears wherever a command's *output*
is the question:

- `[ -z "$(git ls-files -- "$p")" ]` — a git failure reads as "path not tracked"
- `[ -z "$(git config --get X)" ]` — a broken invocation reads as "unset"
- `[ -n "$(command -v tool)" ]` — a PATH failure reads as "not installed"

Each takes the wrong branch with no diagnostic. The remedy is to separate the
two questions:

```bash
if ! out=$(git ls-files -- "$p"); then : handle failure; fi
[ -n "$out" ] || : handle genuinely-empty
```

### Suggested shape

A sibling bullet under the same heading, or two sentences appended to the
existing one — the entry is already in the right place, it just stops one step
short. The SKILL.md table row (`v=$(cmd)` under `set -e`) may also want the
`[ ... ]` spelling beside it, since the table is what a reader scans first.

### Additional context

Not a shellcheck finding: SC2311 flags only function calls in a substitution,
and nothing flags a substitution inside a test.

Distinct from the Claude Code Bash-tool case (errexit inert for the whole
command because of how the tool invokes bash) — here errexit works correctly
and simply has nothing to see.
