## Open decisions

- Which bump the release takes. `just release` bumps from the manifest's 0.3.2. The unreleased content adds two `references/` nodes (`bats.md`, `just.md`), promotes `environments.md` § Parsing git output out of a two-sentence stub, corrects the `GIT_INDEX_FILE` failure-mode claim, and adds the `stat` probe-once rule plus a capture-and-match rung in `robustness.md` — new catalogued material rather than fixes alone, which argues for minor (0.4.0) over patch.

## Remaining

- Publish the memory store and the `ddaanet` tier to their own remotes with `/gitlore:push`. Nothing has been published yet; the earlier `/gitlore:merge` only took facts in.
- Run `just preflight`. `ddaa:preflight` aborts on a resting ` M memory` gitlink, which is a known false finding rather than a real blocker — other dirty paths still count.
- If preflight is green, cut and publish the release through the vendored `plugin-dev` toolkit (now 0.7.1, so `update-plugin-dev` also takes no ref and resolves the newest dist tag itself).
