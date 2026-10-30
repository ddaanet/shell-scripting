# Proposal: hooks under a caller-set `GIT_DIR`/`GIT_WORK_TREE`

Status: proposal only. Nothing in `skills/` is changed. Adding the coverage is
my human partner's call.

Source: the `TODO.md` item "Cover hooks run under a caller-set
`--git-dir`/`--work-tree` (bare dotfiles pattern)", and `docs/design.md`
limitation 9.

## Summary

Every case in the TODO item comes from two facts. Neither needs a new rule.

1. When the caller sets the work tree (`--work-tree` or an exported
   `GIT_WORK_TREE`, together with a git dir), every commit hook receives
   **`GIT_WORK_TREE=.`**, whatever form the caller passed. A caller-set git dir
   with no work tree gives the hook no `GIT_WORK_TREE` at all (P5). The
   shipped rule ("an inherited absolute path survives a cwd change; a relative
   one re-resolves") therefore already predicts the result: a hook `cd` moves
   the work tree silently when `GIT_DIR` is absolute, and fails loudly when
   `GIT_DIR` is still relative.
2. After the blanket unset, a same-repo command needs three things back: the
   repository, the work tree and the commit's index. A non-bare `.git`
   discoverable from the hook's cwd supplies the first two. A bare-dotfiles
   work tree has no `.git`, and its repository is bare, so all three must be
   restored (P7).

The fix is the shipped advice applied consistently. Capture the starting
directory, run same-repo git as `git -C "$start"`, and keep the unset in a
subshell around other-repo commands. P7 verified this pattern with a fresh
repository per case: both layouts, absolute and relative flags, all three
commit modes.

The probes disproved two of the TODO's claims and found one defect in the
shipped text (see "Corrections").

## Probe results (git 2.47.3, Linux)

The scripts are in `$TMPDIR/cgd/` (`probe1.sh` … `probe10.sh`, `hook-*.sh`), and
`$T` is each probe's `mktemp -d` root. The layout is a bare `dot.git` with work
tree `home/` and files `a` and `sub/b`. P1–P6 use a `pre-commit` hook. The
sandbox adds proxy entries to `GIT_CONFIG_PARAMETERS`; they are filtered out
below.

P2, P3 and P6 ran their three commit modes in sequence on one repository, so
only their plain-mode rows are isolated. P7 reruns all three with a fresh
repository per case and supersedes them where they differ.

### P1: environment the hook receives (`probe1.sh`)

| invocation (cwd)                                          | mode     | `GIT_DIR`        | `GIT_INDEX_FILE`                           | `GIT_WORK_TREE` | `GIT_PREFIX` |
| --------------------------------------------------------- | -------- | ---------------- | ------------------------------------------ | --------------- | ------------ |
| `--git-dir=$T/dot.git --work-tree=$T/home` (home)         | plain    | `$T/dot.git`     | `$T/dot.git/index`                         | `.`             | empty        |
| same                                                      | `-a`     | `$T/dot.git`     | `$T/dot.git/index.lock`                    | `.`             | empty        |
| same                                                      | pathspec | `$T/dot.git`     | `$T/dot.git/next-index-34.lock`            | `.`             | empty        |
| `--git-dir=../dot.git --work-tree=.` (home)               | plain    | `../dot.git`     | `../dot.git/index`                         | `.`             | empty        |
| same                                                      | `-a`     | `../dot.git`     | `$T/home/../dot.git/index.lock`            | `.`             | empty        |
| same                                                      | pathspec | `../dot.git`     | `$T/home/../dot.git/next-index-62.lock`    | `.`             | empty        |
| absolute flags (home/sub)                                 | plain    | `$T/dot.git`     | `$T/dot.git/index`                         | `.`             | `sub/`       |
| `--git-dir=../../dot.git --work-tree=..` (home/sub)       | plain    | **`$T/dot.git`** | `$T/dot.git/index`                         | `.`             | `sub/`       |
| exported `GIT_DIR=$T/dot.git GIT_WORK_TREE=$T/home` (home) | plain    | `$T/dot.git`     | `$T/dot.git/index`                         | `.`             | empty        |
| exported `GIT_DIR=../dot.git GIT_WORK_TREE=.` (home)      | plain    | `../dot.git`     | `../dot.git/index`                         | `.`             | empty        |
| exported `GIT_DIR=../../dot.git GIT_WORK_TREE=..` (home/sub) | plain | **`$T/dot.git`** | `$T/dot.git/index`                         | `.`             | n/a          |

In every row the hook's cwd is `$T/home`, the top of the work tree. A relative
`GIT_DIR` is passed through relative only when git was started from the top of
the work tree. When git started in a subdirectory, it had to `chdir` and made
`GIT_DIR` absolute. `GIT_WORK_TREE` is `.` in every row. `-c k=v` reaches the
hook as `GIT_CONFIG_PARAMETERS`.

### P2: hook that `cd`s and then stages (`probe2.sh` + `hook-cd.sh`)

The hook runs `cd sub; printf g > gen; git add gen`, with the environment
untouched.

```text
abs flags, all 3 modes:  show-toplevel=$T/home/sub   add exits 0
                         tree: a gen sub/b   status:  D gen|?? sub/gen|
rel flags, all 3 modes:  fatal: not a git repository: '../dot.git'   add rc=128
```

P7 confirms every row in isolation. When `GIT_DIR` is absolute, the inherited
`GIT_WORK_TREE=.` makes `sub/` the work tree. The file is committed as `gen` at
the top level, with no error.

The control is `hook-nocd.sh`: `git add sub/gen` from the starting cwd records
`sub/gen` in all 6 runs (3 modes × abs/rel), and `status` is clean afterwards.

### P3: blanket unset, then restore (`probe2.sh` + `hook-restore.sh`, invoked as `git -c probe.key=v …`)

The first variant is the shipped caveat-2 recipe, which restores only
`GIT_INDEX_FILE`:

```text
all 6 runs: fatal: not a git repository (or any parent up to mount point /)
            add rc=128   tree: a sub/b   status: ?? sub/gen|
```

The second variant restores `GIT_DIR`, `GIT_WORK_TREE` and `GIT_INDEX_FILE`:

```text
all 6 runs: tree: a sub/b sub/gen   status clean
            -c probe.key before unset: v   in restored cmd: []
```

The restored add works, but the caller's `-c` configuration is gone
(`GIT_CONFIG_PARAMETERS` and `GIT_CONFIG_COUNT` are both in
`--local-env-vars`). P7 isolates each mode and adds the other restore subsets.

### P4: does `safe.directory` reach the restored add? (`probe3.sh`, `GIT_TEST_ASSUME_DIFFERENT_OWNER=1`)

```text
discovery, no safe.directory:                    rc=128
discovery, -c safe.directory=*:                  rc=0
explicit --git-dir/--work-tree, no safe.dir:     rc=0
explicit GIT_DIR=plain/.git, no safe.dir:        rc=0
```

Git skips the ownership check when `GIT_DIR` is explicit. The restored add
cannot need `safe.directory`, so the TODO's example is wrong.

### P5: `--git-dir` with no work tree, run from a subdirectory of a normal repo (`probe4.sh`, `probe5.sh`)

The repository is `r/` with `a` and `sub/b`. The hook runs
`printf g > gen; git add gen`, and the command is run from `r/sub`.

```text
-a:     hook cwd=$T/r/sub  GIT_DIR=$T/r/.git  no GIT_WORK_TREE  show-toplevel=$T/r/sub
        tree: gen          status:  D gen|?? a|?? sub/|
plain:  tree: a gen sub/b  status:  D gen|?? sub/gen|
```

The shipped paragraph beginning "Under inherited `GIT_DIR` (without
`GIT_WORK_TREE`)" already states the mechanism: the cwd is taken as the
work-tree root. With `-a`, the caller's own commit deletes everything outside
`sub/`, so the hook's misplaced file is the smaller problem.

