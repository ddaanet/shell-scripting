# Brief: the staging-hook recipe and its test shape for `environments.md`

From: gitlore, 2026-10-16. The ddaanet memory tier retired its
`git-hook-env-leak` fact because `references/environments.md` § Git hook
environment leakage now carries its symptom strings and the commit-mode
`GIT_INDEX_FILE` table. Two parts of that fact are in no skill text yet. This
brief carries them so the skill can take them.

## 1. A hook that clears the environment and stages something itself

`environments.md` prescribes not stripping the environment for same-repo
commands and keeping the unset in a subshell around the other-repo command.
That avoids the problem. It does not cover a hook already built around a
blanket `unset $(git rev-parse --local-env-vars)` that then runs its own
`git add` — gitlore's memory pre-commit hook is one.

`GIT_INDEX_FILE` names the index the in-flight commit will read. A `git add`
run without it targets the wrong index or, under the two lock-file commit
modes, dies on `fatal: Unable to create '.git/index.lock': File exists`, which
under errexit blocks the commit. Capture it before the unset and restore it for
that one call:

```sh
saved=$GIT_INDEX_FILE
unset $(git rev-parse --local-env-vars)   # intended word-split, needs disable=SC2046
…
GIT_INDEX_FILE="$saved" git add -- <path>
```

Verified on git 2.47.3: with it restored, all three commit modes record the
staged change. In the pathspec mode (`git commit <path>`) the add lands in the
temporary index, so it is in the commit but not in the real index, and the
path still shows as modified afterwards. That is git's documented
partial-commit behaviour, not a hook fault.

## 2. The test shape that catches it

Running `bash hooks/pre-commit` from a shell sets none of the leaked variables
and never exercises the index handoff, so a staging bug stays invisible and
the suite stays green while production fails. Two tests are needed:

- One exports the leaked environment — the index-breaking trio
  (`GIT_DIR`, `GIT_INDEX_FILE`, `GIT_WORK_TREE`) *and* a bogus
  `GIT_COMMON_DIR` and `GIT_OBJECT_DIRECTORY` — and asserts the hook exits 0,
  `index file open failed` does not appear, and no refs landed in the bogus
  common dir.
- One drives a real `git commit` in each of the three modes (plain, `-a`,
  pathspec) and asserts the staged change is in the commit.

## Suggested landing

Both fit under § Git hook environment leakage in `environments.md`: the recipe
as the exception to "keep the unset in a subshell", and the test shape as its
verification. `bats.md` may want a pointer to the second.
