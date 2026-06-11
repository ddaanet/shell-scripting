# shell-scripting Plugin Design Document

Living document. Requirements and decisions are numbered for reference; the history table records changes as they land.

## Functional Requirements

1. A self-triggering skill (`shell-gotchas`) loads whenever Claude writes, edits, reviews, or debugs shell code — `.sh`/`.bash` files, shebang lines, git hooks, bats tests, wrapper scripts, Makefile recipes, CI run steps.
2. The skill covers what shellcheck cannot detect: GNU vs BSD/macOS runtime divergence, `set -e` blind spots and exit-status loss, environment leakage (git hooks, submodules, worktrees, Claude Code sandbox), and error-path honesty. The mechanical class (quoting, word splitting, bashisms) is delegated to shellcheck.
3. The skill mandates whole-script audit when editing existing scripts with portability requirements: the diff is not the unit of review.
4. The skill documents the platform-simulation regression-test pattern (PATH-shadowing wrapper enforcing the stricter platform's behavior) so portability fixes get locked in on Linux CI.
5. A `PostToolUse` hook runs shellcheck on every shell file Claude writes or edits and feeds findings back to the model automatically, independent of whether the skill triggered.
6. The hook detects shell files by extension (`.sh`, `.bash`, `.bats`) or shebang sniff (sh/bash/dash/ksh/bats, with or without interpreter options).
7. Graceful degradation: when shellcheck is missing, the first shell-file edit of a session emits a one-time user-visible notice that lint feedback is inactive; when jq is missing, the hook is silently inert.

## Non-Functional Requirements

1. **Progressive disclosure.** SKILL.md stays lean (≈900 words: rules, quick-reference table, test pattern, exit checklist); full catalogs live in `references/` (`portability.md`, `robustness.md`, `environments.md`) and load only on demand.
2. **Self-application.** The plugin's own shell code follows the skill's rules: POSIX `#!/bin/sh`, shellcheck-clean, `printf` for data, BSD-safe invocations.
3. **Quiet by default.** The hook is silent on non-shell files, clean files, and missing tools (except FR7's one-time notice); findings output is bounded (60 lines).
4. **Minimal footprint.** The hook writes nothing except the per-session notice marker in `$TMPDIR`; no network, no repo writes.
5. **Portable installation.** All intra-plugin paths go through `${CLAUDE_PLUGIN_ROOT}`.

## Design Decisions

**D1 — Shellcheck-first framing, not a self-contained catalog**

The skill is a thin layer over the linter: its body spends tokens only on what static analysis cannot see, and rule 1 mandates running shellcheck rather than duplicating its checks as prose. A self-contained catalog was rejected — it would re-teach what tooling already enforces, bloat the always-loaded layer, and drift as shellcheck evolves.

**D2 — Test-first authoring (writing-skills TDD)**

Baseline subagent runs *without* the skill preceded writing it. Key finding: agents handle famous gotchas in greenfield code (one baseline unset `GIT_DIR` and guarded an unchecked-out submodule unprompted) but ship latent GNU-isms when *editing* existing scripts — a `paste -sd:` survived an edit pass despite an explicit macOS requirement, reproducing the gitlore launcher-shim incident. The skill body therefore leads with the whole-script audit rule and error-path honesty rather than the famous-gotcha list. GREEN runs confirmed the same scenarios pass with the skill loaded.

**D3 — Findings via exit 2 + stderr; JSON `systemMessage` only for the notice**

Lint findings use the documented PostToolUse feedback mechanism (exit 2, stderr fed to the model). The missing-shellcheck notice instead uses exit 0 + JSON `systemMessage`, the user-visible channel — the user, not the model, is who can act on a missing system dependency.

**D4 — Interpreter allowlist for shebang sniffing**

Only sh/bash/dash/ksh shebangs are linted. A generic `*sh*` match was rejected: it would route fish or zsh files to shellcheck, which cannot parse them and would produce noise findings.

**D5 — One-time notice keyed by session marker in `$TMPDIR`**

Visible degradation (FR7) without nagging: a marker file named with the hook payload's `session_id` suppresses repeats within a session. A missing jq stays silent by construction — without jq the hook cannot parse the payload, so it cannot even tell whether the edit touched a shell file.

**D6 — CC-specific content included**

`references/environments.md` covers Claude Code sandbox probing, `$TMPDIR`, `CLAUDE_PLUGIN_ROOT` self-location, and launch-env freeze. This reduces shareability outside CC but matches the plugin's actual habitat; chosen explicitly over a generic-only scope.

## Limitations

1. The hook only sees `Write`/`Edit` tool calls — shell emitted via Bash-tool heredocs, inline one-liners, and scripts created by other means are never linted.
2. Unusual interpreter paths evade the shebang allowlist; fish and zsh are out of scope (shellcheck cannot parse them).
3. Skill *triggering* is verified only by injection (subagents told to read the skill); organic trigger behavior in a fresh session with the plugin installed has not yet been observed.
4. The catalogs are curated, not exhaustive — shellcheck cannot model GNU/BSD divergence, so the portability table is the only guard for that class, and only for the commands it lists.
5. Notice markers accumulate in `$TMPDIR` (one per session) until OS cleanup.
6. No LICENSE; not yet published to a marketplace.

## History

| Date | Change |
|------|--------|
| 2026-06-11 | **Bats files are linted after all.** Fact-check against documentation overturned the "shellcheck has no bats dialect" claim: bats support landed in shellcheck v0.7.0 (2019, changelog: "Files containing Bats tests can now be checked"); the 0.10.0 man page lists `.bats` among auto-detection extensions; verified live (`@test` body produced SC2154/SC2086). Hook now matches `*.bats` and bats shebangs; former limitation 2 rewritten. |
| 2026-06-11 | **Initial design and implementation (`de4d9a2`).** Plugin created via plugin-dev workflow + writing-skills TDD. RED: 4 baseline scenarios (portable script, hostile filenames, submodule pre-commit hook, edit-with-latent-GNU-ism); documented that the edit scenario reproduces the gitlore BSD-`paste` incident. GREEN: SKILL.md (5 core rules, gotcha table, platform-simulation pattern) + 3 reference catalogs; re-tests pass. Hook: `shellcheck-on-edit.sh` (extension + shebang detection, exit-2 feedback, behaviorally tested incl. dash-with-options shebang). Validated by plugin-validator (PASS) and skill-reviewer (pass; description rewrite, MultiEdit matcher dropped, operational-error separation applied). One-time missing-shellcheck `systemMessage` notice added per user request (D5). Meta-find: a comment beginning `# shellcheck …` parses as a malformed shellcheck directive and fails lint. |
