# 2026-10-28 — Added `inbox/` for briefs from other repositories

Recorded from the commit of the same day. Briefs arriving from sessions in other
repositories had no home: dropped at the repo root they read as tracked project
documents, and `plans/` is for this repository's own prospective work.

`inbox/README.md` explains the directory: where such a session drops a brief,
note or finding, and that triage ends by landing the content in a skill and
deleting the file, declining it with the reason recorded, or promoting it into
`plans/` when it becomes scheduled work. The README exists because git does not
track empty directories. `CLAUDE.md` gains an `inbox/` line under Layout. The
commit also cleared `TASK.md` and left `TODO.md` carrying the 0.5.0 release and
the post-release memory reduction.
