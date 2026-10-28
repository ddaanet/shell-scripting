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

The word-split is intended, so this line needs a `disable=SC2046` directive comment.

The signature symptom of the leak is `fatal: .git/index: index file open failed: Not a directory` — the inherited *relative* `GIT_INDEX_FILE=.git/index` resolving under a submodule's cwd, where `.git` is a gitfile rather than a directory. Note that a sandboxed environment can produce the same string for an unrelated reason, so confirm the env is actually leaking before fixing it as one.

The worst case is quieter than that error. In a **linked parent worktree** git exports an absolute `GIT_DIR` *and* `GIT_COMMON_DIR`; a hand-written unset that clears only the first lets `GIT_COMMON_DIR` silently redirect a submodule's refs and objects into the parent's common object store. A plain main-worktree commit does not export it, so a hand-picked unset list passes its tests and corrupts in production.

Three caveats:

- **Do not strip git's env for same-repo commands.** `GIT_INDEX_FILE` is how a commit hook reaches the index the commit is being built from, and which file that is depends on the commit mode (verified, git 2.47.3): plain `git commit` passes `.git/index`, `git commit -a` passes `.git/index.lock`, and `git commit -- <pathspec>` passes `.git/next-index-<pid>.lock`. Unsetting it does not silently mis-stage — in the plain case the variable already names the real index, and in the two lock modes a subsequent `git add` dies outright on `fatal: Unable to create '.git/index.lock': File exists`, because git is still holding that lock. Loud rather than silent, but it breaks the commit either way. Keep the unset scoped to a subshell around the other-repo command, as above.
- **A hook already built around a blanket unset that must stage a file itself** (no subshell around the whole body) captures `GIT_INDEX_FILE` first and restores it for that one `git add`. Without it the add dies in the `-a` and pathspec modes, as above, and blocks the commit under errexit.
  ```sh
  saved=${GIT_INDEX_FILE-}    # empty when the hook is run by hand, so never set -u bare
  # shellcheck disable=SC2046 # intended word-split
  unset $(git rev-parse --local-env-vars)
  …
  if [ -n "$saved" ]; then GIT_INDEX_FILE=$saved git add -- "$path"; else git add -- "$path"; fi
  ```
  Verified, git 2.47.3: restored, all three commit modes record the change. In pathspec mode (`git commit <path>`) the add lands in the temporary index, so it is in the commit but not the real one: a file the hook newly created then shows `D ` plus `??` afterwards, and a hook-modified tracked file shows ` M`. That is git's partial-commit behaviour, not a recipe fault. The restored value is relative in plain mode, so it only resolves from the hook's starting cwd.
- The unset list does not include `GIT_AUTHOR_NAME/EMAIL/DATE` — a hook committing in another repo silently reuses the original commit's author identity and pinned date unless those are unset too.

Under inherited `GIT_DIR` (without `GIT_WORK_TREE`), repository discovery is off and **the current directory is assumed to be the worktree root** — `git rev-parse --show-toplevel` reports the cwd, wherever that is.

### Testing a hook that touches the index

Running `bash hooks/pre-commit` from a shell exports none of the leaked variables and never exercises the index handoff, so a staging bug leaves the suite green while production fails. Two tests catch it: (1) run the hook with the leaked environment exported (`GIT_DIR`, `GIT_INDEX_FILE`, `GIT_WORK_TREE`, plus a bogus `GIT_COMMON_DIR` and `GIT_OBJECT_DIRECTORY`) and assert exit 0, no `index file open failed`, and no refs in the bogus common dir; (2) drive a real `git commit` in each of the three modes (plain, `-a`, pathspec) and assert the staged change is in the commit.

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

The damage outlives the command: `git -C sub rev-parse HEAD` returns the *parent's* HEAD, and staging that as the submodule's gitlink writes a 160000 entry pointing at a commit the submodule does not contain — a superproject that no longer clones. A stray `git branch <name>` lands in the parent the same way.

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

The rest of this section was verified empirically 2026-07-20 and 2026-08-12 (git 2.x, Linux).

