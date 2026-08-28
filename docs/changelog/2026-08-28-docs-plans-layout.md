# 2026-08-28 — Documentation split into `docs/` and `plans/`

Root `DESIGN.md` became `docs/design.md` (via `git mv`, so history follows the
file) plus this changelog. The single file had accumulated two incompatible kinds
of content: the current design, which wants rewriting in place when a decision is
overturned, and the history of how it got there, which must never be rewritten.
Editing either one inside a shared file risks corrupting the other.

`docs/` now holds only what is true now — `design.md` and `changelog.md` plus the
`changelog/` bodies. A root `plans/` holds prospective content: specs, design
proposals, implementation plans, briefs — anything describing work not yet done, or
how something was built rather than what it is. The brief that specified this
migration is its first occupant, renamed to the family's date-first convention
(`2026-07-29-docs-plans-layout-brief.md`, dated the day it was written).

The nine rows of the old history table were backfilled as dated entries, each
dated by the commit it records rather than by the day of backfill. Dating by
release was rejected: entries do not map one-to-one onto releases — one release
can carry several decisions, and some decisions ship across two — while the write
date needs no reconciliation. The version, where there is one, goes in the
`changelog.md` pointer line, not in the filename. A single `changelog.md` holding
all bodies was also rejected: it grows without bound, and every append rewrites a
file whose entries are supposed to be individually frozen.

While reorganising `design.md`, the design decisions and limitations were put back
in ascending numeric order (D6 had drifted after D8, limitation 7 after 4). The
labels are unchanged, so cross-references still resolve.

`CLAUDE.md` was updated in the same commit, since it names these paths. Two stale
claims in it were corrected at the same time: it still described a `PostToolUse`
hook reporting through exit 2 + stderr, which the 2026-06-30 and 2026-06-12
changes had already replaced with `PostToolBatch` and the dual-channel output.

This layout is propagating across the plugin family from `claude-plugin-dev`,
where it was introduced on 2026-07-29 (`c37f3cb`, `1c9999c`).
