# shell-scripting Changelog

How the design got to its current shape. Each entry is a write-time record of one
change: what moved, and the reasoning available at the time. Entries are never
revised — a dated record is correct forever precisely because it is dated. The
living design is [design.md](design.md); when a decision there is overturned, it is
rewritten in place and the reversal gets an entry here.

Newest first.

- [2026-10-27 — Corrected the re-review findings on the bats-gotchas hub](changelog/2026-10-27-bats-hub-review-fixes.md) — out-param bare call limited to success paths, `$stderr` fact detached from the missing-declaration trap, `jq` `false` and Claude Code stdin qualifiers restored, vacuous-passes intro repointed
- [2026-10-27 — bats-gotchas becomes a hub; fixes to the skill split](changelog/2026-10-27-bats-hub-and-split-fixes.md) — one trap/symptom/fix table over themed references, `shell-gotchas` triggers on `.bats` and `just` again, D9 rewritten to match, plus description, manifest and LICENSE-limitation fixes
- [2026-10-27 — Split the bats and just catalogs into sibling skills](changelog/2026-10-27-skill-split.md) — two harness catalogs with mechanical, distinct triggers become `bats-gotchas` and `just-gotchas`, so editing one loads only its own body; the portability-test template moves into `references/portability.md`
- [2026-10-27 — Corrected the review findings on the inbox triage increments](changelog/2026-10-27-inbox-triage-review-fixes.md) — a non-final pipeline stage keeps `-e` (the claim was wrong), the `die` recovery arm needs a guard rather than ordering, the `stat` check gates, and the `%q` and bats text rescoped
- [2026-10-27 — Landed the 2026-10-26 inbox triage increments](changelog/2026-10-27-inbox-triage-increments.md) — AND-OR recovery arms stay armed under `set -e`, substitutions in tests discard failures, plus `wc`, macOS `$TMPDIR`, bash 3.2, hook-staging and bats/jq entries; https submodule urls declined
- [2026-09-02 — Absorbed the remaining memory overlaps](changelog/2026-09-02-wider-memory-absorption.md) — the `stat` probe-once rule, the hook-leak symptom string and `GIT_COMMON_DIR` corruption path, the bogus 160000 gitlink, and the capture-and-match rung
- [2026-09-02 — Absorbed the bats and just catalogs](changelog/2026-09-02-bats-just-absorption.md) — two new `references/` nodes, § Parsing git output promoted out of a stub, and a corrected `GIT_INDEX_FILE` failure mode
- [2026-08-28 — Documentation split into `docs/` and `plans/`](changelog/2026-08-28-docs-plans-layout.md) — `DESIGN.md`'s living design and its immutable history were fighting over one file
- [2026-07-28 — `pipefail` fallback appends to real output](changelog/2026-07-28-pipefail-fallback-gotcha.md) — `x=$(producer | filter || echo FB)` can capture output *and* fallback, back to back (v0.3.2)
- [2026-06-30 — Needless `2>/dev/null` hides real errors](changelog/2026-06-30-stderr-suppression-gotcha.md) — blanket stderr suppression discards permission and disk-full errors too, and shellcheck never flags it (v0.3.1)
- [2026-06-30 — Hook moved to `PostToolBatch`](changelog/2026-06-30-posttoolbatch-coalescing.md) — one report per file per batch, from the platform's own batch record instead of a debounce (v0.3.0)
- [2026-06-30 — Lint follows external sources](changelog/2026-06-30-external-sources.md) — `shellcheck -x` checks sourced helpers in context instead of emitting SC1091 for each (v0.3.0)
- [2026-06-12 — Findings split into model and user channels](changelog/2026-06-12-dual-channel-hook-output.md) — full output to the model via `additionalContext`, one line to the user via `systemMessage` (v0.3.0)
- [2026-06-11 — Skill rewritten from primary-source research](changelog/2026-06-11-research-grounded-rewrite.md) — five research agents replaced memory-derived content with cited or empirically verified claims (v0.2.0)
- [2026-06-11 — Bats files are linted after all](changelog/2026-06-11-bats-linting.md) — shellcheck has had a bats dialect since v0.7.0, overturning a limitation written from memory (v0.2.0)
- [2026-06-11 — Initial design and implementation](changelog/2026-06-11-initial-plugin.md) — skill built test-first against baseline subagent failures, plus the shellcheck-on-edit hook (v0.2.0)
