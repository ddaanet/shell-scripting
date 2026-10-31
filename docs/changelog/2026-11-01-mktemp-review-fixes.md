# 2026-11-01 — Corrected the review of the macOS mktemp change

A medium review of the macOS mktemp change (see
[the entry](2026-11-01-macos-mktemp-tmpdir.md)) and the shell-versions split
(see [the entry](2026-11-01-split-shell-versions-reference.md)) found the
defects below. Both entries stand as written; where their wording no longer
holds, this entry says so.

`skills/shell-gotchas/SKILL.md`: rule 2 and the checklist named only the
portability table for the whole-script audit, so the shell version traps moved
to `references/shell-versions.md` dropped out of it. Both now name
`portability.md` and `shell-versions.md`.

`skills/shell-gotchas/references/portability.md`: the GNU/BSD line credited
"BSD" `-t` with building its template from `TMPDIR`. That holds for FreeBSD
only; macOS builds it from `_CS_DARWIN_USER_TEMP_DIR`, so the line now splits
the two, and the macOS mktemp(1) page joins the sources. The earlier entry's
claim that the difference is invisible unsandboxed was wrong: a redirected
`$TMPDIR` is silently ignored with or without a sandbox. The text now says the
two coincide only while `$TMPDIR` keeps its macOS default.

`skills/shell-gotchas/references/robustness.md`: the temp-file bullet said only
"`mktemp` … respect `$TMPDIR`", which a bare `mktemp` does not do on macOS. It
now prescribes the explicit `"${TMPDIR:-/tmp}/name.XXXXXX"` template. That
rewrite dropped the general rule for scratch paths that are not a `mktemp`, so
a second review caught the loss and the clause is back: any other scratch path also goes under
`${TMPDIR:-/tmp}`, never a hardcoded `/tmp`.

Declined as low: the `//` the template yields on macOS (the next
`portability.md` section covers it), the macOS man page's OPTIONS entry for
`-t` contradicting its DESCRIPTION, "on either" after three platforms, "bare"
naming one of the three forms that ignore `$TMPDIR`, and rule 2's trigger
missing dash on Linux, which predates this change.
