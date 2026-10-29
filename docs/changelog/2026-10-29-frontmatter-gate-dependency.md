# 2026-10-29 — Declared the gate's PyYAML dependency; restored the user-site note

A medium review of the plain hint (see
[the entry](2026-10-29-frontmatter-hint-plain.md)) found that dropping the
user-site note was not a consequence of dropping the routing, as that entry
says: the note keyed on `sys.flags.no_user_site`, which `python3 -I` always
sets, so a reader following the plain hint with `pip install --user` would
install PyYAML where the gate never looks. The hint again says the install
must be outside user site-packages when user site is off.

The same review found the gate's PyYAML requirement declared nowhere. The
`CLAUDE.md` Commands block now lists `just precommit` with what it runs and
needs: `jq`, `shellcheck`, and PyYAML importable by `python3 -I`.

Declined as low severity: recording the no-routing decision in
`docs/design.md`, which describes the plugin rather than its development gate;
and the hint line's length.
