# Proposal: hooks under a caller-set `GIT_DIR`/`GIT_WORK_TREE`

Status: proposal only. Nothing in `skills/` is changed. Adding the coverage is
my human partner's call.

Source: the `TODO.md` item "Cover hooks run under a caller-set
`--git-dir`/`--work-tree` (bare dotfiles pattern)", and `docs/design.md`
limitation 9.

## Summary

A hook's inherited env mixes absolute values, which survive a `cd`, and
relative ones, which re-resolve; a caller-set work tree adds `GIT_WORK_TREE=.`
to the relative ones. The fix in every layout P7 probed: `start=$PWD`,
own-repo git as `git -C "$start" …`, and the shipped unset only in the
subshell around other-repo commands. Edits under "Draft text"; two open
questions at the end.

## Probe results (git 2.47.3, Linux)

The scripts are in `$TMPDIR/cgd/` (`probe1.sh` … `probe10.sh`, `hook-*.sh`), and
`$T` is each probe's `mktemp -d` root. The bare layout is `dot.git` with work
tree `home/` and files `a` and `sub/b`. The sandbox adds proxy entries to
`GIT_CONFIG_PARAMETERS`; they are filtered out below.

### P1: environment a pre-commit hook receives (`probe1.sh`)

| caller (cwd)                                         | `GIT_DIR`        | `GIT_INDEX_FILE` (plain; `-a`; pathspec)                                                   | `GIT_PREFIX` |
| ---------------------------------------------------- | ---------------- | ------------------------------------------------------------------------------------------ | ------------ |
| `--git-dir=$T/dot.git --work-tree=$T/home` (home)    | `$T/dot.git`     | `$T/dot.git/index`; `$T/dot.git/index.lock`; `$T/dot.git/next-index-34.lock`               | empty        |
| `--git-dir=../dot.git --work-tree=.` (home)          | `../dot.git`     | `../dot.git/index`; `$T/home/../dot.git/index.lock`; `$T/home/../dot.git/next-index-62.lock` | empty        |
| absolute flags (home/sub)                            | `$T/dot.git`     | `$T/dot.git/index`                                                                         | `sub/`       |
| `--git-dir=../../dot.git --work-tree=..` (home/sub)  | **`$T/dot.git`** | `$T/dot.git/index`                                                                         | `sub/`       |
| exported `GIT_DIR=../../dot.git GIT_WORK_TREE=..` (home/sub) | **`$T/dot.git`** | `$T/dot.git/index`                                                         | n/a          |

Exporting the same values as the first two rows (plain mode) gives the same
`GIT_DIR` and `GIT_INDEX_FILE`. Rows without a mode list ran plain mode only.
In every row the hook's cwd is `$T/home` and `GIT_WORK_TREE` is `.`. A
relative `GIT_DIR` arrives relative only when git started at the top of the
work tree; from a subdirectory git `chdir`s and makes it absolute. `-c k=v`
reaches the hook as `GIT_CONFIG_PARAMETERS`.

### P4: does `safe.directory` matter under an explicit `GIT_DIR`? (`probe3.sh`, `GIT_TEST_ASSUME_DIFFERENT_OWNER=1`)

```text
discovery, no safe.directory:                    rc=128
discovery, -c safe.directory=*:                  rc=0
explicit --git-dir/--work-tree, no safe.dir:     rc=0
explicit GIT_DIR=plain/.git, no safe.dir:        rc=0
```

Git skips the ownership check when `GIT_DIR` is explicit.

### P5: `--git-dir` with no work tree, run from a subdirectory of a normal repo (`probe4.sh`, `probe5.sh`)

The repository is `r/` with `a` and `sub/b`. The hook runs
`printf g > gen; git add gen`, and the command is run from `r/sub`.

```text
-a:     hook cwd=$T/r/sub  GIT_DIR=$T/r/.git  no GIT_WORK_TREE  show-toplevel=$T/r/sub
        tree: gen          status:  D gen|?? a|?? sub/|
plain:  tree: a gen sub/b  status:  D gen|?? sub/gen|
```

The shipped paragraph beginning "Under inherited `GIT_DIR` (without
`GIT_WORK_TREE`)" already states the mechanism, and with `-a` the caller's own
commit deletes everything outside `sub/`.

### P7: fresh repository per case (`probe10.sh` + `hook-var.sh`, `hook-env.sh`)

Each case gets its own `mktemp -d` repository: layout × form × mode. The
layouts are the bare one and a normal repository `r/` committed through
caller-set flags (`--git-dir=$T/r/.git --work-tree=$T/r`, or
`--git-dir=.git --work-tree=.`). The forms are absolute and relative flags;
the modes are plain, `-a` and pathspec: 12 cases.

