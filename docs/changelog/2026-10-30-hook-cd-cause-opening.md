# 2026-10-30 — The hook's own `cd`: opening cause clause dropped

The medium review of the
[hook-cd-cause-dropped](2026-10-30-hook-cd-cause-dropped.md) change found that
the second caveat's opening sentence still justified the anchor with the cause
that change deleted from the anchor sentence: a `cd` re-resolving every
relative value the hook inherited. The same probe contradicts it. In a linked
worktree whose hook inherited only absolute values, `cd sub` followed by
`git add gen` still recorded a top-level `gen` (git 2.47.3).

The clause is deleted and nothing replaces it. The sentence now says only that
the hook keeps git's env for its add and anchors it to the starting directory.
