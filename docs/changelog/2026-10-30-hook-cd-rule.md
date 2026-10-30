# 2026-10-30 — The hook's own `cd`: a rule, not a layout list

A medium review of the submodule correction found that its per-layout scoping
was again partly wrong: under `--work-tree=.` a linked worktree still
mis-stages silently, and a submodule does too, since an inherited
`GIT_WORK_TREE` overrides `core.worktree`. Three rounds had each listed
layouts that the next probe partly disproved, so `environments.md` now states
the mechanism once, in the paragraph on inherited `GIT_DIR`: an absolute
`GIT_DIR` survives a `cd`, and the work tree is re-resolved from the new cwd
unless something pins it independently of the cwd (`core.worktree` does, the
relative `GIT_WORK_TREE=.` does not); a relative `GIT_DIR` fails loudly.
Layouts appear only as "verified in" examples (git 2.47.3: linked worktree
and `--separate-git-dir` with and without `--work-tree=.`, submodule with and
without it, `.git` directory with `--git-dir=.git` or `--work-tree=.`, and
exported or `--git-dir` from a subdirectory in each). The Consequence
paragraph points there instead of repeating it.

The recipe's exception, and `design.md` limitation 9 with the same wording,
is now the invariant it depends on: `$start` is the top only when the hook
starts there, which fails for a caller-set `GIT_DIR` with no work tree and no
`core.worktree` run from a subdirectory, where any `$path` relative to
`$start` is silently recorded as if relative to the top — not only a file in
the hook's own cwd.

This replaces the layout scoping in the two earlier entries of this date,
[hook-anchor-scope](2026-10-30-hook-anchor-scope.md) and
[hook-anchor-submodule](2026-10-30-hook-anchor-submodule.md).