### P6: proposed pattern (`hook-top.sh` bare layout; `probe9.sh` normal `.git` layout)

The hook runs `start=$PWD; cd sub; printf g > gen; git -C "$start" add -- sub/gen`.
Other-repo commands go through an `other() ( unset …; "$@" )` wrapper.

```text
bare dotfiles, plain mode:  tree: a sub/b sub/gen  status clean
    -c probe.key via -C start: [v]    other git -C $OTHER rev-parse --show-toplevel: $OTHER
```

The `-a` and pathspec rows of this run reused one repository; P7 replaces them.

### P7: every variant, fresh repository per case (`probe10.sh` + `hook-var.sh`, `hook-env.sh`)

Each case gets its own `mktemp -d` repository: layout × form × mode. The
layouts are bare dotfiles (`dot.git` + `home/`) and a normal repository `r/`
committed through caller-set flags (`--git-dir=$T/r/.git --work-tree=$T/r`, or
`--git-dir=.git --work-tree=.`). The forms are absolute and relative flags.
The modes are plain, `-a` and pathspec. That gives 12 cases per variant.

Environment, with `hook-env.sh` installed as pre-commit, prepare-commit-msg,
commit-msg and post-commit:

```text
all 12 cases, all 4 hooks: cwd = work-tree top, GIT_WORK_TREE=., GIT_PREFIX empty,
    GIT_DIR as in P1
pre-commit, prepare-commit-msg, commit-msg: GIT_INDEX_FILE per mode, as in P1
post-commit: GIT_INDEX_FILE = <GIT_DIR>/index in every mode
```

