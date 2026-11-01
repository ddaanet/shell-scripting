# shell-scripting Plugin — Design

Living design document. Present tense: it states what the plugin *is* and why it
has this shape. When a decision is overturned it is rewritten here in place —
never struck through, never annotated with "formerly". History is git's: the doc
keeps no changelog, and the why of a change lives in its commit body.

This document is a hub; `docs/references/` holds one node per mechanism. Read
the node before making a claim about, or changing, the mechanism it argues:
[hook.md](references/hook.md) for the `PostToolBatch` hook (D3, D4, D5, D8,
D11).

## Functional Requirements

1. A self-triggering skill (`shell-gotchas`) loads whenever Claude writes,
   edits, reviews, or debugs shell code — `.sh`/`.bash` files, shebang lines,
   git hooks, `.bats` tests, wrapper scripts, Makefile and `just` recipes, CI
   run steps.
2. The skill covers what shellcheck cannot detect: GNU vs BSD/macOS runtime
   divergence, `set -e` blind spots and exit-status loss, environment leakage
   (git hooks, submodules, worktrees, Claude Code sandbox), and error-path
   honesty. The mechanical class (quoting, word splitting, bashisms) is
   delegated to shellcheck.
3. The skill mandates whole-script audit when editing existing scripts with
   portability requirements: the diff is not the unit of review.
