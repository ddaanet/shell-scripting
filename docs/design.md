# shell-scripting Plugin — Design

Living design document. Present tense: it states what the plugin *is* and why it
has this shape. When a decision is overturned it is rewritten here in place —
never struck through, never annotated with "formerly". History is git's: the doc
keeps no changelog, and the why of a change lives in its commit body.

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
   path and does not duplicate them, and it triggers on the same edits, since
   test and recipe bodies are shell code.


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

Lint findings are fed to the model through the hook's
`hookSpecificOutput.additionalContext` (wrapped in a system reminder next to the
tool result, model-visible only), while the user sees only
`systemMessage: "shell lint: N findings"`; `suppressOutput` keeps the raw JSON
out of the transcript. The earlier design emitted findings via exit 2 + stderr,
but stderr is shown to *both* the model and the user's transcript — splitting
the channels keeps the verbose output where it is actionable (the model) and
spares the user a wall of text. Because the findings no longer reach the
transcript, the former 60-line cap is dropped and the model receives the
complete output. The missing-shellcheck notice keeps using `systemMessage` (with
a zero exit status), in the same message as the summary when both apply — the
user, not the model, is who can act on a missing system dependency.
(`additionalContext` and `systemMessage` carry the same way on `PostToolBatch`
as on the original `PostToolUse` event — see D8.)

**D4 — Interpreter allowlist for shebang sniffing**

Only sh/bash/dash/ksh shebangs are linted. A generic `*sh*` match was rejected:
it would route fish or zsh files to shellcheck, which cannot parse them and
would produce noise findings.

**D5 — One-time notice keyed by session marker in `$TMPDIR`**

Visible degradation (FR7) without nagging: a marker file named with the hook
payload's `session_id` suppresses repeats within a session. A missing jq stays
silent by construction — without jq the hook cannot parse the payload, so it
cannot even tell whether the edit touched a shell file.

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

`PostToolUse` fires once per tool call, so a batch of parallel `Write`/`Edit`
calls to one file produced one shellcheck report per call — duplicated noise to
the model, plus transient findings from intermediate states. `PostToolBatch`
fires exactly once per turn,
*after the whole batch resolves and before the next model call*, carrying every
call in a `tool_calls` array; the hook filters that array to `Write`/`Edit`,
dedupes the `file_path`s, and lints each file once on its final on-disk content.
So each file yields at most one report per batch (FR8), with no timing logic.

This supersedes an earlier debounce design (each `PostToolUse` invocation
claimed a per-file `$TMPDIR` marker, slept a window, and reported only if still
the marker owner). The debounce was rejected once `PostToolBatch` was confirmed:
it added per-edit latency, wrote per-file markers (against NFR4), and was a
heuristic (independent edits inside the window got coalesced). It existed only
because a stateless `PostToolUse` hook cannot see whether a later edit to the
same file is still coming — the "is more coming?" signal lives in the future.
`PostToolBatch` removes the need to guess: the platform hands the hook the
complete batch.

