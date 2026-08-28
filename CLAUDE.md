# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Claude Code plugin with two independent components:

- **`skills/shell-gotchas/`** — a self-triggering skill covering shell pitfalls shellcheck cannot detect. `SKILL.md` is the always-loaded layer and is deliberately lean (~900 words); full catalogs live in `references/` (`portability.md`, `robustness.md`, `environments.md`) and load only on demand. Keep new content in the references unless it earns a place in the core rules.
- **`hooks/`** — a `PostToolBatch` hook (`hooks.json` + `scripts/shellcheck-on-edit.sh`) that shellchecks every shell file the batch wrote or edited, once per file on its final state. Full findings go to the model via **`hookSpecificOutput.additionalContext`**; the user sees only a one-line **`systemMessage`** summary (as does the one-time missing-shellcheck notice). Don't mix the two channels — the split is deliberate (`docs/design.md` D3).

## Layout

- `docs/design.md` — the living rationale: numbered functional and non-functional requirements, lettered design decisions (D1–D8), known limitations. States what the plugin *is*.
- `docs/changelog.md` — index of write-time records, newest first, one line per entry. Bodies live in `docs/changelog/YYYY-MM-DD-slug.md`.
- `plans/` — specs, design proposals, implementation plans, briefs. Prospective content only; `docs/` holds what is true now. Files are named `YYYY-MM-DD-slug.md`, dated the day the document was written.
- `plugin-dev/` — vendored `git subtree` of claude-plugin-dev. Never edit it here; changes go upstream and come back via `just update-plugin-dev`.

**When landing a change, update the docs in the same commit**: adjust `docs/design.md` if requirements, decisions or limitations moved, and add a dated entry under `docs/changelog/` with its pointer line in `docs/changelog.md`.

## Documentation conventions

- **`docs/design.md` is present tense.** An overturned decision is rewritten in place with the new reasoning — never struck through, never annotated with "formerly".
- **Changelog entries are never revised.** A dated record is correct forever precisely because it is dated. The filename date is the day the record is written; when backfilling, use the date of the commit being recorded. The version, when there is one, goes in the `changelog.md` pointer line, not in the filename.
- **`plans/` is prospective.** Anything describing work not yet done, or describing how something was built rather than what it is, belongs there rather than in `docs/`.

## Commands

```sh
# Lint the hook script (must stay clean — see self-application rule below)
shellcheck hooks/scripts/shellcheck-on-edit.sh

# Exercise the hook manually with a synthetic PostToolBatch payload
printf '{"session_id":"test","tool_calls":[{"tool_name":"Write","tool_input":{"file_path":"%s/test.sh"}}]}' \
  "${TMPDIR:-/tmp}" | sh hooks/scripts/shellcheck-on-edit.sh; echo "exit=$?"

# Test the plugin end-to-end in a live session
claude --plugin-dir /Users/david/code/shell-gotchas
```

Hook exit contract: exit 0 always — either silent (no shell file in the batch, missing `jq` or `shellcheck`, clean lint) or one JSON object on stdout. Shebang detection only allows sh/bash/dash/ksh/bats interpreters (D4 — a loose match would feed fish/zsh to shellcheck and produce noise).

## Self-application rule

The plugin's own shell code must follow its own skill: `#!/bin/sh` POSIX only, shellcheck-clean, `printf` for data (never `echo`), BSD/macOS-safe invocations, no writes outside `$TMPDIR`. When editing `shellcheck-on-edit.sh`, audit the whole script, not just the diff.

Gotcha found during development: a comment beginning `# shellcheck …` parses as a malformed shellcheck directive and fails lint — phrase comments to avoid that prefix.

## Skill authoring conventions

The skill was built test-first (writing-skills TDD): baseline subagent runs without the skill identified the failures the skill body targets (latent GNU-isms surviving edit passes, dishonest success messages, lost exit statuses). When changing the skill's emphasis or adding rules, the bar is an observed failure mode, not a hypothetical one. The skill is a thin layer over shellcheck (D1) — do not add prose re-teaching what the linter already enforces.

All intra-plugin paths in `hooks.json` must go through `${CLAUDE_PLUGIN_ROOT}`.

## Commits

A gitmoji commit-msg hook rewrites conventional-commit prefixes (`feat:`, `fix:`, `docs:` …) into emoji. Existing history uses gitmoji style (✨, 📝).
