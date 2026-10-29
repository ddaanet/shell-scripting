# 2026-10-29 — Corrected the fifth review of the bats skill

A medium review of the fourth round's fixes (see
[the entry](2026-10-29-fourth-review-fixes.md)) found three defects. Each was
checked before fixing; none was refuted. The earlier entry stands as written,
except that it overstated the bats(7) manual as the source of the advice to
skip the declaration on 1.5-1.6: the manual says only that the function is
unavailable before 1.7.0 and that bats-backports makes it usable.

`skills/bats-gotchas/references/vacuous-passes.md`: the `run ! command`
paragraph told readers to declare `bats_require_minimum_version 1.5.0`
unconditionally, which fails on bats 1.5-1.6. It now points to the `BW02`
section of `run-semantics.md` for bats before 1.7.0.

`skills/bats-gotchas/SKILL.md`: the `! cmd` Fix cell sent older bats to
`run-semantics.md`, which never said `run !` needs bats 1.5.0. The cell now
states that floor.

`skills/bats-gotchas/references/run-semantics.md`: the `BW02` paragraph
attributed to the manual more than it says. It now keeps to the manual only the
unavailability before 1.7.0 and the bats-backports remedy, restores the
bats-backports URL, and marks plainly that a suite running only on 1.5-1.6 may
skip the declaration as not verified (unprobed).

The review's other seven findings were declined as low severity.