Staging variants (pre-commit hook; `rel` is relative flags):

```text
top    (start=$PWD; cd sub; git -C "$start" add -- sub/gen):
       all 12: tree a sub/b sub/gen; status clean, except pathspec: 'D  sub/gen|?? sub/gen|'
cd     (cd sub; git add gen):
       abs, all 6: add exits 0, tree a gen sub/b, status ' D gen|?? sub/gen|' (pathspec 'D  gen|…')
       rel, all 6: fatal: not a git repository: '<GIT_DIR>'  add rc=128
after the blanket unset, restore …
  GIT_INDEX_FILE only:  bare, all 6: fatal: not a git repository     normal, all 6: recorded
  GIT_DIR only:         bare, all 6: fatal: this operation must be run in a work tree
                        normal: plain recorded; -a, pathspec: Unable to create '…/index.lock'
  GIT_WORK_TREE only:   bare, all 6: fatal: not a git repository
                        normal: plain recorded; -a, pathspec: index.lock
  GIT_DIR+WORK_TREE:    both layouts: plain recorded; -a, pathspec: index.lock
  GIT_DIR+INDEX_FILE:   bare, all 6: must be run in a work tree      normal, all 6: recorded
```

"Recorded" means the tree gains `sub/gen`. In pathspec mode a recorded add
reaches the commit but not the real index (`D  sub/gen|?? sub/gen|`), which is
the partial-commit behaviour caveat 2 already describes. The pattern behind
every row: a same-repo add needs the repository (`GIT_DIR`, or discovery), a
work tree (`GIT_WORK_TREE`, or the cwd of a non-bare repository) and the
commit's index (`GIT_INDEX_FILE`; plain mode's is the default index). Whatever
is not restored has to come from discovery, and in the bare layout discovery
supplies nothing.

## Corrections to the TODO item

- **"kept relative if given relative"** holds for `GIT_DIR` only when git
  starts at the top of the work tree. When it starts in a subdirectory, a
  relative `GIT_DIR`, given by flag or exported, arrives absolute. `GIT_WORK_TREE`
  arrives as the relative `.` in every case (P1), so it always follows a hook
  `cd`. The proposed fix makes both forms irrelevant.
