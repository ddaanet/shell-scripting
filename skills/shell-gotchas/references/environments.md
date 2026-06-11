# Hostile Environments: Git Hooks, Submodules, Worktrees, Claude Code

Scripts inherit an environment shaped by whatever invoked them. These gotchas are invisible in a normal terminal and only fire in the real context — hooks, submodules, sandboxes.

## Git hook environment leakage

Git sets `GIT_DIR`, `GIT_INDEX_FILE`, and `GIT_WORK_TREE` before running hooks. Any `git -C /other/repo …` (or `cd /other/repo && git …`) inside a hook then silently operates on the *original* repo's index and git dir — staging the wrong files, creating branches in the wrong repository.

```sh
# first lines of any hook that touches another repo or a submodule
unset GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE
```

## Submodule escape to the parent

`git -C path/to/submodule` (or `cd` into it) when the submodule is **not checked out** does not fail — git walks up and operates on the parent repo. A "commit the submodule" step can commit the parent instead.

```sh
[ -e path/to/submodule/.git ] || { echo "submodule not checked out" >&2; exit 1; }
```

Note `.git` in a checked-out submodule is a *file* (gitfile), not a directory — test with `-e`, not `-d`.

Also: hooks firing *inside* a submodule read the submodule's own git config, not the parent's. Any config the hook depends on must be mirrored into the submodule.

## Linked worktrees

In a linked worktree, the per-worktree git dir differs from the shared one:

```sh
git_dir=$(git rev-parse --git-dir)
common_dir=$(git rev-parse --git-common-dir)
# equal      → main worktree
# different  → linked worktree
```

Operations that assume the main worktree (submodule init, module-store surgery, absorbing git dirs) must detect this and refuse or redirect. Submodules are typically *not* checked out in linked worktrees — which combines with the escape gotcha above.

## Parsing git output

Use plumbing or `--porcelain` formats (`git status --porcelain`, `git rev-parse`, `git for-each-ref --format=…`). Human-readable output changes across versions and locales.

## Claude Code specifics

These apply to scripts run by Claude Code (hooks, install scripts, Bash tool commands):

- **Sandboxed writes fail mid-run.** The command sandbox blocks writes outside an allowlist with a raw `Permission denied`, potentially leaving partial state. Scripts that write outside the CWD (git common dir, `$HOME`) should probe writability *up front* and fail with the exact re-run instruction, rather than dying halfway:
  ```sh
  probe="$target_dir/.probe.$$"
  if ! ( : > "$probe" ) 2>/dev/null; then
    echo "cannot write to $target_dir — sandbox? re-run with sandbox disabled" >&2
    exit 3
  fi
  rm -f "$probe"
  ```
- **Use `$TMPDIR`, not `/tmp`.** The sandbox redirects `TMPDIR` to a writable location; hardcoded `/tmp` paths may be blocked.
- **`CLAUDE_PLUGIN_ROOT` is injected for hooks but NOT for Bash tool commands.** Plugin scripts that may be invoked both ways must self-locate as a fallback:
  ```sh
  PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
  ```
- **Environment freezes at launch.** A Claude Code session's `PATH`, `CLAUDE_PROJECT_DIR`, and settings-derived values are captured at startup; in-process directory moves (worktree tools) change `cwd` but not that environment. Hook scripts comparing "where am I" against launch-time variables must expect them to diverge.
- **Hook stdout/stderr channels.** For most hook events: exit 0 stdout is transcript-only; exit 2 stderr is fed back to the model. `systemMessage` in JSON output is the user-visible channel. Don't print user-facing messages to channels the user never sees.

## Self-location and cwd discipline

- `self=$(cd "$(dirname "$0")" && pwd)` — works for executed scripts; for *sourced* bash files use `${BASH_SOURCE[0]}` ( `$0` is the caller).
- `unset CDPATH` near the top of any script using `cd` — a user's CDPATH makes `cd` print to stdout and possibly go elsewhere.
- Scripts emitted for *other* processes to run (directives, sub-agent instructions) must be cwd-independent: absolute paths and explicit `cd`, never reliance on the consumer's working directory.
