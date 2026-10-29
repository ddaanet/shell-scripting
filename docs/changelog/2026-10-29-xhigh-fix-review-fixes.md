# 2026-10-29 — Corrected the review of the xhigh review fixes

A medium review of the xhigh fix commit (see
[the entry](2026-10-29-xhigh-review-fixes.md)) found the defects below. Each
probe was re-run first (just 1.46.0, bash 3.2.57 and 5.2, dash); all
reproduced. The earlier entry stands as written; where its wording no longer
holds, this entry says so.

`skills/just-gotchas/SKILL.md`: a column-0 comment or valid assignment
(`x := "a"`) is reported on the indented line *below* it, as `Expected '@',
'[', comment, end of file, end of line, or identifier, but found indent`; the
body now says the error can point at the next line. The earlier entry said the
`description` still fit because `Unknown start of token` covers the common
case. It does not: `import json`, `print(x)`, `def f():` and `done` all give
`Expected … but found`, so the description now names that error too. The
interpolation section's "Unlike the next two, this one never surfaces as an
error at all" became untrue once the indentation section gained a silent case;
it now says the next two usually surface as errors, each with a silent case.

`skills/shell-gotchas/references/portability.md`: the `source` remedy is now
verified on a bash 3.2.57 build as well as 5.2, and the text says that a
failure inside `f` exits with that command's status, not 2. The GNU-only `stat`
gate matched `stat` inside `--numstat` and `--stat`, so `git log --numstat
--format=%H` and `git diff --stat -c` were flagged; the pattern now requires a
non-word, non-hyphen character or line start before `stat`, accepts tabs as
separators, and is shared between the two greps through a variable. Its
Limits now name what it still misses: an option after the operand (`stat "$f"
-c %a`), and a `stat -f` in a comment exempting the file. Probed under bash
and dash; shellcheck-clean.

`skills/shell-gotchas/references/robustness.md`: the pipeline-stage qualifier
now covers a `!`-negated pipeline, which also runs every stage with `-e` off.

`TODO.md`: the review state named a moving "is getting" status; the item now
says to confirm, before releasing, that each commit after the xhigh review has
had its medium review.

Declined as low, from a medium review of the commit declaring the gate's
PyYAML dependency: the user-site note keyed on the flag rather than
`site.ENABLE_USER_SITE`; the note naming `-I` when `-s` or `PYTHONNOUSERSITE`
set it; the always-true conditional on the gate path; the `CLAUDE.md`
dependency list omitting bash, awk and git; and the two phrasings of the
`--user` rule.
