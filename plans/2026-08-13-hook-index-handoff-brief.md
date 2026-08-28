## Brief: the `GIT_INDEX_FILE` handoff a hook must not strip

2026-08-13

Proposal from the gitlore repo. `references/environments.md` already carries
the right rule; what it describes as the consequence is milder than what
git actually does, and the safe idiom is missing.

### Decisions

- The gap is in `skills/shell-gotchas/references/environments.md`, at the
  bullet "**Do not strip git's env for same-repo commands.**" (line 27). The
  rule stays; the failure mode and the idiom are what change.
- Nothing is proposed for the submodule-escape or linked-worktree sections.
  Both are already covered, and the `--path-format=absolute` comparison at
  line 57 is a better detection than the naive one gitlore was carrying.

### The correction

The bullet frames the failure as silent mis-staging — a hook that unsets
`GIT_INDEX_FILE` and runs `git add` "stages into the real index instead".
That is what happens in one of three invocation modes. In the other two the
hook **dies**.

Git hands a pre-commit hook a different index depending on how the commit
was invoked (verified git 2.47.3, 2026-07-21):

| invocation | `GIT_INDEX_FILE` |
|---|---|
| `git commit` | `.git/index` |
| `git commit -a` | `.git/index.lock` |
| `git commit -- <paths>` / `-p` | `.git/next-index-<pid>.lock` |

Under the two lock flavors git already holds `.git/index.lock`, so a bare
`git add` after a blanket `unset $(git rev-parse --local-env-vars)` fails
hard with `fatal: Unable to create '.git/index.lock': File exists`. Under
`set -e` that aborts the hook and blocks the commit. So the cost of
stripping is a hard block in two modes and silent mis-staging in the third —
not one bug class but two.

### The idiom to add

Capture the variable *before* the blanket unset and restore it for the one
call that stages:

```sh
saved_index="$GIT_INDEX_FILE"
# shellcheck disable=SC2046
unset $(git rev-parse --local-env-vars)
...
GIT_INDEX_FILE="$saved_index" git add -- "$path"
```

With it restored, all three modes record the staged change correctly.

Caveat worth stating alongside it: in pathspec mode the add lands in the
temporary index, so it *is* in the commit, but not in the real index — the
path still shows modified afterwards. That is the documented partial-commit
artifact, not a failure of the idiom.

### Testing note

Running `bash hooks/pre-commit` from a shell never exercises the index
handoff at all, so a staging bug is invisible to it. A suite that only
drives the hook that way passes while production fails. One test must drive
a **real `git commit`** in each of the three modes.

### Optional smaller addition

The submodule-escape section (line 40) names the escape and the guard but
not what the escape produces. Two symptoms are worth a clause: `git -C sub
rev-parse HEAD` returns the *parent's* HEAD, which then gets staged as a
bogus `160000` gitlink pointing at a commit no clone of the submodule
contains — an unclonable superproject; and `git branch <name>` inside the
escaped path creates the branch in the parent instead.

### Additional context

The source is gitlore's `scripts/git-hooks/pre-commit`, which commits a
memory submodule from the parent's pre-commit hook and therefore both needs
the blanket unset and needs to stage into the parent's handed-over index.
The three-mode table came out of driving real commits against that hook.
