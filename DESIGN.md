# shell-scripting Plugin Design Document

Living document. Requirements and decisions are numbered for reference; the history table records changes as they land.

## Functional Requirements

1. A self-triggering skill (`shell-gotchas`) loads whenever Claude writes, edits, reviews, or debugs shell code — `.sh`/`.bash` files, shebang lines, git hooks, bats tests, wrapper scripts, Makefile recipes, CI run steps.
2. The skill covers what shellcheck cannot detect: GNU vs BSD/macOS runtime divergence, `set -e` blind spots and exit-status loss, environment leakage (git hooks, submodules, worktrees, Claude Code sandbox), and error-path honesty. The mechanical class (quoting, word splitting, bashisms) is delegated to shellcheck.
3. The skill mandates whole-script audit when editing existing scripts with portability requirements: the diff is not the unit of review.
4. The skill documents the platform-simulation regression-test pattern (PATH-shadowing wrapper enforcing the stricter platform's behavior) so portability fixes get locked in on Linux CI.
5. A `PostToolBatch` hook runs shellcheck on every shell file a tool batch wrote or edited and feeds findings back to the model automatically, independent of whether the skill triggered.
6. The hook detects shell files by extension (`.sh`, `.bash`, `.bats`) or shebang sniff (sh/bash/dash/ksh/bats, with or without interpreter options).
7. Graceful degradation: when shellcheck is missing, the first batch that touches a shell file in a session emits a one-time user-visible notice that lint feedback is inactive; when jq is missing, the hook is silently inert.
8. Each shell file is linted at most once per batch: when a batch lands several `Write`/`Edit` calls to the same file (parallel or not), only its final settled state is reported — intermediate states do not each produce a separate report.

## Non-Functional Requirements

1. **Progressive disclosure.** SKILL.md stays lean (≈1100 words: rules, quick-reference table, test pattern, exit checklist); full catalogs live in `references/` (`portability.md`, `robustness.md`, `environments.md`) and load only on demand.
2. **Self-application.** The plugin's own shell code follows the skill's rules: POSIX `#!/bin/sh`, shellcheck-clean, `printf` for data, BSD-safe invocations.
3. **Quiet by default.** The hook is silent on non-shell files, clean files, and missing tools (except FR7's one-time notice); on findings the user's transcript shows only a one-line `shellcheck failed (N lines)` summary, while the full output goes to the model out of band.
4. **Minimal footprint.** The hook writes nothing except the per-session missing-shellcheck notice marker in `$TMPDIR`; no network, no repo writes.
5. **Portable installation.** All intra-plugin paths go through `${CLAUDE_PLUGIN_ROOT}`.

## Design Decisions

**D1 — Shellcheck-first framing, not a self-contained catalog**

The skill is a thin layer over the linter: its body spends tokens only on what static analysis cannot see, and rule 1 mandates running shellcheck rather than duplicating its checks as prose. A self-contained catalog was rejected — it would re-teach what tooling already enforces, bloat the always-loaded layer, and drift as shellcheck evolves.

**D2 — Test-first authoring (writing-skills TDD)**

Baseline subagent runs *without* the skill preceded writing it. Key finding: agents handle famous gotchas in greenfield code (one baseline unset `GIT_DIR` and guarded an unchecked-out submodule unprompted) but ship latent GNU-isms when *editing* existing scripts — a `paste -sd:` survived an edit pass despite an explicit macOS requirement, reproducing the gitlore launcher-shim incident. The skill body therefore leads with the whole-script audit rule and error-path honesty rather than the famous-gotcha list. GREEN runs confirmed the same scenarios pass with the skill loaded.

**D3 — Findings split across channels: full output to the model via `additionalContext`, a one-line summary to the user via `systemMessage`**

Lint findings are fed to the model through the hook's `hookSpecificOutput.additionalContext` (wrapped in a system reminder next to the tool result, model-visible only), while the user sees only `systemMessage: "shellcheck failed (N lines)"`; `suppressOutput` keeps the raw JSON out of the transcript. The earlier design emitted findings via exit 2 + stderr, but stderr is shown to *both* the model and the user's transcript — splitting the channels keeps the verbose output where it is actionable (the model) and spares the user a wall of text. Because the findings no longer reach the transcript, the former 60-line cap is dropped and the model receives the complete output. The missing-shellcheck notice keeps using `systemMessage` (exit 0) — the user, not the model, is who can act on a missing system dependency. (`additionalContext` and `systemMessage` carry the same way on `PostToolBatch` as on the original `PostToolUse` event — see D8.)

**D4 — Interpreter allowlist for shebang sniffing**

Only sh/bash/dash/ksh shebangs are linted. A generic `*sh*` match was rejected: it would route fish or zsh files to shellcheck, which cannot parse them and would produce noise findings.

**D5 — One-time notice keyed by session marker in `$TMPDIR`**

Visible degradation (FR7) without nagging: a marker file named with the hook payload's `session_id` suppresses repeats within a session. A missing jq stays silent by construction — without jq the hook cannot parse the payload, so it cannot even tell whether the edit touched a shell file.

**D7 — Research-grounded content: every claim cited or empirically verified**

The 2026-06-11 research pass replaced memory-derived content with claims verified against primary sources (POSIX.1-2024, GNU/BSD man pages, bash NEWS, Greg's Wiki BashPitfalls, githooks(5), Claude Code docs) or empirical repros (shellcheck 0.10.0, git 2.47). Reference files carry inline citations; the shellcheck-coverage boundary was mapped empirically per table row, so the skill no longer claims the linter misses things it catches (SC2155, SC2030/31, SC2070, SC2164). Citations date-stamp the facts: shellcheck and POSIX evolve, and a future re-verification pass has concrete sources to diff against.

**D8 — Per-batch coalescing via the `PostToolBatch` event, not a debounce**

`PostToolUse` fires once per tool call, so a batch of parallel `Write`/`Edit` calls to one file produced one shellcheck report per call — duplicated noise to the model, plus transient findings from intermediate states. `PostToolBatch` fires exactly once per turn, *after the whole batch resolves and before the next model call*, carrying every call in a `tool_calls` array; the hook filters that array to `Write`/`Edit`, dedupes the `file_path`s, and lints each file once on its final on-disk content. So each file yields at most one report per batch (FR8), with no timing logic.

This supersedes an earlier debounce design (each `PostToolUse` invocation claimed a per-file `$TMPDIR` marker, slept a window, and reported only if still the marker owner). The debounce was rejected once `PostToolBatch` was confirmed: it added per-edit latency, wrote per-file markers (against NFR4), and was a heuristic (independent edits inside the window got coalesced). It existed only because a stateless `PostToolUse` hook cannot see whether a later edit to the same file is still coming — the "is more coming?" signal lives in the future. `PostToolBatch` removes the need to guess: the platform hands the hook the complete batch.

Two earlier rejected alternatives also fall away: content-hash dedup (an A→B→C batch has three distinct hashes, so all three would still report) and scraping the transcript (the JSONL writes each `tool_use` at dispatch time, interleaved with its result — verified `tool_A`, `result_A`, `tool_B` ordering for one shared `message.id` — so an early call's hook cannot see its later siblings). The batch info exists only in CC's memory between "response received" and "next model call," and `PostToolBatch` is the surface that exposes exactly that window.

The contract was verified empirically (captured payload, 2026-06-30): top-level keys `session_id`/`transcript_path`/`cwd`/`permission_mode`/`prompt_id`/`effort`/`hook_event_name`/`tool_calls`; each `tool_calls` entry has `tool_name`, `tool_input` (with `file_path` for Write/Edit), `tool_use_id`, `tool_response`. `PostToolBatch` fires for single-tool turns too (an `n=1` batch), so it fully replaces `PostToolUse` rather than supplementing it. It has no matcher support, so the script self-filters by `tool_name`; a read-only batch yields no Write/Edit paths and exits silently.

**D6 — CC-specific content included**

`references/environments.md` covers Claude Code sandbox probing, `$TMPDIR`, `CLAUDE_PLUGIN_ROOT` self-location, and launch-env freeze. This reduces shareability outside CC but matches the plugin's actual habitat; chosen explicitly over a generic-only scope.

## Limitations

1. The hook only sees `Write`/`Edit` tool calls — shell emitted via Bash-tool heredocs, inline one-liners, and scripts created by other means are never linted.
2. Unusual interpreter paths evade the shebang allowlist; fish and zsh are out of scope (shellcheck cannot parse them).
3. Skill *triggering* is verified only by injection (subagents told to read the skill); organic trigger behavior in a fresh session with the plugin installed has not yet been observed.
4. The catalogs are curated, not exhaustive — shellcheck cannot model GNU/BSD divergence, so the portability table is the only guard for that class, and only for the commands it lists.
7. Verified facts are pinned to tool versions (shellcheck 0.10.0, git 2.47, POSIX.1-2024, June 2026); the shellcheck-coverage boundary in particular can drift as the linter gains checks.
5. Notice markers accumulate in `$TMPDIR` (one per session) until OS cleanup.
6. No LICENSE; not yet published to a marketplace.
8. `PostToolBatch`'s output channel (`additionalContext` → model, `systemMessage` → user) is taken from documentation and parity with the prior `PostToolUse` path; the input contract was captured empirically, but the model-facing delivery of `additionalContext` on `PostToolBatch` specifically was not round-trip-observed.

## History

| Date | Change |
|------|--------|
| 2026-06-30 | **New gotcha: needless `2>/dev/null` hides real errors.** Added a table row (`SKILL.md`) and a fuller bullet (`references/robustness.md`, "Honest reporting") warning that blanket `2>/dev/null` discards *every* stderr line a command can produce, not just the one expected message — masking permission errors, disk-full, typo'd flags. Recommends testing the condition explicitly or scoping suppression narrowly with a comment. No shellcheck coverage (it never flags stderr redirection), consistent with D1's framing. |
| 2026-06-30 | **Hook moved from `PostToolUse` to `PostToolBatch`; each file linted once per batch (FR5, FR8, D8).** `PostToolUse` fires per tool call, so parallel `Write`/`Edit` calls to one file produced a report per call. The hook now binds `PostToolBatch` (fires once per turn after the whole batch resolves), reads the `tool_calls` array, filters to Write/Edit, dedupes `file_path`s, and shellchecks each shell file once on its final state — `-f gcc` output across files self-identifies by path. A briefly-staged `PostToolUse` debounce (per-file `$TMPDIR` marker + `sleep`) was abandoned before landing: `PostToolBatch` supplies the full batch directly, with no latency, no markers (NFR4 restored), and no heuristic window. Contract verified by capturing a real payload (keys incl. `tool_calls[].{tool_name,tool_input,tool_use_id,tool_response}`; fires for `n=1` turns too, so it fully replaces `PostToolUse`). Rewrote D8, D3 (event-agnostic wording), FR5/7/8, NFR4; new limitation 8 (output channel parity documented, not round-trip-observed). Re-linted clean (SC2015 caught and fixed in the file-collection loop); exercised same-file 3× batch (1 report), multi-file batch (per-path findings), read-only and non-shell batches (silent), singleton (reports). |
| 2026-06-30 | **Lint invocation gains `-x` (follow external sources).** `shellcheck -f gcc` → `shellcheck -x -f gcc`. With `-x` (`--external-sources`) shellcheck follows `source`/`.` directives into the sourced files and checks them in context, instead of emitting SC1091 "not following: file not found" for every helper a script pulls in. Scoped to files resolvable relative to the script and the working directory — no config, no extra writes, so NFR4 holds (reads only). `-x` is BSD/macOS-safe and stable across shellcheck 0.7–0.10. Re-linted the hook (clean) and exercised on a clean payload (exit 0). |
| 2026-06-12 | **Findings split into model and user channels (D3 rewritten) + terse `gcc` format.** The hook no longer dumps shellcheck output to the transcript via exit 2 + stderr. It now exits 0 with PostToolUse JSON: full findings ride `hookSpecificOutput.additionalContext` (model-only), the user sees a one-line `systemMessage: "shellcheck failed (N lines)"`, and `suppressOutput: true` hides the raw JSON. The former 60-line bound (NFR3) is dropped since the output no longer floods the transcript. Switched the lint invocation to `shellcheck -f gcc` so findings arrive as one line each (`file:line:col: severity: message [SCxxxx]`) — no carets, source echoes, or wiki blocks — which is directly model-readable and makes `N` a true per-finding count. `-f gcc` is stable across shellcheck 0.7–0.10 and BSD/macOS-safe. Verified against the hooks reference (additionalContext → model, systemMessage → user) and exercised on findings/clean payloads. |
| 2026-06-11 | **Skill rewritten from primary-source research (D7).** Five parallel research agents fact-checked every claim (POSIX.1-2024, GNU/BSD man pages, bash NEWS, BashPitfalls, githooks(5) + git 2.47 repros, shellcheck 0.10.0 empirical runs, Claude Code docs). Corrections: the skill's own suppression syntax was a parse error (`# shellcheck disable=… reason` → must be `… # reason`); three "shellcheck cannot catch" rows were false (SC2155, SC2030/31, SC2070; `cd` half-caught by SC2164); macOS ≥ 12.3 has `readlink -f` and ships `realpath`; macOS xargs accepts `-r`; POSIX 2024 standardized `-print0`, `xargs -r/-0`, `head -c`, `pipefail`, `sed -E`, `timeout`, `realpath` (while removing `test -a/-o`; `local` rejected, Austin #767); `head --lines` example was wrong on current macOS; git hooks export layout-dependent env (`GIT_WORK_TREE` never observed; silent cross-repo corruption fires in worktrees/submodules/bare, not plain clones), documented fix is subshell + `unset $(git rev-parse --local-env-vars)`, never for same-repo commands (partial-commit temp index). New blind spots added: `timeout` absent on macOS, `inherit_errexit`, pipefail+SIGPIPE, bare `wait`, arithmetic injection, traps reset in subshells, `LC_ALL=C read -d ''` (bash 5.0–5.3, BP#65), worktree detection via `--path-format=absolute`, submodule hooks under `.git/modules/<name>/hooks`, hook cwd/stdin/`GIT_PREFIX`/`core.hooksPath` silent-skip, BWK awk, bsdtar, checksum names, `find -regex` flavors, `getopt(1)`, macOS `/bin/sh`-is-bash. References now carry inline citations. |
| 2026-06-11 | **Bats files are linted after all.** Fact-check against documentation overturned the "shellcheck has no bats dialect" claim: bats support landed in shellcheck v0.7.0 (2019, changelog: "Files containing Bats tests can now be checked"); the 0.10.0 man page lists `.bats` among auto-detection extensions; verified live (`@test` body produced SC2154/SC2086). Hook now matches `*.bats` and bats shebangs; former limitation 2 rewritten. |
| 2026-06-11 | **Initial design and implementation (`de4d9a2`).** Plugin created via plugin-dev workflow + writing-skills TDD. RED: 4 baseline scenarios (portable script, hostile filenames, submodule pre-commit hook, edit-with-latent-GNU-ism); documented that the edit scenario reproduces the gitlore BSD-`paste` incident. GREEN: SKILL.md (5 core rules, gotcha table, platform-simulation pattern) + 3 reference catalogs; re-tests pass. Hook: `shellcheck-on-edit.sh` (extension + shebang detection, exit-2 feedback, behaviorally tested incl. dash-with-options shebang). Validated by plugin-validator (PASS) and skill-reviewer (pass; description rewrite, MultiEdit matcher dropped, operational-error separation applied). One-time missing-shellcheck `systemMessage` notice added per user request (D5). Meta-find: a comment beginning `# shellcheck …` parses as a malformed shellcheck directive and fails lint. |
