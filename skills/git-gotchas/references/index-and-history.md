# Index and History: Staging, Merge State, Replays, Subtree

What git does to the index and to in-progress operations behind a script's back.
Measured on git 2.47.3.

## Staging a path that never existed

A path that is gitignored, absent from disk, and never entered the index cannot
be staged at all, not even with `-f`:

```console
$ git add -f ignored.txt
fatal: pathspec 'ignored.txt' did not match any files      # exit 128
```

`-f` overrides the *ignore* rule, not the "no such pathspec" rule: with the file
gone there is nothing on disk to match and no index entry to record a deletion
against.

This is the benign failure of a hook that stages what a manifest lists,
deletions included. Every tracked path stages fine; the only 128 comes from the
removal of a file that was never tracked, where there is nothing to stage
anyway. A hook that reports staging failures loudly, as it should, reports this
one, and the noise tempts the next reader to put a `2>/dev/null` back on the
whole loop, which re-blinds it to every real failure (a stranded `index.lock`,
say). See "Honest reporting" in
[`robustness.md`](../../shell-gotchas/references/robustness.md).

Separate the case *before* the `git add`: the path is absent from disk *and*
unknown to the index. A new file that exists on disk is untracked too, and must
still be staged, so the index answer alone is not the test. Ask the index with
plain `git ls-files -- "$path"`:

- `git ls-files --error-unmatch` answers the question but writes its refusal to
  stderr, which a hook that exits 0 shows to nobody, and which a script must
  decide whether to suppress.
- Plain `git ls-files -- "$path"` exits 0 either way and answers by *output*: a
  line for a tracked path, nothing for an untracked one.

Read its exit status and test its output separately:

```sh
if ! tracked=$(git ls-files -- "$path"); then
  printf 'cannot read the index for %s\n' "$path" >&2; exit 1
fi
# gone from disk and never tracked: nothing to stage
[ -e "$path" ] || [ -n "$tracked" ] || continue
git add -A -- "$path"
```

Do not fold the two into `[ -z "$(git ls-files -- "$p")" ]`: that discards the
command's status and reads a git failure as "not tracked" (the
substitution-as-argument entry in
[`robustness.md`](../../shell-gotchas/references/robustness.md)).

## Checkout erases a prepared merge

`git checkout` calls `remove_branch_state()`, which unlinks `MERGE_HEAD`,
`MERGE_MSG`, `CHERRY_PICK_HEAD` and `REVERT_HEAD`, silently and on success, with
no warning that an operation was in progress.

The dangerous case is a `git merge --no-commit` that auto-merged **cleanly**.
With no unmerged index entries checkout has nothing to refuse over, so a later
`checkout <same-commit>`, even a no-op re-checkout of the commit HEAD is already
on, succeeds and wipes the merge pointers. The staged merge result survives in
the index; the second-parent link and the message are gone. Tooling that keys on
"a merge is prepared" then reports an unrecoverable state, because its own
discriminator (`rev-parse --verify MERGE_HEAD`) is what was destroyed. A
conflicted merge is safe: unmerged entries make checkout refuse.

Any hook or script that re-checks-out a repository on a schedule (session start,
sync loop, watcher) must guard on a merge in progress first: prepared-merge
state and periodic re-checkout are mutually destructive.

**Recovery.** The index is usually still right; prove it rather than assume:

```sh
git write-tree                                   # the staged result
git merge-tree --write-tree <ours> <theirs>      # what git would produce
```

Identical trees mean nothing was lost. Restore the two pointers and commit:

```sh
git_dir=$(git rev-parse --git-dir)
printf '%s\n' "<theirs-sha>" > "$git_dir/MERGE_HEAD"
printf "Merge commit '%s' into HEAD\n" "<theirs-sha>" > "$git_dir/MERGE_MSG"
git commit --no-edit
```

This keeps the two-parent topology. Committing without restoring `MERGE_HEAD`
produces a single-parent commit that still fast-forwards but orphans the
merged-in history: the content lands, the ancestry does not.

## Which replays fire `pre-commit`

| Path | Fires `pre-commit`? |
|---|---|
| `git rebase --continue` (merge backend, after a conflict) | **no** |
| `git commit` by hand at a conflict stop | yes |
| `git commit --amend` at an interactive `edit` stop | yes |
| `git cherry-pick --continue` | yes |
| `git revert --continue` | yes |
| `git commit` resolving a conflicted merge | yes |

The `rebase --continue` gap matters for tests: a guard driven through
`--continue` passes with no guard at all, so the test asserts nothing. Drive the
hand-made commit at the stop instead; it is both the path that reaches the hook
and the one users take.

**A non-zero `pre-commit` exit during a replay fails that one commit**: the hand
`commit` or `cherry-pick --continue` exits 1, and the rebase or cherry-pick
stays stopped (`rebase-merge` or `CHERRY_PICK_HEAD` still present), waiting for
another attempt. What does damage mid-replay is a hook that *writes*, as the
submodule case below shows, so a hook that writes must detect a replay.

**Detecting a replay:** test for `rebase-merge`, `rebase-apply`,
`CHERRY_PICK_HEAD` and `REVERT_HEAD` via `git rev-parse --git-path <name>`.
`--git-path` is per-worktree, as replay state is. Resolve them *before* any
`unset $(git rev-parse --local-env-vars)`, for the same reason `GIT_INDEX_FILE`
is captured first
([`environments.md`](../../shell-gotchas/references/environments.md)).
`--git-path` can come back relative; resolve it the way `environments.md`'s
"Parsing git output" says before testing it from another directory.

**`MERGE_HEAD` is not a replay marker.** A merge commit is authored now and must
record current state; so must a plain `--amend` on the tip. Both belong in the
test suite as negative controls, or the guard silently over-reaches.

**A submodule pointer is where a replay hook does damage.** A submodule's
worktree does not move when the superproject's HEAD does, so a hook that stages
the gitlink during a replay re-pins the replayed commit to the submodule's
*current* sha instead of the one it recorded, rewriting that commit's content.
Plumbing (`commit-tree`) runs no hooks and never touches the worktree, which is
the way through when surgery is unavoidable.

## Subtree refuses any dirty path

`git subtree add`, `split`, `merge` and `pull` (and `push`, through `split`)
call an internal `ensure_clean()` (in `git-subtree`, under `git --exec-path`)
that runs `git diff-index HEAD` with no pathspec, then
`git diff-index --cached HEAD`, and dies on any hit, whatever the subcommand:

```text
fatal: working tree has modifications.  Cannot add.
fatal: index has modifications.  Cannot add.
```

No flag scopes or bypasses it: not `--force`, not a pathspec argument.

This bites where part of a repository is dirty by design between commits, a
submodule gitlink sitting ahead of what HEAD records, say. A caller's own
pre-check can tolerate that with a pathspec exclusion
(`git diff --quiet HEAD -- . ':(exclude)some/path'`), but `git subtree` still
refuses on its own check: the caller's fix only trades its clear error for
subtree's cryptic one. Before assuming an exclusion lets subtree proceed, check
whether the failure comes from `ensure_clean()` itself (grep the script under
`git --exec-path`). If it does, the only ways through are a genuinely clean tree
(a real commit first) or not using `git subtree` there.
