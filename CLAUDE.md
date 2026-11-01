# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## What this is

A Claude Code plugin with two independent components: skills (three siblings)
and a hook.

- **`skills/shell-gotchas/`** — a self-triggering skill covering shell pitfalls
  shellcheck cannot detect. `SKILL.md` is the always-loaded layer; full catalogs
  live in `references/` (`portability.md`, `shell-versions.md`, `robustness.md`,
  `environments.md`, `claude-code.md`) and load only on demand. Keep new content
  in the references unless it earns a place in the core rules.
- **`skills/bats-gotchas/`** — a self-triggering skill for `.bats` files and
  bats tests: suites that pass while asserting nothing, errexit in a `@test`,
  shellchecking `.bats`. Its `SKILL.md` is a hub in the `shell-gotchas` shape
  (one trap/symptom/fix table); `references/` (`vacuous-passes.md`,
  `run-semantics.md`, `linting.md`) holds the explanations.
- **`skills/just-gotchas/`** — a self-triggering skill for justfiles and `just`
  recipes: raw-text interpolation, shebang indentation, comments that are
  interpolated.
- **`hooks/`** — a `PostToolBatch` hook (`hooks.json` +
  `scripts/shellcheck-on-edit.sh`) that lints every shell file the batch wrote
  or edited, once per file on its final state, with shellcheck and with
  `scripts/bash32-lint.sh` (three bash 3.2 traps shellcheck cannot see, D11).
  Full findings go to the model via **`hookSpecificOutput.additionalContext`**;
  the user sees only a one-line **`systemMessage`** summary,
  `shell lint: N findings` (the one-time missing-shellcheck notice rides in the
  same message). Don't mix the two channels — the split is deliberate
  (`docs/design.md` D3).

The bats and just skills are siblings, not references of `shell-gotchas`, so
editing a `.bats` file or a justfile loads that skill's catalog directly; each
sibling's body tells the reader to also invoke `shell-scripting:shell-gotchas`,
since test and recipe bodies are shell code (`docs/design.md` D9); that is not
always followed. Every skill's `description` is loaded in every session: keep
each one short (the two siblings under ~60 words; `shell-gotchas`' is longer by
design, carrying the main trigger surface). For `SKILL.md` body size, follow the
guidance in the `plugin-dev:skill-development` skill (1,500–2,000 words ideal,
under 3,000); the ddaanet hub cap is the 10000-byte `check-size` limit. A
sibling skill reaches another skill's files by relative path from the referring
file (`../shell-gotchas/references/environments.md`); the pointer to
`shell-gotchas` is the exception and names the skill, since a Read under the
plugin cache can be refused.

## Layout

- `docs/design.md` — the living rationale: numbered functional and
  non-functional requirements, lettered design decisions (D1–D10), known
  limitations. States what the plugin *is*.
- `plans/` — specs, design proposals, implementation plans, briefs. Prospective
  content only; `docs/` holds what is true now. Files are named
  `YYYY-MM-DD-slug.md`, dated the day the document was written.
- `inbox/` — briefs arriving from sessions in *other* repositories, never the
  repo root, where they read as tracked project documents. Triage means landing,
  declining or promoting each into `plans/`, then deleting it
  (`inbox/README.md`).
- `skills/` — the three skills; each is `SKILL.md` plus optional `references/`.
- `docs/references/` — nodes holding the argument of one mechanism each;
  `hook.md` is the `PostToolBatch` hook's. `docs/design.md` keeps the
  conclusions.
- `plugin-dev/` — vendored `git subtree` of claude-plugin-dev.

**When landing a change, update the docs in the same commit**: adjust
`docs/design.md` if requirements, decisions or limitations moved. History is
git's: the why of a change goes in the commit body, not in a separate record.

## Before touching the hook

Read `docs/references/hook.md` first: `docs/design.md` holds only the
conclusions of the hook's decisions.

