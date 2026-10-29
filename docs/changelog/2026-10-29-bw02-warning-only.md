# 2026-10-29 — Removed the claim that a missing BW02 declaration breaks suites

A medium review of the version-floors entry (see
[the entry](2026-10-29-bats-version-floors.md)) found that the bats skill
still said a suite without `bats_require_minimum_version` could be green on one
machine and red on another. The earlier entry stands as written.

Probed on bats 1.14.0 with no declaration: `run --separate-stderr sh -c "echo
o; echo e >&2"` gives `$output`=o and `$stderr`=e; `run ! true` fails the test
("expected nonzero exit code!"); `run ! false` passes with `$status`=1. Each
flagged `run` printed only the `BW02` warning. On 1.7+ a missing declaration
changes nothing but the warning.

`skills/bats-gotchas/references/run-semantics.md`: the `BW02` section drops the
"to-fix" framing and the machine-dependence sentence, and states the probe
result.

`skills/bats-gotchas/SKILL.md`: the `BW02` row's Symptom cell reads "Warning
`BW02` (flags still work)" and its Fix cell no longer says to treat `BW02` as a
to-fix.

Declined as low severity: a remedy for the bats < 1.5 `run !` vacuous pass
(adds new surface); the `command not found` string, which was not probed; the
redundant pointers in `SKILL.md` and `vacuous-passes.md`; and the earlier
entry's declined and fixed wording, which cannot be revised.
