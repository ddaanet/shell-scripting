# 2026-10-29 — Corrected the wording of the review-fix commit

A medium review of the review-fix commit (see
[the entry](2026-10-29-review-fix-review-fixes.md)) found seven defects in the
text that commit wrote. Each was checked before fixing; none was refuted. The
earlier entry stands as written.

`skills/bats-gotchas/SKILL.md` and `references/run-semantics.md`: the `BW02`
remedy for bats 1.5-1.6 no longer reads "load bats-backports or do not
declare" as if both were equal. A suite spanning 1.5-1.6 and newer must load
bats-backports; only one running solely on 1.5-1.6 may skip the declaration.

`skills/bats-gotchas/references/vacuous-passes.md`: "its inverted status is
discarded" was wrong. Bash sets `$?` to the inverted status; `!` exempts the
command from errexit (and the ERR trap), so nothing aborts on it.

`skills/bats-gotchas/references/run-semantics.md`: shadowing a sourced function
through `run` is stated to work on 1.11.1 and on 1.14.0 (probed); only the
visibility of the test's variables differs. The `@test` errexit paragraph is
rewrapped to 80 columns by byte count, since it was 81 bytes.

`skills/shell-gotchas/references/portability.md`: the `[ -r ./f ] || exit 2;
. ./f` form is labelled as a pre-check for a missing or unreadable file, not
"Safe:", and says it does not stop a syntax error in `f` exiting a POSIX shell.

`skills/shell-gotchas/references/robustness.md`: the first `pipefail` bullet
says `pipefail` makes any stage's failure trigger the `||` fallback and that
without it a failing last stage still does, so the closing bullet is not the
only place the concatenation is described.

`skills/shell-gotchas/references/environments.md`: the SC2046 sentence is
rejoined to one line, matching the file's one-line-per-paragraph style.