| If you touch or cite                    | Read first                |
| --------------------------------------- | ------------------------- |
| `hooks/scripts/shellcheck-on-edit.sh`   | `docs/references/hook.md` |
| `hooks/scripts/bash32-lint.sh`          | `docs/references/hook.md` |
| `hooks/hooks.json`                      | `docs/references/hook.md` |
| `hookSpecificOutput.additionalContext`  | `docs/references/hook.md` |
| `systemMessage`                         | `docs/references/hook.md` |
| `PostToolBatch`                         | `docs/references/hook.md` |
| D3, D4, D5, D8, D11                     | `docs/references/hook.md` |

A hub conclusion in `docs/design.md` and its node's argument change in the same
commit.

## Documentation conventions

- **`docs/design.md` is present tense.** An overturned decision is rewritten in
  place with the new reasoning — never struck through, never annotated with
  "formerly".
- **`plans/` is prospective.** Anything describing work not yet done, or
  describing how something was built rather than what it is, belongs there
  rather than in `docs/`.

## Commands

```sh
# Pre-commit gate: check-refs, plugin.json, skill frontmatter, shellcheck,
# `rumdl fmt --check` (80-column wrap), the bats suite, then the toolkit's
# check-size (a byte cap: 20000, 10000 for a SKILL.md hub).
# Needs jq, shellcheck and bats on PATH. rumdl (0.3.2 or newer) and PyYAML come from
# `uv sync` (dev group of pyproject.toml), put on PATH by direnv via .envrc;
# there is no `uv run`. To fix a wrap failure: rumdl fmt --no-cache .
just precommit

# Lint the hook script (must stay clean — see self-application rule below)
shellcheck hooks/scripts/shellcheck-on-edit.sh hooks/scripts/bash32-lint.sh tests/bash32-lint.bats

# Run the suite for the bash 3.2 lint and its hook wiring
bats tests

# Dogfood the lint over the plugin's own scripts and tests (must print nothing)
sh hooks/scripts/bash32-lint.sh hooks/scripts/*.sh tests/*.bats

# Exercise the hook manually with a synthetic PostToolBatch payload
printf '{"session_id":"test","tool_calls":[{"tool_name":"Write","tool_input":{"file_path":"%s/test.sh"}}]}' \
  "${TMPDIR:-/tmp}" | sh hooks/scripts/shellcheck-on-edit.sh; echo "exit=$?"

# Test the plugin end-to-end in a live session
claude --plugin-dir /Users/david/code/shell-gotchas
```

Hook exit contract: exit 0 always — either silent (no shell file in the batch,
missing `jq`, clean lint) or one JSON object on stdout. A missing `shellcheck`
is not silent: the notice and the bash 3.2 findings share that one object.
Shebang detection only allows sh/bash/dash/ksh/bats interpreters (D4 — a loose
match would feed fish/zsh to shellcheck and produce noise).

## Self-application rule

The plugin's own shell code must follow its own skill: `#!/bin/sh` POSIX only,
shellcheck-clean, `printf` for data (never `echo`), BSD/macOS-safe invocations,
no writes outside `$TMPDIR`. When editing `shellcheck-on-edit.sh` or
`bash32-lint.sh`, audit the whole script, not just the diff.

Gotcha found during development: a comment beginning `# shellcheck …` parses as
a malformed shellcheck directive and fails lint — phrase comments to avoid that
prefix.

## Skill authoring conventions

The skill was built test-first (writing-skills TDD): baseline subagent runs
without the skill identified the failures the skill body targets (latent
GNU-isms surviving edit passes, dishonest success messages, lost exit statuses).
When changing the skill's emphasis or adding rules, the bar is an observed
failure mode, not a hypothetical one. The skill is a thin layer over shellcheck
(D1) — do not add prose re-teaching what the linter already enforces.

All intra-plugin paths in `hooks.json` must go through `${CLAUDE_PLUGIN_ROOT}`.

## Commits

A gitmoji commit-msg hook rewrites conventional-commit prefixes (`feat:`,
`fix:`, `docs:` …) into emoji. Existing history uses gitmoji style (✨, 📝).

@memory/ddaanet/shared-claude.md