**Which queries are silent on their normal-absence path** (non-zero exit, nothing on stderr). A `2>/dev/null` on one of these can only ever hide a real fault, so delete it: `git config --get <missing-key>`, `git config --file <missing-file> <key>`, `git config --get-regexp` with no match, `git check-ignore -q`, `git symbolic-ref --short -q HEAD` when detached, `git rev-parse -q --verify <missing-ref>`, and `git rev-parse --show-superproject-working-tree` (which exits 0 with empty output). The genuinely noisy ones, where an expected `fatal:` is the reason a suppression gets written: `git rev-parse --show-toplevel` and `git symbolic-ref` run **outside a repo**.

**Discriminating a push rejection.** The parenthesized reason separates the classes, and the leading marker differs too:

- non-fast-forward → `! [rejected]        HEAD -> live (fetch first)` or `(non-fast-forward)`
- policy → `! [remote rejected] HEAD -> live (pre-receive hook declined)`

"Updates were rejected" appears only on `hint:` lines and its wording varies, so it is not a reliable key. The parenthesized text is git's UI rather than a documented contract, so pin it with a test that provokes each class against a real git — a stale-ref push, a known-diverged push, a local `push .`, an ff-only fetch, a `pre-receive` decline — and let drift fail there rather than in the field.

**A non-fast-forward reason does NOT mean divergence.** git emits the same `(fetch first)` / `(non-fast-forward)` for a ref that is merely **behind** its target as for one that has genuinely diverged. Only the hint prose below differs ("the tip of your current branch is behind its remote counterpart" versus "the remote contains work that you do not have"), and that is advice text, disableable. The reason answers "could this fast-forward?", never "is there something to merge?" — ancestry answers that: run `git merge-base --is-ancestor` in each direction. Pushed ⊆ target is *behind* (nothing of ours to publish); target ⊆ pushed means the refusal was not about ancestry at all (a stale target ref, or the remote moved). Neither is divergence. Routing a merely-behind ref into a merge ends in a merge preparation that finds nothing — and if the preparation detaches onto the authority before discovering that, a failed diagnosis has silently moved the ref it was diagnosing. A test for this must assert the resulting **commit**, not a clean `git status`: the worktree is clean either way, so status is not evidence.

**`-q` is asymmetric between push and fetch.** `git push -q` still reports its rejection reason; **`git fetch -q` prints nothing at all on a non-fast-forward** and only exits 1. Any site that *classifies* a fetch rejection must therefore run without `-q`, capturing stdout and stderr. This has shipped as a live bug where a divergence branch was unreachable and a diverged remote was reported as merely stale — and it survived a suite that already covered ff-only rejection, because the test issued its own `git fetch` **without** `-q`. The invocation was the bug, not the logic: a test that constructs its own call does not exercise the one production uses.

**Whitespace-safe enumeration:** `git config -z --get-regexp <re>` emits one NUL-terminated `key\nvalue` record per match, so `${rec#*$'\n'}` recovers a value containing spaces. Splitting the non-`-z` output on whitespace is broken — for a submodule *named* with a space it yields part of the key.

**`--git-common-dir` is RELATIVE (`.git`) in a main worktree** and absolute in a linked one. With an exported CDPATH, `cd "$(git rev-parse --git-common-dir)"` therefore resolves against CDPATH *and* makes `cd` echo the destination, so the command substitution captures a two-line, wrong path. Always `CDPATH='' cd -- "$(…)"`. The same trap applies to `git -C <dir> rev-parse --git-path <name>`: it is relative to `<dir>` for a plain repo (`.git/<name>`), and absolute only when `<dir>` is a gitfile submodule — so a caller whose cwd is not `<dir>` creates the file in the wrong place. Use `--absolute-git-dir` and append.

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
- **fd 0 under the Bash tool is neither a hook's pipe nor a terminal, and its type is unspecified.** Observed in one session: `/dev/null` for most calls, a socket for others (a fifo only when you pipe in). `bats` inherits whichever it got. On `/dev/null` a read gets EOF at once, so `[ -t 0 ] || payload=$(cat)` takes its stdin branch with an empty payload; on the socket the read blocks and hangs the test. A test therefore gives its subject the stdin production gives it, explicitly — `printf '%s' "$json" |` for a hook payload, `</dev/null` for a git hook such as pre-commit — and never branches on `[ -p /dev/stdin ]` or `[ -c /dev/stdin ]` of the inherited fd.
- **`CLAUDE_PLUGIN_ROOT` is documented for hooks, not for Bash tool commands.** Plugin scripts that may be invoked both ways must self-locate as a fallback:
  ```sh
  PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
  ```
