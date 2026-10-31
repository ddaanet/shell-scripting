# Claude Code: Hooks, Bash Tool, Sandbox

These apply to scripts run by Claude Code (hooks, install scripts, Bash tool
commands). Verified against the
[hooks reference](https://code.claude.com/docs/en/hooks.md) and
[sandboxing docs](https://code.claude.com/docs/en/sandboxing.md).

- **Sandboxed writes fail mid-run.** The command sandbox allows writes only to
  the working directory and the session temp directory; anything else gets a raw
  `Permission denied`, potentially leaving partial state. Scripts that write
  outside the CWD (git common dir, `$HOME`) should probe writability *up front*
  and fail with the exact re-run instruction, rather than dying halfway:
  ```sh
  probe="$target_dir/.probe.$$"
  if ! ( : > "$probe" ) 2>/dev/null; then
    echo "cannot write to $target_dir — sandbox? re-run with sandbox disabled" >&2
    exit 3
  fi
  rm -f "$probe"
  ```
- **Use `$TMPDIR`, not `/tmp`.** Claude Code points `TMPDIR` at the session's
  writable temp directory for sandboxed commands; hardcoded `/tmp` paths may be
  blocked.
- **fd 0 under the Bash tool is neither a hook's pipe nor a terminal, and its
  type is unspecified.** Observed in one session: `/dev/null` for most calls, a
  socket for others (a fifo only when you pipe in). `bats` inherits whichever it
  got. On `/dev/null` a read gets EOF at once, so `[ -t 0 ] || payload=$(cat)`
  takes its stdin branch with an empty payload; on the socket the read blocks
  and hangs the test. A test therefore gives its subject the stdin production
  gives it, explicitly — `printf '%s' "$json" |` for a hook payload,
  `</dev/null` for a git hook such as pre-commit — and never branches on
  `[ -p /dev/stdin ]` or `[ -c /dev/stdin ]` of the inherited fd.
- **`CLAUDE_PLUGIN_ROOT` is documented for hooks, not for Bash tool commands.**
  Plugin scripts that may be invoked both ways must self-locate as a fallback:
  ```sh
  PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
  ```
- **Hook stdout/stderr channels** (hooks reference): exit 0 stdout is parsed as
  JSON / transcript-only; exit 2 stderr is fed back to the model;
  `systemMessage` in JSON output is the user-visible channel. Don't print
  user-facing messages to channels the user never sees. Hook input JSON carries
  `session_id`, `cwd`, `hook_event_name`, and event-specific fields like
  `tool_input.file_path`.
- **Environment freezes at launch** (observed behavior; not in the docs). A
  session's `PATH`, `CLAUDE_PROJECT_DIR`, and settings-derived values are
  captured at startup; in-process directory moves (worktree tools) change `cwd`
  but not that environment. Hook scripts comparing "where am I" against
  launch-time variables must expect them to diverge. (`SessionStart`-family
  hooks can persist env via `$CLAUDE_ENV_FILE`.)
