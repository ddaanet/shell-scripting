# 2026-06-30 — New gotcha: needless `2>/dev/null` hides real errors (v0.3.1)

Added a table row to `SKILL.md` and a fuller bullet to `references/robustness.md`
("Honest reporting") warning that a blanket `2>/dev/null` discards *every* stderr
line a command can produce, not just the one expected message — masking permission
errors, disk-full, and typo'd flags.

The recommendation is to test the condition explicitly, or scope the suppression
narrowly and say in a comment what is being suppressed and why.

Shellcheck has no coverage here — it never flags stderr redirection — which is
exactly the boundary the skill is meant to occupy.