- **Hook stdout/stderr channels** (hooks reference): exit 0 stdout is parsed as JSON / transcript-only; exit 2 stderr is fed back to the model; `systemMessage` in JSON output is the user-visible channel. Don't print user-facing messages to channels the user never sees. Hook input JSON carries `session_id`, `cwd`, `hook_event_name`, and event-specific fields like `tool_input.file_path`.
- **Environment freezes at launch** (observed behavior; not in the docs). A session's `PATH`, `CLAUDE_PROJECT_DIR`, and settings-derived values are captured at startup; in-process directory moves (worktree tools) change `cwd` but not that environment. Hook scripts comparing "where am I" against launch-time variables must expect them to diverge. (`SessionStart`-family hooks can persist env via `$CLAUDE_ENV_FILE`.)

## Self-location and cwd discipline

- `self=$(cd "$(dirname "$0")" && pwd)` — works for executed scripts; for *sourced* bash files use `${BASH_SOURCE[0]}` (`$0` is the caller).
- Use `pwd -P` when `self` is compared against anything else (a PATH entry, `--show-toplevel`): `pwd` and `$PWD` keep symlinks, while `git rev-parse --show-toplevel` reports the resolved path — a second place its answer surprises, next to the inherited-`GIT_DIR` note above.
- **A wrapper that strips its own directory from `PATH` and `exec`s the next match must resolve each entry, never match spellings.** `PATH` entries built from `$TMPDIR` (`…//`, symlinked) miss a string-compared strip, `command -v` finds the wrapper again, and the `exec` re-enters it: an infinite loop, not a failure (a whole suite stops with no output). Verified, shellcheck-clean:
  ```sh
  self=$(CDPATH='' cd -- "$(dirname "$0")" && pwd -P)
  newpath=; oldifs=$IFS; IFS=:
  for d in $PATH; do
    d=${d:-.}   # an empty entry means the cwd
    if [ -d "$d" ]; then n=$(CDPATH='' cd -- "$d" 2>/dev/null && pwd -P) || n=$d; else n=$d; fi
    [ "$n" = "$self" ] || newpath="${newpath:+$newpath:}$d"
  done
  IFS=$oldifs
  ```
  This covers a trailing slash, `//`, `..`, a symlinked duplicate, an empty middle entry (`::`) and an entry that cannot be entered, which stays on `PATH` unresolved, in one pass (wrap the loop in `set -f` if entries may contain glob characters). A trailing empty entry (`PATH=/a:`) is dropped by the field split, so the cwd is no longer searched through it; a leading or middle one yields an empty field, which `d=${d:-.}` keeps on `PATH` as `.`. `CDPATH=''` keeps `cd` from printing and from resolving a relative entry elsewhere. A second physical copy of the wrapper elsewhere on `PATH` stays uncovered. Reproduce on Linux: put the wrapper's directory on `PATH` with a doubled slash and run under `timeout`; a hang exits 124.
- `unset CDPATH` near the top of any script using `cd` — a user's CDPATH makes `cd` print to stdout (corrupting `$(cd … && pwd)` captures) and possibly go elsewhere. ShellCheck flags unguarded `cd` (SC2164) but not CDPATH output pollution.
- Scripts emitted for *other* processes to run (directives, sub-agent instructions) must be cwd-independent: absolute paths and explicit `cd`, never reliance on the consumer's working directory.
