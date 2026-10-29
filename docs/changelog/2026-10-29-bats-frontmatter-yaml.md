# 2026-10-29 — Quoted the bats skill description so its frontmatter parses

An adversarial Codex review of `dev` against `main` found that the
`bats-gotchas` `description` was an unquoted YAML scalar containing
`pitfalls: tests`, which a YAML parser rejects as a nested mapping
(`mapping values are not allowed here`, reproduced with PyYAML). The
description is now double-quoted, with its text unchanged; all three skills'
frontmatter parse.

The medium review of the `BW02` heading rename (see
[the entry](2026-10-29-bw02-heading.md)) found no high or medium issue.
Declined as low severity: the section's opening "On 1.7+ declare" read as a
requirement, though the same sentence says bats carries on without it; the
plural "anchor links" in that entry's pointer line; the hub's `BW02` row
linking to `run-semantics.md` without the section anchor; and the missing
trailing newline in `TASK.md`.