- **"plain-mode `GIT_INDEX_FILE` relative to it"** is confirmed. In the lock
  modes the index path is absolute but still contains `..`, which has no effect
  on the outcome.
- **"the blanket unset drops `git -c`/`GIT_CONFIG_*` (e.g. `safe.directory`)"**
  is true for `-c` in general (P3) and false for `safe.directory`, because an
  explicit `GIT_DIR` bypasses the ownership check (P4).
- **"restored values break after a hook `cd`"** is confirmed for a restored
  relative `GIT_DIR`. The larger break needs no restore at all: an absolute
  `GIT_DIR` plus `GIT_WORK_TREE=.` silently stages at the wrong path (P2, P7).
- **"`--git-dir` without a work tree from a subdirectory stages the hook's file
  at the wrong path"** is confirmed (P5). The shipped inherited-`GIT_DIR`
  paragraph already covers it, and it is the caller's error.

## Defect found in shipped text

The second caveat in `environments.md` (beginning "A commit hook already built
around a blanket unset") prescribes restoring `GIT_INDEX_FILE` alone. That
works where a non-bare `.git` is discoverable from the hook's cwd, including
a normal repository committed through caller-set flags (P7). In the bare
dotfiles layout it dies with `fatal: not a git repository` in every mode (P3,
P7). The caveat assumes discovery without saying so. See open question 1.

## Draft text

### environments.md

**Replace** the paragraph beginning "This section covers the environment git
itself gives a hook" (the "out of scope here" paragraph) with:

```markdown
The bullets below describe the environment git gives a hook when the caller sets neither `GIT_DIR` nor `GIT_WORK_TREE`. A caller-set `GIT_DIR` alone is covered by the inherited-`GIT_DIR` paragraph after the caveats, and a caller-set work tree by the paragraph after that.
```

This scopes the unconditional bullets ("**no `GIT_DIR`**" for a `.git`
directory, and "`GIT_WORK_TREE`: not exported to commit hooks") to the case
they were probed in, so they do not contradict the new paragraph.

**Insert** a new paragraph after the paragraph beginning "Under inherited
`GIT_DIR` (without `GIT_WORK_TREE`)", immediately before the heading
`### Testing a hook that touches the index`:

````markdown
**Caller-set `GIT_DIR` and `GIT_WORK_TREE` together** (`git --git-dir=… --work-tree=…`, or both exported, as in the bare dotfiles pattern): the commit hooks (pre-commit, prepare-commit-msg, commit-msg, post-commit) start at the top of the work tree and receive `GIT_DIR`, an index path, and `GIT_WORK_TREE=.` whatever form the caller passed (verified, git 2.47.3). `GIT_DIR` stays relative only when git was started at the top of the work tree. The rule above decides the rest. `GIT_WORK_TREE=.` follows a hook `cd`, so with an absolute `GIT_DIR` a `git add gen` from `sub/` exits 0 and records `gen` at the top level, and with a relative `GIT_DIR` the same add dies on `not a git repository`. After the blanket unset, a same-repo command needs the repository, the work tree and the commit's index back, and whatever is not restored must come from discovery. A non-bare `.git` discoverable from the hook's cwd supplies the first two, so the restore in the caveat above works. In the bare dotfiles layout nothing is discoverable, so all three variables must be restored. The unset also drops `GIT_CONFIG_PARAMETERS`, which carries every `git -c` the caller passed. So capture the starting directory before any `cd`, run same-repo commands from it, and unset only inside the subshell around other-repo commands:

```sh
start=$PWD                         # hook cwd: the work-tree top
other() (
  # shellcheck disable=SC2046 # intended word-split
  unset $(git rev-parse --local-env-vars) GIT_QUARANTINE_PATH
  "$@"
)
git -C "$start" add -- "$path"     # $path relative to the work-tree top
other git -C /other/repo …
```

Verified with a fresh repository per case: the bare dotfiles layout and a `.git` directory, absolute and relative flags, all three commit modes. In pathspec mode the add reaches the commit but not the real index, as in the caveat above.
````

The paragraph has about 210 words plus the code block. `environments.md` grows
from 153 to about 168 lines.

### SKILL.md hub

Two options for the row beginning `` | git hook running `git -C elsewhere` ``:

- **A (recommended): add a row** directly below it.

  ```markdown
  | git hook under caller-set `GIT_DIR`/`GIT_WORK_TREE` (dotfiles) — inherited `GIT_WORK_TREE=.` follows a hook `cd`; the blanket unset leaves nothing to discover | `start=$PWD` first, same-repo git as `git -C "$start"`, the unset only in a subshell around other-repo commands |
  ```

  The trap is different from that row's (the hook's *own* repository is lost,
  rather than another repository being hit), so it gets its own symptom
  column. Cost: one hub line.