4. The skill documents the platform-simulation regression-test pattern
   (PATH-shadowing wrapper enforcing the stricter platform's behavior) so
   portability fixes get locked in on Linux CI.
5. A `PostToolBatch` hook runs shellcheck and the bash 3.2 lint (D11) on every
   shell file a tool batch wrote or edited and feeds findings back to the model
   automatically, independent of whether the skill triggered.
6. The hook detects shell files by extension (`.sh`, `.bash`, `.bats`) or
   shebang sniff (sh/bash/dash/ksh/bats, with or without interpreter options).
7. Graceful degradation: when shellcheck is missing, the first batch that
   touches a shell file in a session emits a one-time user-visible notice that
   shellcheck feedback is inactive, and the bash 3.2 lint still runs and
   reports; when jq is missing, the hook is silently inert.
8. Each shell file is linted at most once per batch: when a batch lands several
   `Write`/`Edit` calls to the same file (parallel or not), only its final
   settled state is reported — intermediate states do not each produce a
   separate report.
9. Two sibling self-triggering skills cover the harnesses around shell code:
   `bats-gotchas` loads when Claude writes, edits, reviews, or debugs `.bats`
   files or bats tests, and `just-gotchas` loads for justfiles and `just`
   recipes. Each carries its own catalog; `shell-gotchas` names them by relative
   path and does not duplicate them, and each sibling's body sends the reader to
   `shell-gotchas`, since test and recipe bodies are shell code.


## Non-Functional Requirements

1. **Progressive disclosure.** `shell-gotchas/SKILL.md` stays lean (≈1100 words:
   rules, quick-reference table, exit checklist); its full catalogs live in
   `references/` (`portability.md`, `shell-versions.md`, `robustness.md`,
   `environments.md`, `claude-code.md`) and load only on demand.
   `just-gotchas/SKILL.md` is its catalog, sized to the
   `plugin-dev:skill-development` guidance (body 1,500–2,000 words ideal, under
   3,000) and to the 10000-byte hub cap. `bats-gotchas/SKILL.md` is a hub in the
   same shape as `shell-gotchas`: one table of traps, each row carrying its fix,
   with the explanations in `bats-gotchas/references/` (`vacuous-passes.md`,
   `run-semantics.md`, `linting.md`). A catalog that outgrows the cap takes the
   same shape. Every skill `description` is loaded in every session, so each
   stays short.
2. **Self-application.** The plugin's own shell code follows the skill's rules:
   POSIX `#!/bin/sh`, shellcheck-clean, `printf` for data, BSD-safe invocations.
3. **Quiet by default.** The hook is silent on non-shell files, clean files, and
   missing tools (except FR7's one-time notice); on findings the user's
   transcript shows only a one-line `shell lint: N findings` summary, while the
   full output goes to the model out of band.
4. **Minimal footprint.** The hook writes nothing except the per-session
   missing-shellcheck notice marker in `$TMPDIR`; no network, no repo writes.
5. **Portable installation.** All intra-plugin paths go through
   `${CLAUDE_PLUGIN_ROOT}`.
6. **Honest size.** Markdown prose is hard-wrapped at 80 columns, and no file
   outgrows a single read. `just precommit` fails when `rumdl fmt --check` would
   change a file, and when the toolkit's `check-size` (a dependency of
   `precommit`, beside `check-refs`) finds a file over its byte cap: 20000
   bytes, 10000 for a `SKILL.md` at any depth. `check-size` reads every file git
   does not ignore, tracked or not, from disk. It reads only regular files, so a
   submodule such as `memory/` is not checked: git lists it as one gitlink, and
   the check skips that. It also skips symlinks, unreadable and binary files,
   `plugin-dev/`, a root `plans/`, and `uv.lock` or `package-lock.json`. The
   repository has no `size.exempt`. `rumdl` has its own exclusion list (D10).


## Design Decisions

**D1 — Shellcheck-first framing, not a self-contained catalog**

The skill is a thin layer over the linter: its body spends tokens only on what
static analysis cannot see, and rule 1 mandates running shellcheck rather than
duplicating its checks as prose. A self-contained catalog was rejected — it
would re-teach what tooling already enforces, bloat the always-loaded layer, and
drift as shellcheck evolves.

**D2 — Test-first authoring (writing-skills TDD)**

Baseline subagent runs *without* the skill preceded writing it. Key finding:
agents handle famous gotchas in greenfield code (one baseline unset `GIT_DIR`
and guarded an unchecked-out submodule unprompted) but ship latent GNU-isms when
*editing* existing scripts — a `paste -sd:` survived an edit pass despite an
explicit macOS requirement, reproducing the gitlore launcher-shim incident. The
skill body therefore leads with the whole-script audit rule and error-path
honesty rather than the famous-gotcha list. GREEN runs confirmed the same
scenarios pass with the skill loaded.

**D3 — Findings split across channels: full output to the model via
`additionalContext`, a one-line summary to the user via `systemMessage`**

Lint findings go to the model through `hookSpecificOutput.additionalContext`,
and the user sees only the one-line `systemMessage` summary
([hook.md](references/hook.md)).

**D4 — Interpreter allowlist for shebang sniffing**

Only sh/bash/dash/ksh/bats shebangs are linted ([hook.md](references/hook.md)).

**D5 — One-time notice keyed by session marker in `$TMPDIR`**

A marker file named with the hook payload's `session_id` suppresses the
missing-shellcheck notice after its first showing in a session
([hook.md](references/hook.md)).

**D6 — CC-specific content included**

`references/claude-code.md` covers Claude Code sandbox probing, `$TMPDIR`,
`CLAUDE_PLUGIN_ROOT` self-location, and launch-env freeze. This reduces
shareability outside CC but matches the plugin's actual habitat; chosen
explicitly over a generic-only scope.

**D7 — Research-grounded content: every claim cited or empirically verified**

The 2026-06-11 research pass replaced memory-derived content with claims
verified against primary sources (POSIX.1-2024, GNU/BSD man pages, bash NEWS,
Greg's Wiki BashPitfalls, githooks(5), Claude Code docs) or empirical repros
(shellcheck 0.10.0, git 2.47). Reference files carry inline citations; the
shellcheck-coverage boundary was mapped empirically per table row, so the skill
no longer claims the linter misses things it catches (SC2155, SC2030/31, SC2070,
SC2164). Citations date-stamp the facts: shellcheck and POSIX evolve, and a
future re-verification pass has concrete sources to diff against.

**D8 — Per-batch coalescing via the `PostToolBatch` event, not a debounce**

`PostToolBatch` fires once per turn, after the whole batch resolves, so the hook
lints each file once on its final on-disk state, with no debounce
([hook.md](references/hook.md)).

**D9 — Bats and just are sibling skills, not references of `shell-gotchas`**

A `references/` node of `shell-gotchas` was rejected for the bats and just
catalogs. Their trigger conditions are mechanical and distinct — a `.bats` file,
a justfile — so each is a skill of its own: editing one loads its catalog
directly, with no hop through the shell hub, and a bats session does not pay for
just content or the reverse. The cost is two more `description` lines in every
session's skill listing, so each sibling description is one clause on what the
skill is plus the concrete triggers, kept under about 60 words. `shell-gotchas`'
description is longer by design: it carries the main trigger surface, and it
also names `.bats` tests and `just` recipes, because shell code sits inside them
(a recipe body, a `@test`). `shell-gotchas` keeps a single line naming both
siblings by relative path. The descriptions alone load only the sibling on a
bats or just task (one run each, CC 2.1.316, Opus 5.5), so each sibling's body
opens by telling the reader to also invoke `shell-scripting:shell-gotchas`,
since shell code sits in test and recipe bodies. That costs a bats or just
session the shell hub's body, once per session. The pointer names the skill
rather than a relative path because in a headless probe (`acceptEdits`, fresh
directory, CC 2.1.316) a Read under the plugin cache was refused while the
`Skill` tool succeeded. The refused Reads included a skill's own `references/`
file, so the links kept as paths carry the same exposure; a reference node has
no other route, since the `Skill` tool loads only a `SKILL.md` body. The cost is
that a plugin rename means editing both lines, and `check-refs` does not see
them. The siblings point into `shell-gotchas/references/` only where a fact is
shared (`../shell-gotchas/references/claude-code.md` for the test-stdin fact,
`portability.md` for the GNU-only spelling a PATH stub never shadows, and
`robustness.md`, from `bats-gotchas/references/run-semantics.md`, for the
discarded status of a command substitution used as an argument). The
platform-simulation template (FR4) lives in `references/portability.md` under
"Locking fixes in", beside the divergences it locks in, rather than in
`shell-gotchas/SKILL.md`; this keeps the hub to rules, the table and the
checklist.

**D10 — A read-only formatter check in the commit gate, with `rumdl` from
`uv sync`**

Markdown is kept hard-wrapped at 80 columns so diffs and reviews work on
line-sized units. The gate runs `rumdl fmt --check -q --no-cache .`. The size
cap is separate: the toolkit's `check-size` counts bytes, which move little when
text is re-wrapped, so it does not depend on the formatter. Each choice has a
reason:

- `fmt --check`, not `rumdl check`: `check` reports a line it cannot wrap (a
  long code span, a URL) on every run, so it is permanently red, while
  `fmt --check` exits 0 once `fmt` has done what it can. It is read-only like
  every other `precommit` step. A rewriting `fmt` inside the recipe was
  rejected: it leaves unstaged changes after the gate passes, so a commit of the
  staged files ships text the gate never saw.
- `reflow-mode = "normalize"`: the default only breaks over-long lines and never
  converges widths. Normalize re-fills every paragraph, so wrapping is uniform,
  at the cost that a hand-wrapped paragraph fails the check until
  `rumdl fmt --no-cache` is run.
- Code blocks, tables and headings are not wrapped (`code-blocks`, `tables`,
  `headings = false`). A line over 80 columns inside one, like an unbreakable
  token in prose, stays long.
- The `.rumdl.toml` `exclude` list is the formatter's own: `plans/`, `inbox/`,
  `memory/`, `plugin-dev/`, `.claude/` and the task files are not documentation
  a reader takes in. The size check keeps no list of its own beyond the
  toolkit's built-ins (NFR6), so it does read `inbox/`. The built copy under
  `dist/plugin/` is skipped by both through `.gitignore`.
- `rumdl` and PyYAML are the `dev` dependency group of `pyproject.toml`,
  resolved into the committed `uv.lock` by `uv sync` and put on `PATH` by
  `.envrc`; `uv run` is not used. PyYAML is in the group because the venv's
  `python3` shadows the system one, and `scripts/check-frontmatter.py` imports
  it. `rumdl>=0.3.2` is the version floor. A missing `rumdl` fails `precommit`
  with a message naming `uv sync` and `direnv allow`, rather than skipping.

A file that crosses its byte cap is split in its own commit, carrying only the
move and the inbound-citation updates it forces.

**D11 — The bash 3.2 lint is a sibling script the hook calls, with three
line-level patterns and no suppression comment**

The lint is `hooks/scripts/bash32-lint.sh`, which the hook calls on the same
file list as shellcheck; it flags three line-level patterns and has no
suppression comment ([hook.md](references/hook.md)).

## Limitations

1. The hook only sees `Write`/`Edit` tool calls — shell emitted via Bash-tool
   heredocs, inline one-liners, and scripts created by other means are never
   linted.
2. Unusual interpreter paths evade the shebang allowlist; fish and zsh are out
   of scope (shellcheck cannot parse them).
3. Skill triggering is observed only in a few headless sessions in a fresh
   directory (CC 2.1.316, Opus 5.5): a portable sh script loads `shell-gotchas`,
   a bats or just task loads its sibling first, and a Python script loads none.
   A sibling's pointer to `shell-gotchas` is not always followed: a run can
   write the files without it. Interactive sessions are not observed.
4. The catalogs are curated, not exhaustive — shellcheck cannot model GNU/BSD
   divergence, so the portability table is the only guard for that class, and
   only for the commands it lists.
5. Notice markers accumulate in `$TMPDIR` (one per session) until OS cleanup.
6. Retired.
7. Verified facts are pinned to tool versions (shellcheck 0.10.0, git 2.47,
   POSIX.1-2024, June 2026); the shellcheck-coverage boundary in particular can
   drift as the linter gains checks.
8. `PostToolBatch`'s output channel (`additionalContext` → model,
   `systemMessage` → user) is taken from documentation and parity with the prior
   `PostToolUse` path, not round-trip-observed ([hook.md](references/hook.md)).
9. The own-repo staging recipe and the inherited `GIT_WORK_TREE=.` are probed on
   pre-commit, prepare-commit-msg, commit-msg and post-commit; hooks run by
   other commands are unprobed for them.
10. `rumdl fmt` leaves a line it cannot wrap (a code span containing `|`, a long
    URL) over 80 columns; the formatter check accepts it. The `-q --no-cache`
    flags and the exit codes are verified on rumdl 0.3.2.
11. The bash 3.2 lint matches lines, not syntax: quotes, comments and heredoc
    bodies are not parsed ([hook.md](references/hook.md)).
