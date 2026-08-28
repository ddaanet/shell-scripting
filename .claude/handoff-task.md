## Current task

The docs/ + plans/ layout migration is finished. The next thread is the
vendored toolkit: apply `brief-plugin-dev-0.5.3.md` then
`brief-plugin-dev-0.6.0.md` (both at the repo root) to upgrade the
`plugin-dev/` subtree. A third brief, `brief-hook-index-handoff.md`, is
still unread and unscheduled.

## Open decisions

- Whether to add a `.gitignore` entry for `.claude/autorename`. The file
  was just untracked, but the autorename plugin rewrites it every session,
  so a broad `git add` will re-add it. Repo currently has no `.gitignore`
  at all.