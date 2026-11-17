---
name: git-gotchas
description: "Catalogs git plumbing pitfalls in scripts and hooks: config reads, staging, merge and replay state, transport policy, submodule urls, subtree. This skill should be used when writing, reviewing, or debugging a script or hook that calls `git config`, `add`, `checkout`, `rebase`, `clone`, `submodule` or `subtree`, or one failing with `did not match any files` or `transport … not allowed`."
---

# Git Plumbing Gotchas

A script or hook calling git is shell code: before working on one, also invoke
the `shell-scripting:shell-gotchas` skill. Its
[`environments.md`](../shell-gotchas/references/environments.md) holds the
hook-environment facts (inherited `GIT_DIR`, `--local-env-vars`, submodule
escape, linked worktrees, parsing git output); this skill holds what git itself
does to a script's assumptions. Every row was measured on git 2.47.3.

## Symptoms

Find the error string or the silent behaviour, then read the row's reference
section before changing the code.

| Symptom | Cause | Fix |
|---|---|---|
| `fatal: pathspec '<p>' did not match any files`, exit 128, from `git add -f` of a deleted path | A path that is ignored, absent from disk and never in the index has nothing to match; `-f` overrides the ignore rule, not the pathspec rule | Skip a path only when it is gone from disk *and* `git ls-files -- "$p"` does not list it; never blanket-silence the loop ([index-and-history.md](references/index-and-history.md#staging-a-path-that-never-existed)) |
| A prepared merge vanishes: `rev-parse --verify MERGE_HEAD` fails after a later `git checkout`, staged result still in the index | `checkout` silently unlinks `MERGE_HEAD`, `MERGE_MSG`, `CHERRY_PICK_HEAD`, `REVERT_HEAD` on success; a cleanly auto-merged `merge --no-commit` gives it nothing to refuse over | Guard any re-checkout on a merge in progress; to recover, compare `write-tree` with `merge-tree --write-tree`, restore both pointers, commit ([index-and-history.md](references/index-and-history.md#checkout-erases-a-prepared-merge)) |
| A `pre-commit` guard passes tests driven by `git rebase --continue` with the guard deleted | `rebase --continue` does not fire `pre-commit`; a hand `commit` or `--amend` at the stop, `cherry-pick --continue` and `revert --continue` do | Drive the test through a hand commit at the stop ([index-and-history.md](references/index-and-history.md#which-replays-fire-pre-commit)) |
| A replayed commit records a submodule sha it never had | A `pre-commit` hook staged the gitlink during a rebase or cherry-pick; the submodule worktree does not move with HEAD | Detect a replay via `--git-path` before writing, and write nothing during one ([index-and-history.md](references/index-and-history.md#which-replays-fire-pre-commit)) |
| `fatal: working tree has modifications.  Cannot add.` or `fatal: index has modifications.  Cannot add.` from `git subtree` despite a pathspec-scoped clean check | `git-subtree`'s internal `ensure_clean()` runs an unscoped `git diff-index HEAD`; no flag scopes or bypasses it | Run `git update-index -q --refresh`, commit any real change, then retry; or avoid `git subtree` there ([index-and-history.md](references/index-and-history.md#subtree-refuses-any-tracked-change)) |
| A guard names one of several values and its advised `git config --unset` fails with status 5 | `--get` prints the last value of a multi-valued key, exit 0; `--unset` refuses a multi-valued key | `--get-all`, one value per line; advise `--unset-all` ([config-and-remotes.md](references/config-and-remotes.md#multi-valued-keys)) |
| `fatal: bad config line`, and every git call exits 128 | An unparsable config file breaks all of git, not just `git config` | Absorb only the status meaning "unset" (1) in a guard; a broken config cannot serve as the fixture for that ([config-and-remotes.md](references/config-and-remotes.md#multi-valued-keys)) |
| `git config --get-regexp "$key"` returns another key's value (status 0), misses its own (status 1), or fails `invalid key pattern` (status 6) | The argument is a regex over the key name; a branch or remote name holds `.`, `+`, `(` … | Interpolate a name only into `--get-all`; keep `-z --get-regexp` for hand-written patterns ([config-and-remotes.md](references/config-and-remotes.md#an-interpolated-key-is-a-regex)) |
| `fatal: transport 'file' not allowed` from `submodule add`, `submodule update`, `clone --recurse-submodules` | `protocol.file.allow` defaults to `user`; git's child clone is not the user, and it never reads the parent's repo config | `git -c protocol.file.allow=always …`, or the `GIT_CONFIG_COUNT` env form; test fixtures only ([config-and-remotes.md](references/config-and-remotes.md#transport-policy)) |
| `fatal: transport 'ext' not allowed`; or a review ranks an `ext::sh -c` url as command injection | `ext` is off by default, unless `protocol.ext.allow` or a blanket `protocol.allow=always` enables it | Probe the policy before ranking the finding; a scheme allowlist closes the class where a hook clones a caller's url ([config-and-remotes.md](references/config-and-remotes.md#transport-policy)) |
| A check of a submodule's `remote.origin.url` against a marker written into `.gitmodules` never matches | `submodule init`/`sync` resolve a relative url against the default remote, or the superproject directory when there is none | Match the basename, or read `.gitmodules` ([config-and-remotes.md](references/config-and-remotes.md#submodule-urls-arrive-rewritten)) |
| `fatal: No url found for submodule path '<p>' in .gitmodules` | An entry without a `url` key cannot be initialized, though status and lookups work | Give the entry some url ([config-and-remotes.md](references/config-and-remotes.md#submodule-urls-arrive-rewritten)) |

## References

- [`references/index-and-history.md`](references/index-and-history.md) — staging
  a deleted, never-tracked path; `checkout` erasing a prepared merge; which
  replays fire `pre-commit` and how to detect one; `git subtree`'s unscoped
  clean check.
- [`references/config-and-remotes.md`](references/config-and-remotes.md) —
  multi-valued and interpolated config reads; the `file` and `ext` transport
  policy; submodule urls rewritten on the way in.
