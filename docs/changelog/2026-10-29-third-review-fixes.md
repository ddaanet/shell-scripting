# 2026-10-29 — Corrected the third review of the bats and shell skills

A medium review of the wording commit (see
[the entry](2026-10-29-fix-review-wording.md)) found three defects. Each was
checked before fixing; none was refuted. The earlier entry stands as written.

`skills/bats-gotchas/SKILL.md`: the `BW02` Fix cell is cut to the core remedy
(declare `bats_require_minimum_version 1.5.0`; the function exists from bats
1.7.0) and points at `references/run-semantics.md` for older bats. The `! cmd`
Symptom cell now matches `vacuous-passes.md`: `$?` holds the inverted status
but nothing aborts on it.

`skills/bats-gotchas/references/run-semantics.md`: "must load bats-backports"
was absolute. On 1.5-1.6 the function is missing; the paragraph quotes the
bats(7) manual on bats-backports and offers a guarded call, `type
bats_require_minimum_version >/dev/null 2>&1 && bats_require_minimum_version
1.5.0`, probed on bats 1.14.0 to silence `BW02` and pass `shellcheck
--shell=bats`. The paragraph is rewrapped to 80 columns.

`skills/shell-gotchas/references/robustness.md`: the first `pipefail` bullet's
headline said the fallback runs "whenever any stage fails", true only under
`pipefail`. It now says "whenever the pipeline fails", and the parenthetical
about a failing last stage is dropped, since the third bullet states the
no-`pipefail` case.

Declined: the `[ -r ./f ]` directory case in `portability.md`. A directory
where a sourced file is expected is a state nothing in practice produces.
