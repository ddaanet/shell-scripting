# 2026-06-11 — Skill rewritten from primary-source research (v0.2.0)

Five parallel research agents fact-checked every claim in the skill against primary
sources: POSIX.1-2024, GNU and BSD man pages, bash NEWS, Greg's Wiki BashPitfalls,
`githooks(5)` with git 2.47 repros, shellcheck 0.10.0 empirical runs, and the Claude
Code docs. This established the standing rule that content is cited or empirically
verified, never memory-derived.

Corrections the pass produced:

- The skill's own suppression syntax was a parse error — `# shellcheck disable=… reason`
  must be `… # reason`.
- Three "shellcheck cannot catch" rows were false: SC2155, SC2030/31, SC2070; `cd` is
  half-caught by SC2164.
- macOS ≥ 12.3 has `readlink -f` and ships `realpath`; macOS `xargs` accepts `-r`.
- POSIX 2024 standardized `-print0`, `xargs -r/-0`, `head -c`, `pipefail`, `sed -E`,
  `timeout`, and `realpath`, while removing `test -a/-o`; `local` was rejected
  (Austin #767).
- The `head --lines` example was wrong on current macOS.
- Git hooks export layout-dependent environment: `GIT_WORK_TREE` was never observed,
  and the silent cross-repo corruption fires in worktrees, submodules and bare repos
  rather than plain clones. The documented fix is a subshell plus
  `unset $(git rev-parse --local-env-vars)` — never for same-repo commands, which
  need the partial-commit temp index.

New blind spots added: `timeout` absent on macOS, `inherit_errexit`, pipefail +
SIGPIPE, bare `wait`, arithmetic injection, traps reset in subshells,
`LC_ALL=C read -d ''` (bash 5.0–5.3, BP#65), worktree detection via
`--path-format=absolute`, submodule hooks under `.git/modules/<name>/hooks`, hook
cwd/stdin/`GIT_PREFIX`/`core.hooksPath` silent-skip, BWK awk, bsdtar, checksum
names, `find -regex` flavors, `getopt(1)`, and macOS `/bin/sh`-is-bash.

Reference files now carry inline citations. Citations date-stamp the facts:
shellcheck and POSIX evolve, and a future re-verification pass has concrete sources
to diff against.
