## Open decisions

- Whether to apply the `plans/2026-08-13-hook-index-handoff-brief.md` correction to `skills/shell-gotchas/references/environments.md`, given that the `ddaanet` tier's `git-hook-env-leak.md` already states the save/restore idiom (capture `GIT_INDEX_FILE` before the blanket `unset $(git rev-parse --local-env-vars)`, restore it for the staging `git add`). Verified on git 2.47.3: `git commit` hands the hook `.git/index`, `git commit -a` hands it `.git/index.lock`, `git commit -- <paths>` hands it `.git/next-index-<pid>.lock`. In the two lock modes the add dies on `fatal: Unable to create '.git/index.lock': File exists`; no mode reproduces the silent mis-staging that the current bullet describes, so the brief's own framing of it as one-of-three-modes is wrong too. Three ways to go: apply the full correction, apply only the failure-mode fix and leave the idiom to memory, or drop it and delete the brief.
- Whether to shorten the `ddaanet` tier's index lines. `memory/MEMORY.md` sits at ~110% of the 25600-byte budget, so its tail falls past Claude Code's 24.4KB loader cutoff and never reaches a session. The fix is not local: it changes what every repo mounting the tier loads.

## Remaining

- Add to the tier's `claude-plugin-dev.md` the kernel lost with the deleted `plugin-dev-subtree-updates.md`: run `just --list` immediately after a subtree pull, and land any consumer-side fix as its own commit separate from the merge commit.
