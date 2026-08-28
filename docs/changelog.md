# shell-scripting Changelog

How the design got to its current shape. Each entry is a write-time record of one
change: what moved, and the reasoning available at the time. Entries are never
revised — a dated record is correct forever precisely because it is dated. The
living design is [design.md](design.md); when a decision there is overturned, it is
rewritten in place and the reversal gets an entry here.

Newest first.

- [2026-08-28 — Documentation split into `docs/` and `plans/`](changelog/2026-08-28-docs-plans-layout.md) — `DESIGN.md`'s living design and its immutable history were fighting over one file
- [2026-07-28 — `pipefail` fallback appends to real output](changelog/2026-07-28-pipefail-fallback-gotcha.md) — `x=$(producer | filter || echo FB)` can capture output *and* fallback, back to back (v0.3.2)
- [2026-06-30 — Needless `2>/dev/null` hides real errors](changelog/2026-06-30-stderr-suppression-gotcha.md) — blanket stderr suppression discards permission and disk-full errors too, and shellcheck never flags it (v0.3.1)
- [2026-06-30 — Hook moved to `PostToolBatch`](changelog/2026-06-30-posttoolbatch-coalescing.md) — one report per file per batch, from the platform's own batch record instead of a debounce (v0.3.0)
- [2026-06-30 — Lint follows external sources](changelog/2026-06-30-external-sources.md) — `shellcheck -x` checks sourced helpers in context instead of emitting SC1091 for each (v0.3.0)
- [2026-06-12 — Findings split into model and user channels](changelog/2026-06-12-dual-channel-hook-output.md) — full output to the model via `additionalContext`, one line to the user via `systemMessage` (v0.3.0)
- [2026-06-11 — Skill rewritten from primary-source research](changelog/2026-06-11-research-grounded-rewrite.md) — five research agents replaced memory-derived content with cited or empirically verified claims (v0.2.0)
- [2026-06-11 — Bats files are linted after all](changelog/2026-06-11-bats-linting.md) — shellcheck has had a bats dialect since v0.7.0, overturning a limitation written from memory (v0.2.0)
- [2026-06-11 — Initial design and implementation](changelog/2026-06-11-initial-plugin.md) — skill built test-first against baseline subagent failures, plus the shellcheck-on-edit hook (v0.2.0)
