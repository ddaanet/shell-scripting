# 2026-10-27 — bats-gotchas becomes a hub; fixes to the skill split

The review of the skill split (commit 83d2436) found the siblings did not bring
the general shell catalog with them, and that `bats-gotchas/SKILL.md` stood at
201 lines with a `run`-scoping section stranded after the linting pointer.

`bats-gotchas/SKILL.md` is now shaped like `shell-gotchas/SKILL.md`: frontmatter,
a short intro, and one table with a row per trap (trap, symptom, fix), each row
carrying its fix so the body is usable without opening a reference. The
explanations moved verbatim into `references/`: `vacuous-passes.md` (`! cmd`,
`run` of a missing function, a helper's `${n:-default}`, multi-line
`grep -qF`, `jq` output), `run-semantics.md` (both `run` subshell sections
adjacent, the `BW02` and `$stderr` paragraph under a heading of its own, and
errexit in a `@test`), and the existing `linting.md`. Only headings and joins
are new; a sorted-line comparison against the pre-change body found every
sentence in exactly one reference. The intro paragraphs (the six-vacuous-passes
summary, the errexit-points-the-other-way note, the "green test is evidence
only if" rule) sit at the top of `vacuous-passes.md`. Two table rows point out
of the skill: test stdin to `environments.md`, and the GNU-only spelling in a
`@test` body that a PATH stub never shadows to "Locking fixes in" in
`portability.md`.

`shell-gotchas` triggers on `.bats` tests and `just` recipes again: its
description regains both in the trigger list, because test and recipe bodies
are shell code. Editing either now loads the general skill and the sibling
together, so the sibling skills need no reach-back line. D9 is rewritten to
say so, drops the claim that the siblings reach back to
`shell-gotchas/references/` in general, and scopes the "under about 60 words"
description budget to the two sibling descriptions, since `shell-gotchas`'
description carries the main trigger surface. NFR1 and FR1/FR9, `CLAUDE.md` and
the README follow. The `shell-gotchas` portability bullet now mentions the
platform-simulation regression-test template.

Smaller fixes: the `bats-gotchas` description reads as a sentence ("Catalogs
bats pitfalls: tests that pass while asserting nothing, and lint traps"); the
`CLAUDE.md` sibling-loading paragraph moved out of the skill bullet list to
after the hook bullet, and the opening line says "skills (three siblings) and a
hook"; `plugin.json` names the skills in the plural (shell, bats, just) and
gains `bats` and `just` keywords. Design limitation 6 no longer says "No
LICENSE": the file exists and ships in `dist.include`.
