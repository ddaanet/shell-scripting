# 2026-10-29 — Corrected the second review of the xhigh review fixes

A medium review of the previous correction (see
[the entry](2026-10-29-xhigh-fix-review-fixes.md)) found three defects. Each
probe was re-run first (just 1.46.0, dash, bash); all reproduced.

`skills/just-gotchas/SKILL.md`: the indentation section said a column-0
comment or valid assignment errors on the line below, then that any line of
valid justfile syntax raises no error; both are valid syntax. The silent case
is now narrowed to a line shaped like a recipe header (`for x in y:`,
`else:`), and the paragraph is reflowed to 80 columns. "Diagnosing a token
error" said the error lands on a line that looks inert; it can land on the real
code line below a column-0 comment or assignment, so the section now tells the
reader to check the line above the reported one too.

`skills/shell-gotchas/references/portability.md`: the GNU-only `stat` gate
skipped only short options before `-c` or `--format`, so `stat --dereference
-c %a f` and `stat --dereference --format=%a f` passed. The skip group now
accepts long options too (`--?[A-Za-z-]+`); the gate still flags every earlier
positive case and none of the negatives, under dash and `bash -o pipefail`,
and stays shellcheck-clean.

`TODO.md`: the release item now records the review state of `dev` and that
every commit after the xhigh review needs its own medium review before the
release. A new item asks to re-ground the `environments.md` claim that git
exports `GIT_COMMON_DIR` to a hook in a linked worktree, which a pre-commit
probe on git 2.47.3 did not reproduce.

Declined as low: the 99-column line in the just skill (now reflowed with its
paragraph); the gate snippet's bare global `s`; and the `robustness.md` bullet
lacking a `!` example and repeating the `!` fact.
