# Plan: a hook's own git commands after a `cd`

## When and why it matters

A git hook that runs git on its own repository, typically a pre-commit hook
that regenerates a file and stages it, inherits git's environment. Some of
those values are paths relative to where the hook started. If the hook `cd`s
and then runs git, they point somewhere else: the file is staged at the wrong
path with exit 0, or the commit fails.

The dotfiles setup (`git --git-dir=~/.dotfiles --work-tree=~`) is where it
bites hardest. Every commit hook there gets the relative `GIT_WORK_TREE=.`,
and the work tree has no `.git` to discover, so the recipe shipped today
(blanket unset, restore `GIT_INDEX_FILE` only) dies on
`fatal: not a git repository`.

The fix is one habit: `start=$PWD` at the top, own-repo git as
`git -C "$start" …`, and the unset only in the subshell around other-repo
commands.

## Decisions

1. Replace caveat 2's capture-and-restore recipe with the `git -C "$start"`
   habit (edit (c)).
2. Generalise the existing `SKILL.md` hub row; add no new row.

## Evidence (git 2.47.3, Linux; throwaway repos)

- With `start=$PWD; cd sub; …; git -C "$start" add -- sub/gen` in
  pre-commit, the commit records `sub/gen` in all three modes, in the
  dotfiles layout (absolute and relative flags), in a normal repo committed
  through `--git-dir`/`--work-tree`, and in a normal repo with no flags.
  Pathspec mode shows `D  sub/gen|?? sub/gen|` afterwards, git's
  partial-commit behaviour.
- Without the anchor, `cd sub; git add gen` under an absolute `GIT_DIR`
  exits 0 and records `gen` at the top level; under a relative one it dies on
  `not a git repository`.
- The shipped restore-`GIT_INDEX_FILE` recipe works in a normal repo and dies
  in the dotfiles layout in every mode.
- Under a caller-set work tree, pre-commit, prepare-commit-msg, commit-msg and
  post-commit all start at the work-tree top with `GIT_WORK_TREE=.`. A
  caller-set relative `GIT_DIR` arrives absolute when git started below the
  work-tree top.
- The blanket unset drops the caller's `git -c` settings
  (`GIT_CONFIG_PARAMETERS`) even with the three variables restored.

## Draft text

### environments.md, section "Git hook environment leakage"

**(a)** Append to the paragraph beginning "Consequence: an inherited
repo-local variable", after its sentence "A **relative** one re-resolves under
the new cwd, where it either names the other repo's own file or fails
loudly.":

```markdown
The same holds for the hook's own `cd`: a caller-set work tree reaches the hook as the relative `GIT_WORK_TREE=.`, so after `cd sub` beside an absolute `GIT_DIR`, `git add gen` exits 0 and records `gen` at the top level.
```

**(b)** Delete the paragraph beginning "This section covers the environment
git itself gives a hook". Extend two bullets by one clause each:

- the bullet beginning "Commit hooks where `.git` is a directory: **no
  `GIT_DIR`**", after "**no `GIT_DIR`**":

  ```markdown
  unless the caller set one (`--git-dir` or exported), which arrives made absolute when git started below the work-tree top
  ```

- the bullet beginning "`GIT_WORK_TREE`: not exported to commit hooks", after
  "not exported to commit hooks":

  ```markdown
  unless the caller set a work tree (`--work-tree` or exported), when every commit hook gets `GIT_WORK_TREE=.` whatever form was passed
  ```

**(c)** Replace caveat 2 (the bullet beginning "A commit hook already built
around a blanket unset", its code block and its "Verified" paragraph) with:

````markdown
- **A commit hook that must stage a file itself** keeps git's env for that add and anchors it to the starting directory, since a `cd` re-resolves every relative value it inherited. Move any blanket unset into the subshell around other-repo commands: with `GIT_INDEX_FILE` gone the add dies in the `-a` and pathspec modes, as above, and restoring it alone relies on discovering the repository from the cwd, which a bare-dotfiles work tree does not allow. Keeping the env also keeps the caller's `git -c` settings (`GIT_CONFIG_PARAMETERS`, in the bullet above). Other-repo commands keep the subshell unset above.
  ```sh
  start=$PWD                         # before any cd: the work-tree top
  …
  git -C "$start" add -- "$path"     # $path relative to $start
  ```
  Verified, git 2.47.3. In pathspec mode (`git commit <path>`) the add lands in the temporary index, so it is in the commit but not the real one: a file the hook newly created then shows `D ` plus `??` afterwards, and a hook-modified tracked file shows `MM`: the real index keeps the pre-hook content, so a later plain `git commit` reverts the hook's edit unless the file is restaged. That is git's partial-commit behaviour, not a recipe fault.
````

### SKILL.md hub

Replace the row beginning `` | git hook running `git -C elsewhere` `` with:

```markdown
| git hook running git after a `cd` or as `git -C elsewhere` — inherited repo-local env: an absolute value survives, a relative one re-resolves | `start=$PWD` first, own-repo git as `git -C "$start"`; other-repo git in `(unset $(git rev-parse --local-env-vars) GIT_QUARANTINE_PATH; git -C … )`, under `# shellcheck disable=SC2046` |
```

The `references/environments.md` pointer bullet and the checklist line stay.

## Landing edits

- `skills/shell-gotchas/references/environments.md`: (a), (b), (c) above.
- `skills/shell-gotchas/SKILL.md`: the hub row above.
- `docs/design.md` limitation 9, replaced by: "The own-repo staging recipe
  and the inherited `GIT_WORK_TREE=.` are probed on pre-commit,
  prepare-commit-msg, commit-msg and post-commit; hooks run by other commands
  are unprobed for them."
- `TODO.md`: remove the item.
- A changelog entry and its pointer line.
