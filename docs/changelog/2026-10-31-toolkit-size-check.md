# Size gate: the toolkit's check-size replaces scripts/check-size.sh

The vendored toolkit (0.13.0) ships `check-size`, a byte cap of 20000 per file
and 10000 for a `SKILL.md`. `precommit` now depends on it
(`precommit: check-refs check-size`), and the repository's own
`scripts/check-size.sh` (400 lines, 200 for a hub, `.md`, `.sh` and `.py` only)
is removed, as the migration note directs: the two measures disagree, and a file
can pass one and fail the other.

Bytes replace lines because a line count rewards cramming long lines, and bytes
barely move when text is re-wrapped. D10's argument that a line cap is honest
only against wrapped text therefore no longer grounds the size cap. The
`rumdl fmt --check` step stays in `precommit` for its own sake, and `.rumdl.toml`
keeps its exclusion list.

The toolkit selects differently from the old script: every file git does not
ignore, whatever its extension, minus `plugin-dev/`, a root `plans/`, lockfiles,
binary files and symlinks. The write-time records, `inbox/`, `memory/` and
`TODO.md` are now counted, and no `size.exempt` is needed. NFR6, D10,
`CLAUDE.md` and the `shellcheck` line of the `precommit` recipe are updated to
match.
