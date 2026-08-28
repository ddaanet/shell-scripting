# 2026-06-11 — Bats files are linted after all (v0.2.0)

A fact-check against documentation overturned the initial "shellcheck has no bats
dialect" claim. Bats support landed in shellcheck v0.7.0 (2019 changelog: "Files
containing Bats tests can now be checked"), and the 0.10.0 man page lists `.bats`
among the auto-detected extensions. Verified live: a `@test` body produced SC2154
and SC2086.

The hook now matches `*.bats` and bats shebangs, and the limitation that claimed
otherwise was rewritten.
