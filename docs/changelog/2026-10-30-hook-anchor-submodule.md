# 2026-10-30 — Submodules and exported `GIT_DIR` in the anchor's scope

A medium review of the scope correction found two claims a probe (git 2.47.3)
contradicts:

- The silent `cd sub; git add gen` mis-stage does not happen in a submodule:
  its git dir sets `core.worktree`, so git finds the real top and records
  `sub/gen`. The rule is now an absolute `GIT_DIR` with no `GIT_WORK_TREE`
  and no `core.worktree`, which a linked worktree and `--separate-git-dir`
  meet and a submodule does not.
- The unhandled subdirectory case applies to an exported `GIT_DIR` exactly as
  to `--git-dir`; `environments.md` and `design.md` limitation 9 now say
  "a caller-set `GIT_DIR` (`--git-dir` or exported)".

The recipe comment no longer calls `$start` the work-tree top, and the
exception names the silent failure only for a file the hook writes into its
own cwd; a path relative to the real top fails loudly on a pathspec error.
