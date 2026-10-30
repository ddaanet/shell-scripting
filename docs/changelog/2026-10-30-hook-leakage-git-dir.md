# 2026-10-30 — The hook-leakage hazard is an inherited absolute path, not GIT_COMMON_DIR

`references/environments.md` claimed that in a linked parent worktree git
exports `GIT_COMMON_DIR` to a hook, so a hand-written unset clearing only
`GIT_DIR` would let it redirect a submodule into the parent's object store. The
claim came from a memory fact that cited no probe, and probes on git 2.47.3
contradict it: none of the hooks probed in a linked worktree (pre-commit,
commit-msg, post-commit, post-checkout, reference-transaction) saw
`GIT_COMMON_DIR`.

The "Git hook environment leakage" section now states the mechanism as one
rule. An inherited repo-local variable holding an absolute path survives
`git -C`: an absolute `GIT_DIR` retargets the command at the hook's
repository, an absolute `GIT_INDEX_FILE` alone splices the hook's index onto
the other repository's objects; a relative one
re-resolves under the new cwd, where it names the other repository's own file
or fails loudly, which is why the relative `.git/index` gives the loud
`index file open failed` symptom. Under an absolute `GIT_DIR`,
`git -C sub rev-parse HEAD` silently answers for the hook's repository. An
absolute `GIT_INDEX_FILE` alone (`-a` and pathspec commits where `.git` is a
directory) is mostly loud: `ls-files` answers silently wrong, but `status` and
`diff --cached` die and a submodule `add` fails the parent commit. The full
unset stays the fix.

The inventory is keyed by whether `.git` is a directory or a gitfile (linked
worktree, submodule, `--separate-git-dir`), so it no longer reads as a closed
list of layouts. It gains the pre-receive quarantine variables
(`GIT_OBJECT_DIRECTORY`, `GIT_ALTERNATE_OBJECT_DIRECTORIES`, and
`GIT_QUARANTINE_PATH`, which `--local-env-vars` omits) and the
`GIT_CONFIG_PARAMETERS` that `git -c` passes to commit hooks. A bare repo's
hook `cd` retargets silently only into another git dir; anywhere else it fails
loudly. The per-mode `GIT_INDEX_FILE` paths are given once, relative to
`git rev-parse --absolute-git-dir`, since `<top>/.git/…` holds only where
`.git` is a directory. The section states its scope: the environment git
itself gives a hook, not a `GIT_DIR` or `GIT_WORK_TREE` the caller sets by
flag or export (the bare dotfiles pattern), a gap `design.md` now lists among
its limitations. The unset
snippet, in the reference and the `SKILL.md` hub, also names
`GIT_QUARANTINE_PATH`, so a pre-receive hook can write refs into another
repository. The `GIT_WORK_TREE` bullet records that
reference-transaction during `git worktree add` gets `GIT_WORK_TREE=.`, with
the hooks probed named.

The testing advice drives real commits in each commit mode and in layouts the
rule tells apart, and asserts on effects, including `git status` after the
commit, never on exit status or an error string alone. It no longer tests an
unset for completeness: no commit hook probed receives `GIT_COMMON_DIR` or
the quarantine variables, so a commit test cannot show a hand-written unset
missing them, and the full unset is the rule.

Review rounds kept adding per-layout outcome claims to the section, and each
next round partly disproved them. Stating the absolute/relative rule and
deriving the cases from it replaces that list. See the diff.
