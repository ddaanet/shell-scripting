# 2026-10-30 — The hook's own `cd`: cause clause dropped

The medium review of the
[hook-cd-outcomes-dropped](2026-10-30-hook-cd-outcomes-dropped.md) change
found that the second caveat's anchor sentence named a cause, the hook's own
git re-resolving relative values it inherited, which a probe contradicted. In
a linked worktree whose hook inherited only absolute values, `cd sub` followed
by `git add gen` still recorded a top-level `gen` (git 2.47.3).

The clause is deleted and nothing replaces it. The sentence now says only
that after a `cd` the hook's own git can record a file at the wrong path or
fail, and prescribes the `git -C "$start"` anchor.
