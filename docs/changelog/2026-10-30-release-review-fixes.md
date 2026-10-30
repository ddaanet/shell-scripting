# 2026-10-30 — Pre-release review fixes

The pre-release review of `dev` against `main` found two things to correct.

NFR6 in `docs/design.md` said the gate covers every Markdown, shell and Python
file, but `scripts/check-size.sh` selects files by extension, so a `.bats` file
or an extensionless shell script is never measured. NFR6 now names the
extensions the script selects: `*.md`, `*.sh` and `*.py`.

The `shell-gotchas` hub row for a git hook running git after a `cd` still
explained the trap as an absolute value surviving and a relative one
re-resolving. `environments.md` had dropped that split for the hook's own `cd`
after a probe reproduced the mis-stage with only absolute values inherited; it
holds only for `git -C /other/repo`. The row's trap cell now drops the
mechanism, and its fix cell is unchanged.
