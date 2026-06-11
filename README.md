# shell-scripting

Claude Code plugin: shell scripting gotchas knowledge plus automatic shellcheck feedback.

## Components

### Skill: `shell-gotchas`

Self-triggering skill that loads when Claude writes or edits shell scripts (`.sh`/`.bash` files, shebang lines, git hooks, bats tests, wrapper scripts, Makefile recipes). Covers what shellcheck cannot catch:

- **GNU vs BSD/macOS runtime divergence** (`paste`, `sed -i`, `date`, `stat`, bash 3.2 on macOS, …)
- **Robustness** — `set -e` blind spots, exit-status loss, quoting, filename safety, `read` discipline
- **Hostile environments** — git hook env leakage (`GIT_DIR`), submodule escape, linked worktrees, Claude Code sandbox specifics
- **The touched-line audit rule** — when editing existing scripts with portability requirements, review the whole script, not just the diff
- **Platform-simulation regression tests** — PATH-shadowing wrappers that make Linux CI catch macOS breakage

Detailed catalogs live in `skills/shell-gotchas/references/`.

### Hook: shellcheck on edit

A `PostToolUse` hook runs shellcheck on every shell file Claude writes or edits (detected by extension or shebang) and feeds findings back to Claude automatically. When `shellcheck` is not installed, the first shell-file edit of a session shows a one-time notice that lint feedback is inactive; missing `jq` disables the hook silently.

## Prerequisites

- `shellcheck` and `jq` on PATH for the hook (the skill works without them)

## Installation

Local testing:

```sh
claude --plugin-dir /path/to/shell-scripting
```

Or install via a marketplace entry pointing at this repository.

## Provenance

Built test-first: baseline subagent runs (without the skill) showed agents handle famous gotchas in greenfield code but ship latent GNU-isms when *editing* existing scripts, print success messages on failed paths, and lose exit statuses behind substitutions. The skill body targets those observed failures; the catalogs serve as lookup.

Content is research-grounded, not memory-derived: every claim was verified against primary sources (POSIX.1-2024, GNU/BSD man pages, bash NEWS, Greg's Wiki, githooks(5), Claude Code docs) or empirically (shellcheck 0.10.0, git 2.47), and the reference catalogs carry inline citations. The fact-check pass corrected the original improvised version in several places — including claims that shellcheck misses things it catches, and a suppression syntax that was itself a shellcheck parse error.
