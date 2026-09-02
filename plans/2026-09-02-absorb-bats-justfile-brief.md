## Brief: absorb the bats and justfile facts, and reconcile four overlaps

2026-09-02

Source material lives in the ddaanet memory tier, mounted in this repo at
`memory/ddaanet/<name>.md`. Inspected against shell-scripting 0.3.2.

### What to do

Two additions and one reconciliation.

1. Absorb `bats-shellcheck-gotchas.md` (10,223 bytes) as a new `references/`
   node — eight independent mechanical facts about bats and shellchecking it.
2. Absorb `justfile-gotchas.md` (3,626 bytes), and add just recipes to the
   skill's trigger list.
3. Reconcile four ddaanet facts that already overlap the shipped skill. This is
   the part worth doing carefully.

### Why these two belong here

The skill's own description already promises the first one: *"…writing, editing,
reviewing, or debugging shell scripts or snippets — .sh/.bash files, sh or bash
shebang lines, git hooks, **.bats tests**, installers, wrapper/launcher scripts,
**Makefile recipes**, or CI run steps."* `.bats tests` is in the trigger and the
content is not in the skill. `justfile` is not named at all — one word to add,
and the content fits beside Makefile recipes.

Both also fail as memory. gitlore's recall delivers the first 4096 bytes of a
file and stops, so `bats-shellcheck-gotchas` is 40% reachable. Its own opening
line states a task-shaped trigger — *"writing or reviewing bats tests and
shellchecking them"* — which is a skill's job, not an index line's.

### The reconciliation

Four ddaanet facts overlap this skill at four different depths. The overlap is
real but was never decided; make it deliberate.

| memory fact | skill section | overlap |
| ----------- | ------------- | ------- |
| `git-hook-env-leak` (4,004 b) | `environments.md` § Git hook environment leakage | Rule duplicated — verified git 2.47, the `git rev-parse --local-env-vars` fix, the partial-commit and `GIT_AUTHOR_*` caveats. Memory adds the symptom string `index file open failed: Not a directory`, the three-mode `GIT_INDEX_FILE` table, the capture-and-restore idiom, and the regression-test pattern. |
| `submodule-escape-to-parent` (1,466 b) | `environments.md` § Submodule escape to the parent | Rule, the `-e` not `-d` test, and the guard snippet all duplicated. Memory adds gitlore-specific symptoms (bogus 160000 gitlink, `git branch live` landing in the parent) and the linked-worktree detector. |
| `no-stderr-suppression` (2,011 b) | `robustness.md` § Honest reporting, 4th bullet | Near-total, "no linter coverage" included. Memory adds two gitlore defects as evidence. |
| `git-stderr-and-parsing` (5,380 b) | `environments.md` § Parsing git output | **Inverted.** The skill is a three-line stub saying "use plumbing or porcelain". The memory carries which queries are silent on normal absence, `(fetch first)`/`(non-fast-forward)` versus `(pre-receive hook declined)`, `fetch -q` printing nothing on rejection while `push -q` still reports, and `--git-common-dir` being relative in a main worktree with its CDPATH trap. |

The division to converge on, which the first three already approximate:
**the general rule ships in the skill; the error string and the reproduction stay
in memory**, where a tool result surfaces them. Where the skill is thinner than
the memory — the fourth row — promote the content. Where the memory is only a
restatement of what the skill says, it can shrink to the symptom line that
routes a reader here.

### Decisions

- **A `references/` node, not `SKILL.md` body.** bats alone is 10KB; the
  hub-plus-nodes shape this skill already uses is the right one.
- **The description gains just recipes and keeps purpose-first form** — what the
  skill does, then "Use when", then exclusions. Its length is a per-session cost
  in every repo where the plugin is enabled.
- **Do not delete or edit anything under `memory/ddaanet/`.** The tier is shared
  with nine repos and retiring a fact from it is a gitlore-side pass. This brief
  ends at absorbing the content here.

### Constraints

- **Distributed skill text never cites a memory file.** Consumers do not have
  this store, so a `[[wikilink]]` dangles for all of them. Inline the criteria
  instead. Links to resolve: `bats-shellcheck-gotchas` carries
  `[[green-is-not-evidence]]` and `[[hook-output-channels]]`;
  `submodule-escape-to-parent` carries `[[plugin-recurse-clone]]` and
  `[[git-hook-env-leak]]`; `git-stderr-and-parsing` carries three.
  `justfile-gotchas` carries none.
- Release through the vendored `plugin-dev` toolkit, pinning a `dist-vX.Y.Z`
  tag; never hand-edit `plugin-dev/`.
- Never `--no-verify`; run the repo's precommit gate before committing. Do not
  create or switch branches — work on what is checked out.

### Rejected approaches

- **Sending bats and justfile to the new `craft` plugin** with the design-doc,
  plan and test skills. An existing skill already names their trigger, and a
  second skill on the same moment splits it — the reader gets whichever fires,
  not both.
- **Leaving them in memory and trimming under 4KB.** bats is eight independent
  facts sharing one trigger surface; cutting to 4096 bytes means dropping five
  of them.

### Additional context

- gitlore's ddaanet index is 25,505 bytes against a ~24,985-byte loader cutoff,
  so it truncates today. The six lines named above hold 2,042 bytes of it. That
  is a motive for the tier's own curation pass, not a reason to rush this one.
- `justfile-gotchas` was last touched 2026-09-01 and its quoting section
  (`quote()` for data arguments, since interpolation is raw text) applies to
  ddaanet justfiles generally, including this repo's.
