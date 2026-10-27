# 2026-10-27 — Corrected the re-review findings on the bats-gotchas hub

A re-review of the hub restructure (see
[the hub entry](2026-10-27-bats-hub-and-split-fixes.md)) found four low defects
in the condensed table and the references. The earlier entry stands as written.

`skills/bats-gotchas/SKILL.md`: the out-param row now limits the bare call to
success paths, since a bare call of a function returning non-zero aborts the
test. The `BW02` row no longer files the `$stderr`-unset fact under the missing
declaration: it happens with the declaration too, so the Fix cell states it
independently of the declaration. The `jq` row carries the caveat that
`// empty` also empties `false` (use `has` for booleans), and the test-stdin row
scopes "fd 0 is `/dev/null` or a socket" to Claude Code's Bash tool.

`references/vacuous-passes.md`: the intro no longer claims shellchecking as part
of its trigger surface, and the errexit paragraph points to `run-semantics.md`,
where that section now lives.
