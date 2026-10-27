# 2026-10-27 — Split the bats and just catalogs into sibling skills

`shell-gotchas` carried two harness catalogs as `references/` nodes, `bats.md`
and `just.md`. Both have triggers that are mechanical and unrelated to general
shell code, a `.bats` file and a justfile, yet editing either loaded the whole
shell skill first and the catalog only if the model chose to follow a pointer.
They are now skills of their own.

`skills/bats-gotchas/SKILL.md` is `references/bats.md` moved with `git mv` and
given frontmatter; `skills/just-gotchas/SKILL.md` likewise from `just.md`. Each
`description` is one clause on what the skill is plus the concrete triggers,
under about 60 words, because every description is loaded in every session.
Paths in the moved bodies that pointed at sibling references now read
`../shell-gotchas/references/<file>.md`.

`bats-gotchas/SKILL.md` came to 221 lines against the ~200-line hub cap. The
two linting sections ("ShellCheck lints `.bats` natively" and the
directive-comment trap) moved to `bats-gotchas/references/linting.md` behind a
pointer, rather than trimming prose; they are the most self-contained part of
the file.

`shell-gotchas/SKILL.md` lost its two reference bullets (replaced by one line
naming the siblings by relative path), `.bats tests` and `just recipes` in its
description triggers (Makefile stays), and its "Locking In a Portability Fix"
section. The template and the adapt-for-`sed -i`/`xargs`/`date` sentence moved
into `references/portability.md` under "Locking fixes in", replacing the
pointer back to `SKILL.md`; the section is retitled since it is no longer a
cross-reference. The hub dropped from about 1300 to about 1100 words.

`CLAUDE.md` describes three skills and points at the `plugin-dev:skill-development`
size guidance instead of the stale "~900 words" figure. `docs/design.md` gains
FR9 and D9, and its progressive-disclosure requirement is rewritten for three
skills. `README.md` lists all three. `dist.include` already ships `skills/` and
`plugin.json` has no explicit skills list, so neither changed.

Not decided here: whether the cost of two more always-on descriptions is worth
it in practice. The split rests on the triggers being distinct; observed
trigger behaviour in fresh sessions (design limitation 3) applies to the new
skills as well.
