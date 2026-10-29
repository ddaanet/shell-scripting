# 2026-10-29 — Corrected the fourth review of the bats and shell skills

A medium review of the third round's fixes (see
[the entry](2026-10-29-third-review-fixes.md)) found four defects. Each was
checked before fixing; none was refuted. The earlier entry stands as written.
This round removes surface rather than adding it.

`skills/bats-gotchas/references/run-semantics.md`: the guarded call the third
round's entry recommends, `type bats_require_minimum_version >/dev/null 2>&1 &&
bats_require_minimum_version 1.5.0`, is removed together with its probe. It
returns 1 when the function is missing, which breaks a `load`ed helper or a
`setup()` that ends with it, and the probe covered only the branch where the
function exists. The paragraph restores the earlier split: a suite spanning
1.5-1.6 and newer can load bats-backports (paraphrasing the bats(7) manual); a
suite that runs only on 1.5-1.6 may skip the declaration.

`skills/bats-gotchas/SKILL.md`: the `! cmd` Fix cell routes older bats to
`run-semantics.md`, as the `BW02` row does, instead of stating the 1.7.0
boundary. The `! cmd` Symptom cell now says that when non-final nothing aborts
on it, with `$?` still holding the inverted status. The `BW02` Fix cell regains
the `$stderr` trap: read `$stderr` before the next `run`, since a plain `run`
unsets it.

`skills/shell-gotchas/references/robustness.md`: the first `pipefail` bullet's
headline said the fallback runs without discarding what "an earlier stage"
already wrote; it now says "the pipeline", which also covers a failing last
stage's own partial output.
