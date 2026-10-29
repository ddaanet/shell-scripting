## Remaining

- Release the inbox triage increments, the three-skill split (shell-gotchas, bats-gotchas, just-gotchas) and the bats-gotchas hub restructure: a minor bump (0.5.0, new skills) through the vendored `plugin-dev` toolkit. The xhigh review of `main..dev` has run and its findings are fixed; before releasing, confirm each commit landed after it has had its medium review.
- After the release ships, reduce `memory/ddaanet/bash32-macos-traps.md` to its bash 3.2 build-and-run recipe: its trap bullets now live in `skills/shell-gotchas/references/portability.md`. Rewrite its index line to match. Not before: until the release, consuming repos have those traps only in memory.
