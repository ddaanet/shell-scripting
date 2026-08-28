# 2026-06-12 — Findings split into model and user channels (v0.3.0)

The hook no longer dumps shellcheck output to the transcript via exit 2 + stderr.
stderr is shown to *both* the model and the user, so a wall of lint findings landed
in the transcript for a human who could not act on it.

It now exits 0 with `PostToolUse` JSON: the full findings ride
`hookSpecificOutput.additionalContext` (model-only), the user sees a one-line
`systemMessage: "shellcheck failed (N lines)"`, and `suppressOutput: true` keeps the
raw JSON out of the transcript. Because the findings no longer reach the transcript,
the former 60-line cap is dropped and the model receives the complete output.

The lint invocation switched to `shellcheck -f gcc`, so findings arrive one line
each (`file:line:col: severity: message [SCxxxx]`) with no carets, source echoes, or
wiki blocks. That is directly model-readable and makes `N` a true per-finding count.
`-f gcc` is stable across shellcheck 0.7–0.10 and BSD/macOS-safe.

The missing-shellcheck notice keeps using `systemMessage` — the user, not the model,
is who can act on a missing system dependency.

Verified against the hooks reference (`additionalContext` → model, `systemMessage` →
user) and exercised on both findings and clean payloads.
