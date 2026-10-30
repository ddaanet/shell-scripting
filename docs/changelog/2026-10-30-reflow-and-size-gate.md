# 2026-10-30 — Markdown wrapped at 80 columns, with a formatter and size gate

`environments.md` kept each paragraph on one physical line, so its 153 lines
understated its size against the 400-line cap by about 2.5x. The in-scope
Markdown is now hard-wrapped at 80 columns, and `just precommit` keeps it so:
`rumdl fmt --check -q --no-cache .` first, then `scripts/check-size.sh`, which
counts lines with `awk` and fails with `<path>: oversized-file: <n> lines > <cap>`
past 400 (200 for a `skills/*/SKILL.md` hub). No file exceeds its cap after the
reflow, so nothing is split; the two files nearest the cap are
`environments.md` and `portability.md`.

`.rumdl.toml` enables MD013 only, in `normalize` mode, and excludes the
write-time records, `plans/`, `inbox/`, `memory/`, `plugin-dev/`, `TODO.md` and
`TASK.md`. `TASK.md` is not in the plan's exclude list; it is a transient task
note, excluded like `TODO.md`. `rumdl` and PyYAML come from `uv sync`
(`pyproject.toml` dev group, committed `uv.lock`), put on `PATH` by `.envrc`;
`/.venv/` is ignored. The `CLAUDE.md` Commands note and `design.md` (NFR6, D10,
limitation 10) state the gate.

Rationale and measurements are in `plans/2026-10-30-reflow-and-size-gate.md`.
