# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Claude Code plugin with two independent components:

- **`skills/shell-gotchas/`** — a self-triggering skill covering shell pitfalls shellcheck cannot detect. `SKILL.md` is the always-loaded layer and is deliberately lean (~900 words); full catalogs live in `references/` (`portability.md`, `robustness.md`, `environments.md`) and load only on demand. Keep new content in the references unless it earns a place in the core rules.
- **`hooks/`** — a `PostToolUse` hook (`hooks.json` + `scripts/shellcheck-on-edit.sh`) that shellchecks every shell file Claude writes or edits. Findings go to the model via **exit 2 + stderr**; the one-time missing-shellcheck notice goes to the user via **exit 0 + JSON `systemMessage`**. Don't mix the two channels — the split is deliberate (DESIGN.md D3).

## DESIGN.md is the source of truth

DESIGN.md is a living document with numbered functional/non-functional requirements, lettered design decisions (D1–D6), known limitations, and a history table. **When landing a change, update DESIGN.md in the same commit**: adjust requirements/limitations if behavior changed, and add a row to the history table.

## Commands

```sh
# Lint the hook script (must stay clean — see self-application rule below)
shellcheck hooks/scripts/shellcheck-on-edit.sh

# Exercise the hook manually with a synthetic payload
printf '{"tool_input":{"file_path":"/tmp/claude/test.sh"},"session_id":"test"}' \
  | sh hooks/scripts/shellcheck-on-edit.sh; echo "exit=$?"

# Test the plugin end-to-end in a live session
claude --plugin-dir /Users/david/code/shell-scripting
```

Hook exit contract: 0 = silent (non-shell file, clean lint, missing tool), 2 = findings on stderr. Shebang detection only allows sh/bash/dash/ksh/bats interpreters (D4 — a loose match would feed fish/zsh to shellcheck and produce noise).

## Self-application rule

The plugin's own shell code must follow its own skill: `#!/bin/sh` POSIX only, shellcheck-clean, `printf` for data (never `echo`), BSD/macOS-safe invocations, no writes outside `$TMPDIR`. When editing `shellcheck-on-edit.sh`, audit the whole script, not just the diff.

Gotcha found during development: a comment beginning `# shellcheck …` parses as a malformed shellcheck directive and fails lint — phrase comments to avoid that prefix.

## Skill authoring conventions

The skill was built test-first (writing-skills TDD): baseline subagent runs without the skill identified the failures the skill body targets (latent GNU-isms surviving edit passes, dishonest success messages, lost exit statuses). When changing the skill's emphasis or adding rules, the bar is an observed failure mode, not a hypothetical one. The skill is a thin layer over shellcheck (D1) — do not add prose re-teaching what the linter already enforces.

All intra-plugin paths in `hooks.json` must go through `${CLAUDE_PLUGIN_ROOT}`.

## Commits

A gitmoji commit-msg hook rewrites conventional-commit prefixes (`feat:`, `fix:`, `docs:` …) into emoji. Existing history uses gitmoji style (✨, 📝).
