# 2026-10-29 — Recipe-header-shaped column-0 lines can error too

A medium review of the second round of xhigh fixes (see
[the entry](2026-10-29-xhigh-fix-review-2-fixes.md)) found that
`just-gotchas` called a column-0 recipe-header-shaped line silent, while a
repeated one (two `else:` lines in a pasted Python body) gives ``Recipe `else`
first defined on line 4 is redefined`` and a deeper-indented line under one
gives `Recipe line has extra leading whitespace` (both probed, just 1.46.0).
The indentation section now names both, and the diagnosis section lists them
among the parse errors the bug surfaces as.

Declined as low severity: the GNU-only `stat` gate missing a `--opt=value`
long option before `-c` and flagging `stat -- -c`, spellings nothing in
practice writes, and the earlier entry's claim that long options are skipped,
which holds for the bare form; and replacing the gate's ERE with an awk
tokenizer. The gate is a heuristic whose Limits paragraph says so; further
regex rounds on it are not planned.
