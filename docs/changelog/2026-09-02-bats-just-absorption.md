# 2026-09-02 — Absorbed the bats and just catalogs, and reconciled the git-output overlap

Two new `references/` nodes and one promotion, all sourced from facts that had
been living in a shared memory store rather than in the skill.

`references/bats.md` (≈9.8KB) collects eight independent mechanical facts about
bats tests and shellchecking them. Four are ways a suite looks green while
asserting nothing — a bare `! cmd` (SC2314), `run` of a missing function exiting
127, a multi-line `grep -qF` matching any one line, a helper's `${n:-default}`
swallowing the empty-argument case. One points the other way and is there to
refute the common misreading: `@test` bodies *do* run under errexit, so a failing
mid-body assertion aborts rather than being swallowed, and `|| return 1` guards
are diagnostics rather than a correctness fix. The skill's description already
named `.bats tests` as a trigger while carrying none of this content.

`references/just.md` (≈3.3KB) covers three `just` recipe traps: `{{ … }}` is
textual substitution performed before any shell sees the line, so shell quotes
around it protect nothing and data arguments need `quote()`; every body line of a
shebang recipe must share one leading indent; and a recipe body's `#` comments are
interpolated too, which fails loudly on an unresolvable name and **silently
substitutes** one already in scope. `just recipes` joins `Makefile recipes` in the
description's trigger list.

A node each rather than one combined file: the two fire on different moments, and
merging them would load 13KB for either trigger, against the progressive
disclosure the skill is built on.

`references/environments.md` § Parsing git output was a two-sentence stub saying
"use plumbing or `--porcelain`" while the memory carried the substance. Promoted:
which queries are silent on their normal-absence path (so a `2>/dev/null` there can
only hide a real fault), the `! [rejected] … (fetch first)` versus
`! [remote rejected] … (pre-receive hook declined)` discriminator, the fact that a
non-fast-forward reason does **not** distinguish behind from diverged (ancestry
does, via `merge-base --is-ancestor` in each direction), `git fetch -q` printing
nothing at all on rejection where `git push -q` still reports, `git config -z
--get-regexp` for whitespace-safe enumeration, and `--git-common-dir` being relative
in a main worktree with its CDPATH trap.

The division being converged on: the general rule ships in the skill, the error
string and the reproduction stay in memory where a tool result surfaces them.
Where the skill was thinner than the memory, the content moved here.

Also corrected, in the same section, a claim that had been wrong since it was
written. The "do not strip git's env for same-repo commands" bullet said a hook
that unsets `GIT_INDEX_FILE` and runs `git add` "stages into the real index
instead — the classic lint-staged bug class". Verified against git 2.47.3, no
commit mode produces that silent mis-staging: plain `git commit` passes
`.git/index` (so unsetting is a no-op), `git commit -a` passes `.git/index.lock`,
and `git commit -- <pathspec>` passes `.git/next-index-<pid>.lock`. In both lock
modes the `git add` dies on `fatal: Unable to create '.git/index.lock': File
exists`. The rule survives — the failure is loud rather than silent, and it still
breaks the commit — but the mechanism named was not the one that occurs.

No memory file was edited: that store is shared with other repositories, and
retiring a fact from it is a separate pass.
