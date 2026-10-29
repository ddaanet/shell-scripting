# 2026-10-29 — Added a skill frontmatter check to the precommit gate

The invalid `bats-gotchas` frontmatter (see
[the entry](2026-10-29-bats-frontmatter-yaml.md)) passed `just precommit` and
the medium review of the commit that introduced it, because nothing in the
gate parsed a `SKILL.md`. `precommit` now runs `scripts/check-frontmatter.py`,
which parses each `skills/*/SKILL.md` frontmatter block with PyYAML and fails
when it is invalid YAML, lacks a non-empty `name` or `description`, or names a
skill other than its directory. It signs off with the number of skills
checked. `scripts/` is not in `dist.include`, so the check does not ship.
