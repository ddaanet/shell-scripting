# 2026-10-29 — Stated the bats version floors for `run` flags and the declaration

A medium review of the fifth round's fixes (see
[the entry](2026-10-29-fifth-review-fixes.md)) found that the bats skill still
prescribed `bats_require_minimum_version 1.5.0` where it fails. The earlier
entry stands as written. It marked the advice to skip the declaration on
1.5-1.6 as unverified; the upstream bats-core CHANGELOG, section [1.7.0],
resolves it: `BW02` ("run uses flags without proper
`bats_require_minimum_version` guard", #587) and `bats_require_minimum_version`
itself both start at 1.7.0.

The rule now stated: `run` flags need bats >= 1.5.0; on 1.5-1.6 use them
without declaring (there is no warning to silence, and declaring fails with
`bats_require_minimum_version: command not found`); on 1.7+ declare. A suite
spanning both can load bats-backports.

`skills/bats-gotchas/references/run-semantics.md`: the `BW02` section states
the rule, cites the CHANGELOG for the version, and drops the unverified skip
clause.

`skills/bats-gotchas/SKILL.md`: the `! cmd` and `BW02` Fix cells make the
declaration conditional on bats >= 1.7.0 and point bats < 1.7.0 to
`run-semantics.md`.

`skills/bats-gotchas/references/vacuous-passes.md`: the `run !` paragraph no
longer prescribes the declaration unconditionally.

Declined as low severity: the `≥`/`>=` notation nit (fixed in passing, the
Fix cells now use `>=`) and bundling the memory pointer; nothing else was
raised.
