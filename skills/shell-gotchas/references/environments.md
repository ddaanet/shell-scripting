# Hostile Environments: Git Hooks, Submodules, Worktrees, Claude Code

Scripts inherit an environment shaped by whatever invoked them. These gotchas are invisible in a normal terminal and only fire in the real context — hooks, submodules, sandboxes.

Git facts verified June 2026 against [githooks(5)](https://git-scm.com/docs/githooks), [git(1) ENVIRONMENT](https://git-scm.com/docs/git#_environment_variables), [git-worktree(1)](https://git-scm.com/docs/git-worktree), and empirical repros on git 2.47.

## Git hook environment leakage

githooks(5) says only that "environment variables, such as `GIT_DIR`, `GIT_WORK_TREE`, etc., are exported so that Git commands run by the hook can correctly locate the repository." What is *actually* exported depends on the hook and the repository layout (verified, git 2.47):

- Plain repo, main worktree, commit hooks: **no `GIT_DIR`** — only a *relative* `GIT_INDEX_FILE` (`.git/index`), plus `GIT_PREFIX`, `GIT_AUTHOR_NAME/EMAIL/DATE`, `GIT_EDITOR=:`.
- Linked worktree or submodule commit: **absolute `GIT_DIR` and `GIT_INDEX_FILE`** pointing into the per-worktree/module store.
- Server-side receive hooks in a bare repo: **`GIT_DIR=.`** with cwd = the git dir — any `cd` silently retargets the repo.
- `GIT_WORK_TREE`: never observed exported by hooks on modern git (unsetting it stays harmless and covers user-set values).

Consequence: a hook that runs `git -C /other/repo …` **works when tested in a plain clone** and silently operates on the *wrong repository's* index and refs when the same hook fires in a worktree, submodule, or bare repo. Testing in one layout proves nothing about the others.

The documented fix (githooks(5) itself), covering all 15 repo-local variables (`git rev-parse --local-env-vars` lists them — includes `GIT_COMMON_DIR`, `GIT_OBJECT_DIRECTORY`, `GIT_CONFIG_PARAMETERS`, which a hand-written three-variable unset misses):

```sh
# around any git command aimed at ANOTHER repo — subshell keeps this repo's env intact
(unset $(git rev-parse --local-env-vars); git -C /other/repo …)
```

Two caveats:

- **Do not strip git's env for same-repo commands.** During a partial commit (`git commit <pathspec>`), `GIT_INDEX_FILE` points to a *temporary* index; a hook that unsets it and runs `git add` stages into the real index instead — the classic lint-staged bug class.
- The unset list does not include `GIT_AUTHOR_NAME/EMAIL/DATE` — a hook committing in another repo silently reuses the original commit's author identity and pinned date unless those are unset too.

Under inherited `GIT_DIR` (without `GIT_WORK_TREE`), repository discovery is off and **the current directory is assumed to be the worktree root** — `git rev-parse --show-toplevel` reports the cwd, wherever that is.

## Hook execution context

- **cwd is the worktree top level, not where the user ran git** — except push-related hooks (pre-receive, update, post-receive, post-update, push-to-checkout), which run in `$GIT_DIR`. `$GIT_PREFIX` holds the subdirectory the user invoked git from; relative paths from the user must be resolved against it.
- **stdin is /dev/null** for most hooks — `read` returns EOF instead of prompting. Hooks that *receive data* on stdin: pre-push, pre-receive, post-receive, post-rewrite, reference-transaction. Interactive prompts need `exec < /dev/tty` and hang where no tty exists (CI, GUI clients).
- **post-checkout fires after `git clone` and `git worktree add`** with the null-ref (`0000…0`) as `$1` — `git diff $1 $2` explodes there. Its exit status also *becomes* the checkout's exit status, breaking `git checkout x && …` chains on a flaky hook.
- **`core.hooksPath` redirection fails silent**: a relative hooksPath resolves per-worktree; where the directory is missing (e.g. a fresh linked worktree), hooks are skipped with no warning. A global hooksPath (husky pattern) disables `.git/hooks` everywhere.
- **reference-transaction runs on nearly every git command** (a single rebase fires it ~30×) — keep it cheap; its exit status only matters in the `prepared` state.

## Submodule escape to the parent

`git -C path/to/submodule` (or `cd` into it) when the submodule is **not checked out** does not fail — the directory is empty, git walks up and operates on the parent repo (verified: `git -C sub status` reports the parent's branch). A "commit the submodule" step can commit the parent instead.

```sh
[ -e path/to/submodule/.git ] || { echo "submodule not checked out" >&2; exit 1; }
```

`.git` in a checked-out submodule is a *file* (`gitdir: ../.git/modules/sub`), not a directory — test with `-e`, not `-d`. Belt-and-braces: compare `git -C sub rev-parse --show-toplevel` against the expected path, or set `GIT_CEILING_DIRECTORIES` to forbid upward discovery.

Also (verified):

- Hooks firing *inside* a submodule read the submodule's own git config, not the parent's. Any config the hook depends on must be mirrored into the submodule.
- A submodule's hooks do **not** live in `sub/.git/hooks` (that's a gitfile) — they live in `parent/.git/modules/<name>/hooks`. Hook installers must resolve `git -C sub rev-parse --git-path hooks`.

## Linked worktrees

Detection: `--git-dir` equals `--git-common-dir` only in the main worktree — but the naive string compare **misclassifies the main worktree as linked when run from a subdirectory** (one path comes back absolute, the other relative; verified). Robust form (git ≥ 2.31):

```sh
[ "$(git rev-parse --path-format=absolute --git-dir)" = \
  "$(git rev-parse --path-format=absolute --git-common-dir)" ]
```

Operations that assume the main worktree (submodule init, module-store surgery, absorbing git dirs) must detect this and refuse or redirect. Submodules are not checked out in fresh linked worktrees — git-worktree(1) BUGS: multiple checkout of a superproject is "NOT recommended" — which arms the submodule-escape gotcha above by default.

## Parsing git output

Use plumbing or `--porcelain` formats (`git status --porcelain`, `git rev-parse`, `git for-each-ref --format=…`). Porcelain formats are documented stable "across Git versions and regardless of user configuration"; human-readable output changes across versions and is localized.

## Claude Code specifics

These apply to scripts run by Claude Code (hooks, install scripts, Bash tool commands). Verified against the [hooks reference](https://code.claude.com/docs/en/hooks.md) and [sandboxing docs](https://code.claude.com/docs/en/sandboxing.md).

- **Sandboxed writes fail mid-run.** The command sandbox allows writes only to the working directory and the session temp directory; anything else gets a raw `Permission denied`, potentially leaving partial state. Scripts that write outside the CWD (git common dir, `$HOME`) should probe writability *up front* and fail with the exact re-run instruction, rather than dying halfway:
  ```sh
  probe="$target_dir/.probe.$$"
  if ! ( : > "$probe" ) 2>/dev/null; then
    echo "cannot write to $target_dir — sandbox? re-run with sandbox disabled" >&2
    exit 3
  fi
  rm -f "$probe"
  ```
- **Use `$TMPDIR`, not `/tmp`.** Claude Code points `TMPDIR` at the session's writable temp directory for sandboxed commands; hardcoded `/tmp` paths may be blocked.
- **`CLAUDE_PLUGIN_ROOT` is documented for hooks, not for Bash tool commands.** Plugin scripts that may be invoked both ways must self-locate as a fallback:
  ```sh
  PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
  ```
- **Hook stdout/stderr channels** (hooks reference): exit 0 stdout is parsed as JSON / transcript-only; exit 2 stderr is fed back to the model; `systemMessage` in JSON output is the user-visible channel. Don't print user-facing messages to channels the user never sees. Hook input JSON carries `session_id`, `cwd`, `hook_event_name`, and event-specific fields like `tool_input.file_path`.
- **Environment freezes at launch** (observed behavior; not in the docs). A session's `PATH`, `CLAUDE_PROJECT_DIR`, and settings-derived values are captured at startup; in-process directory moves (worktree tools) change `cwd` but not that environment. Hook scripts comparing "where am I" against launch-time variables must expect them to diverge. (`SessionStart`-family hooks can persist env via `$CLAUDE_ENV_FILE`.)

## Self-location and cwd discipline

- `self=$(cd "$(dirname "$0")" && pwd)` — works for executed scripts; for *sourced* bash files use `${BASH_SOURCE[0]}` (`$0` is the caller).
- `unset CDPATH` near the top of any script using `cd` — a user's CDPATH makes `cd` print to stdout (corrupting `$(cd … && pwd)` captures) and possibly go elsewhere. ShellCheck flags unguarded `cd` (SC2164) but not CDPATH output pollution.
- Scripts emitted for *other* processes to run (directives, sub-agent instructions) must be cwd-independent: absolute paths and explicit `cd`, never reliance on the consumer's working directory.
