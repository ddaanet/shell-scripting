# 2026-10-30 — The hook's own `cd`: per-layout claims dropped

A medium review of the [hook-cd-rule](2026-10-30-hook-cd-rule.md) entry's
change disproved its claims again: a relative `GIT_DIR` does not always fail
loudly, a `.git` directory can receive a `GIT_DIR` the caller never passed,
and the `$start`-is-the-top exception was not the only case. Four rounds had
each predicted outcomes per layout that the next review's probes contradicted,
so the claims are dropped rather than refined.

`environments.md` keeps only what the recipe needs, in the second caveat:
under an inherited `GIT_DIR` discovery is off and an unpinned work tree takes
the cwd as its top, so the hook anchors its own git with `git -C "$start"`.
The standalone paragraph, its verified-in list, the relative-`GIT_DIR`
outcome and the recipe's exception sentence are gone, as is the matching
sentence in `design.md` limitation 9. The "no `GIT_DIR`" bullet now holds for
a caller-set git dir or work tree, and the testing advice adds the axis of
with and without a caller-set `--git-dir`/`--work-tree`.