```text
environment (hook-env.sh as pre-commit, prepare-commit-msg, commit-msg, post-commit):
  all 12 cases, all 4 hooks: cwd = work-tree top, GIT_WORK_TREE=., GIT_PREFIX empty, GIT_DIR as in P1
  pre-commit, prepare-commit-msg, commit-msg: GIT_INDEX_FILE per mode, as in P1
  post-commit: GIT_INDEX_FILE = <GIT_DIR>/index in every mode
staging (pre-commit):
  top  (start=$PWD; cd sub; git -C "$start" add -- sub/gen):
       all 12: tree a sub/b sub/gen; status clean, except pathspec: 'D  sub/gen|?? sub/gen|'
  cd   (cd sub; git add gen):
       abs, all 6: add exits 0, tree a gen sub/b, status ' D gen|?? sub/gen|' (pathspec 'D  gen|…')
       rel, all 6: fatal: not a git repository: '<GIT_DIR>'  add rc=128
```

After the blanket unset, restoring `GIT_INDEX_FILE` alone (the shipped caveat-2
recipe) records the add in the normal layout in all 6 cases and dies on
`fatal: not a git repository` in the bare layout in all 6. Across the restore
subsets probed, a same-repo add needs the repository, a work tree and the
commit's index, and whatever is not restored must come from discovery, which
the bare layout does not offer.

Earlier runs on one bare repository, modes in sequence (`probe2.sh` with
`hook-nocd.sh` and `hook-restore.sh`; `hook-top.sh`): `git add sub/gen` from the
starting cwd with the env untouched records `sub/gen` in all 6 runs;
`git -c probe.key=v` is visible to `git -C "$start"` (`[v]`) but gone after
the unset even with `GIT_DIR`, `GIT_WORK_TREE` and `GIT_INDEX_FILE` restored
(`[]`); and `git -C $OTHER rev-parse --show-toplevel` inside the subshell
unset reports `$OTHER`.

### P8: the same pattern with no caller flags (normal `.git` repo)

A fresh repo per mode, with no `--git-dir`/`--work-tree`. pre-commit does
`start=$PWD; cd sub; printf gen > gen; git -C "$start" add -- sub/gen`. In
plain and `-a` mode the commit exits 0, records `sub/gen`, and `status` is
clean. In pathspec mode it exits 0 and records `sub/gen`, and `status` shows
`D  sub/gen|?? sub/gen|`, which is the partial-commit behaviour caveat 2
already documents. This backs the recast caveat 2's "Verified" for commits
made without flags.

## Corrections

- TODO: **"kept relative if given relative"** holds for `GIT_DIR` only when
  git starts at the top of the work tree; from a subdirectory it arrives
  absolute, and `GIT_WORK_TREE` is always `.` (P1).
- TODO: **"the blanket unset drops `git -c`/`GIT_CONFIG_*` (e.g.
  `safe.directory`)"** holds for `-c` and not for `safe.directory`, because an
  explicit `GIT_DIR` bypasses the ownership check (P4).
- Shipped caveat 2 (beginning "A commit hook already built around a blanket
  unset") restores `GIT_INDEX_FILE` alone, which relies on discovering the
  repository from the cwd: it works in a normal layout and dies in the bare
  layout in every mode (P7).

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

### Landing edits for the main thread (not done here)

- `skills/shell-gotchas/references/environments.md`: (a) "Consequence: an
  inherited repo-local variable"; (b) "This section covers the environment
  git itself gives a hook", "Commit hooks where `.git` is a directory",
  "`GIT_WORK_TREE`: not exported"; (c) "A commit hook already built around a
  blanket unset".
- `skills/shell-gotchas/SKILL.md`: the row "git hook running `git -C
  elsewhere`".
- `docs/design.md` limitation 9, replaced by: "The own-repo staging recipe
  and the inherited `GIT_WORK_TREE=.` are probed on pre-commit,
  prepare-commit-msg, commit-msg and post-commit; hooks run by other commands
  are unprobed for them."
- `TODO.md`: remove the item.
- A changelog entry and its pointer line.

## Deliberately not covered

- **Hooks outside a commit.** P7 probed the four commit hooks only; the
  replacement limitation records this.
- **`--git-dir` without `--work-tree` from a subdirectory (P5).** The shipped
  "Under inherited `GIT_DIR` (without `GIT_WORK_TREE`)" paragraph covers it,
  and the caller's commit is wrong regardless of the hook.

## Open questions for my human partner

1. **Caveat 2: recast or clause?** Default: the recast in (c), which retires
   the capture-and-restore recipe for `git -C "$start"`. Alternative: keep the
   recipe, which converged in 0.5.1, and add a clause limiting it to a hook
   whose cwd discovers a non-bare `.git`.
2. **Hub row.** Default: generalise the existing row as above. Alternatives:
   a separate row below it, or extending only its fix cell.
