# 2026-09-02 — Absorbed the remaining memory overlaps

A second pass over the same reconciliation, covering the three facts the first
one left duplicated rather than migrated. Each had a rule the skill already
stated and a residue it did not; the residue moved here, and the memory kept
only what no skill can own.

`references/portability.md` § stat gains the probe-once rule. The reflex form
`stat -c … 2>/dev/null || stat -f …` pays twice — on BSD it suppresses an
expected error per file, and on GNU it suppresses a *real* one (missing file,
permission denied) and falls through to a BSD branch that then fails for an
unrelated reason. Probe at startup and branch on the stored answer.

`references/environments.md` § Git hook environment leakage gains the leak's
signature symptom, `fatal: .git/index: index file open failed: Not a directory`,
with the note that a sandbox can raise the same string for an unrelated reason.
It also gains the quieter failure: in a linked parent worktree git exports an
absolute `GIT_DIR` *and* `GIT_COMMON_DIR`, so a hand-picked unset clearing only
the first lets `GIT_COMMON_DIR` redirect a submodule's refs and objects into the
parent's store — passing its tests in a plain main worktree and corrupting in
production. The `disable=SC2046` the documented unset needs is now stated where
the snippet is.

§ Submodule escape to the parent gains the consequence rather than just the
mechanism: `git -C sub rev-parse HEAD` returns the parent's HEAD, and staging
that as the gitlink writes a 160000 entry pointing at a commit the submodule does
not contain — a superproject that no longer clones.

`references/robustness.md` § Honest reporting gains the middle rung the bullet
was missing. Between "guard the condition" and "scope the redirect and say why"
sits capture-and-match: `err=$(cmd 2>&1)` then `case "$err"` on a discriminator
verified against the real tool, for a command whose several failure modes want
different handling — the branch you cannot take is the one whose evidence you
discarded. Alongside it, never replacing a tool's message with a guess: a
presumed cause appended to every failure is wrong exactly where the reader most
needs the truth.

The division stays the one the first pass set: the general rule ships in the
skill, and what survives in memory is what no artifact here can own — a standing
correction from the repository owner, and a hook idiom deliberately left out of
the skill because the skill's remedy (scope the unset to a subshell) is the one
that applies when you are not also staging.
