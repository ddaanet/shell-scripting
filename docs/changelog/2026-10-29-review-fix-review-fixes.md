# 2026-10-29 — Corrected the review of the pre-release fix commit

A medium review of the pre-release fix commit (see
[the entry](2026-10-28-pre-release-review-fixes.md)) found nine defects in the
text that commit wrote. Each was probed (bats 1.14.0, bash 5.2, dash,
shellcheck) before fixing; none was refuted. The earlier entry stands as
written.

`skills/bats-gotchas/references/vacuous-passes.md`: the `! cmd` section heading
and first sentence now say "non-final", since a final `! true` does fail the
test. The explanation no longer claims bats inspects only the last command's
status, which is wrong because `@test` bodies run under errexit (a failing
`(( 0 ))` mid-body aborts). The mechanism is that bash exempts a `!`-negated
command from errexit, so a non-final one cannot abort the test.

`skills/bats-gotchas/references/run-semantics.md`: "the override is visible
where the test's variables are not" is scoped to bats 1.11.1. The 1.14.0
non-reproduction now names both shapes probed (plain `run helper` and
`run --separate-stderr helper`, helper defined in the `@test` body under
`set -u`), matching the example, which uses plain `run`. The edited paragraphs
are hard-wrapped at 80 columns, as is `skills/bats-gotchas/SKILL.md`'s intro.

`skills/bats-gotchas/SKILL.md`: the `BW02` row's Fix cell gives the remedy for
bats 1.5-1.6, where the declaration function does not exist: load bats-backports
or do not declare.

`skills/shell-gotchas/references/robustness.md`: the `pipefail` closing bullet
no longer says neither half is visible without `pipefail`. Without it an
earlier stage's failure never reaches `||`, but a failing last stage still does,
and the fallback lands after the output it already wrote. A pipeline left of
`||` is exempt from `set -e` with or without `pipefail`, so the "(or `set -e`)"
aside is gone.

`skills/shell-gotchas/references/environments.md`: the other-repo unset
one-liner carries a `disable=SC2046` directive on the line above, so it is
lint-clean as copied, and the prose says so. The matching `TODO.md` item is
removed.

`skills/shell-gotchas/references/portability.md`: the `[ -r ./f ]` pre-check no
longer "works everywhere". It catches only a missing or unreadable file; a
syntax error in `f` still exits a POSIX shell at `. ./f` (dash, `bash --posix`).
