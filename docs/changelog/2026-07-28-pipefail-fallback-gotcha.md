# 2026-07-28 — New gotcha: `pipefail` fallback appends to real output (v0.3.2)

Added a `SKILL.md` table row and a new `pipefail` subsection in
`references/robustness.md`, kept separate from the "Exit status and `set -e`"
section because the mechanism is `pipefail`, not errexit.

The case is `x=$(producer | filter || echo FB)`. Under `pipefail`, `||` fires when
*any* stage fails, including one that fails *after* the last stage has already
written real output — so the substitution captures the output and the fallback
concatenated. The symptom that surfaced it was a JSON consumer choking on two
documents back to back. The fix is to put `||` outside the substitution.

Folded in the related half of the same incident: a pipeline-producer function whose
benign "no match" case returns non-zero, with the same shape of fix (an explicit
`return 0`).

Sourced from a real proof-pass incident rather than a primary-source citation. The
research bar still applied — the mechanism was verified, not just restated. The
existing errexit-suspended-in-condition bullet was left untouched: it already covered
its mechanism, and no narrative incident was added, to keep the catalog's
non-narrative tone.
