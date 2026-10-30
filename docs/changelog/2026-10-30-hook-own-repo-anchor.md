# 2026-10-30 — Own-repo git in a hook is anchored with `git -C "$start"`

Caveat 2 of the "Git hook environment leakage" section told a hook with a
blanket unset to capture `GIT_INDEX_FILE` and restore it for its own `git add`.
That recipe works in a normal repository and dies on `fatal: not a git
repository` in the bare dotfiles layout (`git --git-dir=~/.dotfiles
--work-tree=~`), where every commit hook gets the relative `GIT_WORK_TREE=.`
and the work tree has no `.git` to discover. It also drops the caller's
`git -c` settings, and a restored relative value breaks after a hook `cd`.

The caveat now prescribes one habit: `start=$PWD` before any `cd`, own-repo git
as `git -C "$start" …`, and the blanket unset only in the subshell around
other-repo commands. The `SKILL.md` hub row is generalised to cover git run
after a `cd` as well as `git -C elsewhere`; no row is added. The inventory
bullets for `GIT_DIR` and `GIT_WORK_TREE` record what a caller-set value looks
like at a commit hook, and the section's out-of-scope paragraph is gone, so
`design.md` limitation 9 now states what was probed (pre-commit,
prepare-commit-msg, commit-msg, post-commit) instead of pointing at `TODO.md`.

Evidence and the modes probed are in
`plans/2026-10-30-caller-set-git-dir-hooks.md`.
