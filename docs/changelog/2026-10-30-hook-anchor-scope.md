# 2026-10-30 — Scope of the `git -C "$start"` anchor, corrected

A medium review of the own-repo anchor change found four claims in the "Git
hook environment leakage" section that a reader would act on wrongly:

- `start=$PWD` is not the work-tree top when the caller sets `--git-dir` with
  no work tree and commits from a subdirectory: the hook starts there and git
  treats it as the top. The recipe now names this as an unhandled exception,
  and `design.md` limitation 9 records it again.
- "Unsetting `GIT_WORK_TREE` stays harmless" is scoped to the other-repo
  subshell, so it no longer contradicts the caveat that keeps git's env for the
  hook's own add.
- `GIT_WORK_TREE=.` under a caller-set work tree is claimed for the four
  commit hooks probed, not "every commit hook", and the bullet's probed list
  gains prepare-commit-msg, matching `design.md`.
- The silent `cd sub; git add gen` mis-stage is attributed to any absolute
  `GIT_DIR` with no work tree discovered, which includes the gitfile layouts;
  a linked-worktree probe (git 2.47.3) recorded `gen` at the top level.