Two earlier rejected alternatives also fall away: content-hash dedup (an A→B→C
batch has three distinct hashes, so all three would still report) and scraping
the transcript (the JSONL writes each `tool_use` at dispatch time, interleaved
with its result — verified `tool_A`, `result_A`, `tool_B` ordering for one
shared `message.id` — so an early call's hook cannot see its later siblings).
The batch info exists only in CC's memory between "response received" and "next
model call," and `PostToolBatch` is the surface that exposes exactly that
window.

The contract was verified empirically (captured payload, 2026-06-30): top-level
keys
`session_id`/`transcript_path`/`cwd`/`permission_mode`/`prompt_id`/`effort`/`hook_event_name`/`tool_calls`;
each `tool_calls` entry has `tool_name`, `tool_input` (with `file_path` for
Write/Edit), `tool_use_id`, `tool_response`. `PostToolBatch` fires for
single-tool turns too (an `n=1` batch), so it fully replaces `PostToolUse`
rather than supplementing it. It has no matcher support, so the script
self-filters by `tool_name`; a read-only batch yields no Write/Edit paths and
exits silently.

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
(a recipe body, a `@test`). An edit to either therefore loads the general shell
skill and the sibling together, and `shell-gotchas` keeps a single line naming
both siblings by relative path. The siblings point into
`shell-gotchas/references/` only where a fact is shared
(`../shell-gotchas/references/claude-code.md` for the test-stdin fact,
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

macOS `/bin/bash` 3.2 runs some constructs without an error and with a wrong
result (`references/shell-versions.md`, `references/portability.md`); shellcheck
cannot flag them, and no Linux test reproduces them. The hook flags three, each
with a rewrite that preserves meaning:

- an unbraced `$name` immediately followed by a byte >= 0x80 (fix: `${name}`);
- `LC_ALL`, `LANG` or `LC_CTYPE` assigned as a command prefix, among other
  prefix assignments or not, in front of a bash builtin (fix:
  `$(LC_ALL=C; cmd ...)`, which can draw SC2030, or save, assign and restore).
  The prefix before an external command, a standalone assignment and `export`
  are fine. The builtin set is bash 5's `enable -a`, frozen in the script: a
  superset of 3.2's whose extras are harmless. The list is of builtins, not of
  the locale-sensitive ones, which is the list that would rot;
- `printf -v` with a format holding the `b` conversion, unless `||` or `&&`
  precedes it on the same line. `%s` formats are fine.

The lint is `hooks/scripts/bash32-lint.sh`, which the hook finds beside itself
with `$(dirname "$0")` and runs on the same file list as shellcheck. A separate
script lets the bats suite call it directly. It prints findings in shellcheck's
gcc shape with a `[bash32-N]` tag and always exits 0. It never decides whether a
file is shell; the hook already has.

No suppression comment exists: every pattern has an accepted rewrite, so a
finding is fixed rather than silenced. Matching is per line under `LC_ALL=C`,
with the high-byte test an explicit octal range, never a ctype class: macOS libc
classifies 0x80-0xFF as printable in a UTF-8 locale and glibc does not, so a
class would differ on the Mac where no Linux test sees it. The patterns are
written so the script and its tests do not match their own text.

The bash 3.2 pass runs with or without shellcheck. A missing shellcheck keeps
its one-time notice (D5) but no longer ends the run: the notice, the summary and
the findings share one `systemMessage` and one JSON object.

## Limitations

1. The hook only sees `Write`/`Edit` tool calls — shell emitted via Bash-tool
   heredocs, inline one-liners, and scripts created by other means are never
   linted.
2. Unusual interpreter paths evade the shebang allowlist; fish and zsh are out
   of scope (shellcheck cannot parse them).
3. Skill *triggering* is verified only by injection (subagents told to read the
   skill); organic trigger behavior in a fresh session with the plugin installed
   has not yet been observed.
4. The catalogs are curated, not exhaustive — shellcheck cannot model GNU/BSD
   divergence, so the portability table is the only guard for that class, and
   only for the commands it lists.
5. Notice markers accumulate in `$TMPDIR` (one per session) until OS cleanup.
6. Not yet published to a marketplace.
7. Verified facts are pinned to tool versions (shellcheck 0.10.0, git 2.47,
   POSIX.1-2024, June 2026); the shellcheck-coverage boundary in particular can
   drift as the linter gains checks.
8. `PostToolBatch`'s output channel (`additionalContext` → model,
   `systemMessage` → user) is taken from documentation and parity with the prior
   `PostToolUse` path; the input contract was captured empirically, but the
   model-facing delivery of `additionalContext` on `PostToolBatch` specifically
   was not round-trip-observed.
9. The own-repo staging recipe and the inherited `GIT_WORK_TREE=.` are probed on
   pre-commit, prepare-commit-msg, commit-msg and post-commit; hooks run by
   other commands are unprobed for them.
10. `rumdl fmt` leaves a line it cannot wrap (a code span containing `|`, a long
    URL) over 80 columns; the formatter check accepts it. The `-q --no-cache`
    flags and the exit codes are verified on rumdl 0.3.2.
11. The bash 3.2 lint matches lines, not syntax: quotes, comments and heredoc
    bodies are not parsed, so a matching line inside one is flagged, and a
    prefix assignment split across words by quoting (`FOO="a b" LC_ALL=C cmd`)
    is missed. Behaviour on 3.2 itself is not observable in the suite; the tests
    pin the patterns only.
