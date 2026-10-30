# 2026-10-30 — Size gate: review fixes

The medium review of the reflow and size gate found four things to correct.

`scripts/check-size.sh` failed the whole gate on a tracked file deleted from the
work tree but not yet staged, since `git ls-files --cached` still lists it and
`awk` cannot open it. A deletion is not a size violation: the script now skips a
path that no longer exists, and the summary counts only files it measured.

The `precommit` guard for a missing `rumdl` said only `run uv sync`, but once
`.venv` exists the usual cause is a shell where direnv has not loaded `.envrc`;
the message now names both `uv sync` and `direnv allow`.

In `docs/design.md`, NFR6 called the gated files "shipped", while the gate covers
every tracked or untracked-but-not-ignored Markdown, shell and Python file
outside the exclusions, shipped or not; it now states that rule. D10 claimed
that an unwrapped long line in a code block or table "cannot hide size"; such a
line counts once however long it is, so it understates size, and D10 now says
so. `CLAUDE.md` Layout's decision range now reads D1–D10.