- **B: extend that row's fix cell** with `; for same-repo commands under a
  caller-set GIT_DIR, git -C "$start" with $start captured before any cd`.
  This costs no new row, but it buries a separate symptom inside the fix
  column.

Neither option changes the `references/environments.md` pointer bullet.

### Landing edits for the main thread (not done here)

- `environments.md`: the replacement and insertion above.
- `SKILL.md`: option A or B.
- `docs/design.md`: replace limitation 9 with one stating what remains
  uncovered: under a caller-set `GIT_DIR`/`GIT_WORK_TREE`, the catalog covers
  the commit hooks only, and hooks run by other commands are unprobed.
- `TODO.md`: remove the item.
- A changelog entry and its pointer line.
- Caveat 2: depends on open question 1.

## Deliberately not covered

- **Hooks outside a commit.** P7 probed the four commit hooks. The draft names
  them and claims nothing about receive hooks, post-checkout or
  reference-transaction under a caller-set dir. The replacement limitation
  records this.
- **An inherited absolute `GIT_DIR` leaking into `git -C /other`.** The
  existing consequence paragraph and the unset already cover it, unchanged in
  this layout.
- **`--git-dir` without `--work-tree` from a subdirectory (P5).** It follows
  from the shipped inherited-`GIT_DIR` paragraph, and the caller's commit is
  wrong regardless of the hook. A hook cannot detect it, because
  `GIT_WORK_TREE` is unset and `GIT_PREFIX` is empty.
- **Per-mode index paths under a caller-set dir.** `git -C "$start"` makes
  them irrelevant, so listing them would bring back the per-case claims that
  made the 0.5.1 cycle fail to converge.
- **Which restore subsets work in which layout.** The draft states the rule
  (restore what discovery cannot supply) instead of P7's table.
- **Pathspec-mode real-index divergence.** Caveat 2 already covers it. P7
  reproduced it in both layouts.
- **`safe.directory`.** P4 shows it plays no part when `GIT_DIR` is explicit.
- **Other `GIT_CONFIG_*` forms** (`GIT_CONFIG`, `GIT_CONFIG_COUNT`). The draft
  names `GIT_CONFIG_PARAMETERS` only as the carrier of `-c`. The fix avoids the
  unset for same-repo commands, so it covers every form without listing them.

## Open questions for my human partner

1. **Caveat 2 under a caller-set dir.** Its recipe (restore `GIT_INDEX_FILE`
   only) needs discovery, which the bare dotfiles layout lacks. Should caveat 2
   gain a clause like "where a non-bare `.git` is discoverable from the hook's
   cwd; otherwise see the caller-set paragraph below"? Or should it be
   rewritten to recommend the `start=$PWD` + `other()` pattern for every
   layout, and stop recommending restoring after a blanket unset? Default: add
   the clause. The rewrite is cleaner, but it touches text that converged in
   0.5.1.
2. **Hub: option A or B?** Default: A.
