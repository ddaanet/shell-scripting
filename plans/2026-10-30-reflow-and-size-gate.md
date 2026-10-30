# Reflow to 80 columns and a size gate: proposal

Proposal only. Nothing in the repo has changed; all measurement ran on copies
under `$TMPDIR`. The TODO item this answers: reflow the skill references and
docs to 80 columns, and decide whether to wire `rumdl` MD013 reflow into
`just precommit` ahead of an oversized-file check.

## Findings

1. **No file exceeds its cap after reflow.** The largest, `environments.md`,
   goes from 153 to 380 lines against 400. The line counts understated size by
   2.5x there, but the file still fits. No split is forced today.
2. **Two files sit close to the cap and one is being edited.** `environments.md`
   is at 95 percent, `portability.md` at 90 percent. Another agent is editing
   `environments.md` right now; a few dozen added lines crosses 400. A split
   seam for each is proposed below, to be taken when a file crosses, not now.
3. **`rumdl` is not installed on this box.** It installs without touching the
   system: `UV_CACHE_DIR=$TMPDIR/... UV_TOOL_DIR=$TMPDIR/... UV_TOOL_BIN_DIR=
   $TMPDIR/... uv tool install rumdl` gave `rumdl 0.3.2` (needs network to
   pypi.org and files.pythonhosted.org). `cargo` (1.99.1), `pipx` (1.7.1) and
   `uv` are present here; `brew` is not. Every measurement below used 0.3.2.
   For macOS the documented routes are `brew install rumdl`, `uv tool install
   rumdl`, `pipx install rumdl` or `cargo install rumdl`; only the `uv` route
   was run here, so the macOS routes are unverified.
4. **Normalize mode barely differs from the default on this corpus.** Default
   `reflow = true` only breaks over-long lines; `reflow-mode = "normalize"`
   also re-fills hand-wrapped paragraphs. Totals over all 60 markdown files
   measured (in-scope, plans, TODO, inbox): 2,826 before, 4,198 default, 4,185 normalize. The bats files were
   already wrapped near 80, so normalize shaved 1 to 3 lines from each. The
   mode matters for the future (prose hand-wrapped at 60 columns counts about
   1.3x), not for the one-time reflow.
5. **Reflow is idempotent and lossless here.** A second pass changed nothing.
   A whitespace-insensitive word comparison of every file before and after
   differs only in `plans/2026-10-26-inbox-triage/{robustness,environments}.md`,
   where wrapping a blockquote adds a `>` prefix to each continuation line.
   Frontmatter, fenced code blocks and tables kept their line structure in
   every file (fence count and table-row count equal before and after).
6. **Some lines stay over 80 by design.** Code blocks, tables and unbreakable
   tokens (long URLs in link lists) are left alone: 55 such lines in
   `docs/changelog.md`, 29 in `robustness.md`, 26 in `portability.md`. They do
   count in `wc -l`, once each, so they cannot be used to hide size.
   `rumdl` also left 9 lines unwrapped that it could have: `rumdl check`
   reports "Found 9 issues" after `fmt`. Example: in `vacuous-passes.md` a
   code span containing `|` and `…` stops the wrap, leaving a 160-column line.
   So `check` cannot be the gate; `fmt --check` can (finding 8).
7. **`check-refs` is expected to be unaffected, not shown.** It extracts links
   line by line (`plugin-dev/check-refs-parse.sh`, scanning each line for
   `](`); only an open fence, code span or HTML comment carries to the next
   line. rumdl never split a link target, but a break inside link text or a
   code span could change what a line yields. `just check-refs` was not run on
   the reflowed copy (it needs the repo context), so the sequence runs it.
8. **Exit codes, verified in a scratch repo with a root `.rumdl.toml`:**
   `rumdl fmt --check .` exits 1 on the unreflowed tree and 0 on the reflowed
   one, even with the 9 unwrappable lines; `[global] exclude = [...]` skipped a
   long-line file placed under `plugin-dev/` and `memory/`.

## Measured table

Lines before reflow, after default reflow (`reflow = true`), after normalize
(`reflow-mode = "normalize"`), and the cap. SKILL.md hubs cap at 200, all else
at 400. Config: `line-length = 80`, `code-blocks = false`, `tables = false`,
`headings = false`, only MD013 enabled. Files are snapshots taken at the start
of this session.

| File | Before | Default | Normalize | Cap | Of cap |
| --- | ---: | ---: | ---: | ---: | ---: |
| `skills/shell-gotchas/references/environments.md` | 153 | 380 | 380 | 400 | 95% |
| `skills/shell-gotchas/references/portability.md` | 185 | 363 | 363 | 400 | 90% |
| `skills/shell-gotchas/references/robustness.md` | 85 | 249 | 249 | 400 | 62% |
| `docs/design.md` | 84 | 227 | 227 | 400 | 56% |
| `CLAUDE.md` | 70 | 131 | 131 | 400 | 32% |
| `skills/bats-gotchas/references/vacuous-passes.md` | 116 | 116 | 113 | 400 | 28% |
| `skills/shell-gotchas/SKILL.md` | 65 | 107 | 107 | 200 | 53% |
| `skills/bats-gotchas/references/run-semantics.md` | 100 | 100 | 99 | 400 | 25% |
| `skills/just-gotchas/SKILL.md` | 90 | 90 | 89 | 200 | 45% |
| `README.md` | 56 | 85 | 85 | 400 | 21% |
| `skills/bats-gotchas/SKILL.md` | 38 | 43 | 43 | 200 | 22% |
| `skills/bats-gotchas/references/linting.md` | 27 | 27 | 26 | 400 | 7% |

Also measured, none near a cap: the 40 files under `docs/changelog/` total
1,136 lines before and 1,139 after, longest 79. They are out of scope all the
same: dated changelog entries are never revised (`CLAUDE.md`), so neither the
reflow nor the size gate touches them. `docs/changelog.md`, the index, is out
of scope too: `CLAUDE.md` defines it as one line per entry, and reflow would
wrap its pointer lines (50 to 148), so the gate would fail every new one-line
entry. In `plans/` (soft cap):
`2026-10-26-inbox-triage/portability.md` 159 to 302, `.../robustness.md` 124 to
283, `.../environments.md` 76 to 177; the two dated briefs stay at 94 to 98.
`TODO.md` 4 to 16 and `inbox/README.md` 16 to 16.

**Files that would exceed a cap: none.** Source files have no wrapping issue
(`hooks/scripts/shellcheck-on-edit.sh` 86, `scripts/check-frontmatter.py` 53).

## Seams, for when a file crosses 400

Neither is needed now. `environments.md` is being edited concurrently, so any
split of it waits for that edit to land.

- **`environments.md` (380 after reflow).** Section line counts after reflow:
  git hook leakage 13-143, hook execution context 144-166, submodule escape
  167-195, linked worktrees 196-214, parsing git output 215-290, Claude Code
  specifics 291-340, self-location and cwd discipline 341-380. Seam: move
  "Claude Code specifics" and "Self-location and cwd discipline" (about 90
  lines) to a new `claude-code-environment.md` node; the git sections (about
  290 lines) stay. The title already says "Git Hooks, Submodules, Worktrees,
  Claude Code", so the split follows the two halves it names.
- **`portability.md` (363 after reflow).** Seam: "Locking fixes in" (315-363,
  the PATH-shadowing platform-simulation pattern, about 49 lines) to
  `platform-simulation.md`. If more room is needed, "Shell version traps"
  (241-314, about 74 lines) to `shell-versions.md`, leaving the
  command-by-command divergence catalog (about 228 lines) in place.
- **Cost of either split.** No anchor (`#section`) links point into these
  files, so no fragment breaks, and `check-refs` will not catch a stale
  pointer: the path still resolves, only the section has moved. The split
  step therefore updates every inbound citation of a moved section, found by
  grepping for the file names and section titles (excluding `plans/`,
  `memory/`, `plugin-dev/`, `docs/changelog/`). Today that grep finds:
  - routing: `skills/shell-gotchas/SKILL.md` lines 53-55 (a new node needs
    its own routing line there) and line 34 (quick-reference row pointing at
    `portability.md`);
  - "Claude Code specifics" seam: `skills/bats-gotchas/SKILL.md:28` (cites
    `environments.md`, Claude Code specifics, for the test-stdin fact);
    `skills/shell-gotchas/references/portability.md:110` ("see
    environments.md, Self-location"); `docs/design.md:54` (`environments.md`
    covers sandbox probing, `$TMPDIR`, `CLAUDE_PLUGIN_ROOT` self-location);
    `docs/design.md:72` (cites `environments.md` for the test-stdin fact);
  - "Locking fixes in" seam: `skills/bats-gotchas/SKILL.md:30` (cites
    `portability.md` for the static GNU-only check); `docs/design.md:72` (the
    FR4 template "lives in `references/portability.md` under \"Locking fixes
    in\"");
  - "Shell version traps" seam: `skills/shell-gotchas/references/robustness.md:21`
    (pipefail, "see portability.md");
  - by file list: `docs/design.md:23` and `CLAUDE.md` (Layout, What this is)
    enumerate the three reference files, so a new node is added there.

  `skills/bats-gotchas/references/run-semantics.md:94` cites only
  `robustness.md`, which no seam moves. Line numbers are as of this proposal;
  rerun the grep at split time, after the reflow has moved them.

## Risks of reflowing

- **Tables.** With `tables = false` rumdl leaves rows alone (verified: table
  row counts equal in all 60 files). A table row over 80 columns stays over,
  and counts as one line. Wide tables in `SKILL.md` hubs stay wide.
- **Code blocks.** Fences are untouched (fence counts equal). Indented
  four-space blocks were not examined separately; the word-level comparison
  (finding 5) shows no content change.
- **Frontmatter.** The `description:` lines in the three `SKILL.md` files stay
  single-line and byte-identical; `scripts/check-frontmatter.py` would still
  parse them. Run it on the real reflow, not only on this copy.
- **List items.** A wrapped item takes a hanging indent (two spaces under
  `- `); a bold lead (`- **Rule.** text`) stays on the first line. One
  rewrap produced a prose line beginning `0) ` in `docs/design.md`. A line
  starting `1.` in the middle of a paragraph would open a list in CommonMark;
  `0)` does not, so that instance is harmless. The rule for the diff review:
  no continuation line may begin with anything that would start a CommonMark
  block. The scan run here checked only `-`, `+`, `#`, `1.` and `>`, and found
  none besides that one.
- **Blockquotes in plans.** Reflowed with a `>` per line: lossless but noisy.
  The recommended scope excludes `plans/`.
- **Diff noise.** About 2,400 added and 1,100 removed lines across the 60-file
  run (plans included). The recommended scope (excluding `plans/`, `inbox/`,
  `TODO.md`, `docs/changelog/` and `docs/changelog.md`) is 12 Markdown files,
  1,069 lines to 1,912 under normalize. A re-measure on the current working
  tree that still included `docs/changelog.md` gave 327 fixes, 1,406 added
  and 465 removed lines; those three figures were not re-measured without
  it. `git blame` on every paragraph then points at the
  reflow commit. Mitigation: land the reflow as its own commit containing
  nothing else, and add it to `.git-blame-ignore-revs`
  (`git config blame.ignoreRevsFile .git-blame-ignore-revs`; that is one more
  file, so it is a fork for my human partner, not part of the recommendation).
- **Cost to every later edit.** Under `normalize`, any paragraph an agent
  hand-wraps at a different width fails `fmt --check`, and the fix is to run
  the formatter. That is the point of the gate and also its recurring tax.
- **Concurrent edit.** The reflow rewrites `environments.md` wholesale. It must
  not run while the other agent holds uncommitted edits to that file.

## Gate options

All options share the rumdl config below, saved as a root `.rumdl.toml`
(a new file; verified to work through `rumdl fmt --check .`):

    [global]
    enable = ["MD013"]
    exclude = ["plugin-dev", "memory", "plans", "inbox", "docs/changelog/",
               "docs/changelog.md", "TODO.md"]

    [MD013]
    line-length = 80
    reflow = true
    reflow-mode = "normalize"
    code-blocks = false
    tables = false
    headings = false

Two exclusion behaviours were probed on rumdl 0.3.2 in a scratch tree.
`"docs/changelog/"` skips the directory's files and still checks
`docs/changelog.md`, so the index needs its own entry. rumdl honours
`.gitignore`: with `/dist/plugin/` listed there (as in this repo), an over-long file under `dist/plugin/` was skipped by
both `fmt --check .` and `fmt .`, and was flagged once the line was removed
from `.gitignore`. So the built copy under `dist/plugin/` needs no entry in
`exclude`.

- **A. One-time reflow, no gate.** Count is honest once and rots; the next
  crammed paragraph restores the original problem silently.
- **B. Line-count checker only, no formatter.** Cheap, but passes today's
  153-line `environments.md`. That is the defect the TODO names.
- **C. `rumdl fmt` (rewriting) then the checker inside `precommit`.** The count
  is always honest, but a recipe that rewrites files leaves unstaged changes
  after the gate passes; a `git commit` of only the staged files then ships
  the pre-format text that was never checked. Every other `precommit` step is
  read-only.
- **D. `rumdl fmt --check`, then the checker (recommended).** Read-only like
  its neighbours. On a miss it prints the diff and the fix is `rumdl fmt`.
  The size checker runs only on files already at 80 columns, so its counts
  are honest. No extra `fmt` recipe is needed (`rumdl fmt` is the command).
- **E. D plus a `fmt` recipe and a blame-ignore file.** Convenience on top of
  D; each is a new surface to decide separately.

### Recommendation: D, normalize mode

`precommit` gains two lines after `check-refs`, in this order:

    command -v rumdl >/dev/null || { printf '%s\n' 'precommit: rumdl not found; install with one of: brew install rumdl, uv tool install rumdl, pipx install rumdl, cargo install rumdl' >&2; exit 1; }
    rumdl fmt --check .
    sh scripts/check-size.sh

The first line is the missing-`rumdl` guard: without it a bare `rumdl` fails
with the shell's `rumdl: not found` and exit 127, naming no install route.

`scripts/check-size.sh` contract (POSIX `#!/bin/sh`, shellcheck-clean, per the
self-application rule; appended to the `precommit` shellcheck line):

- Precondition: run from the repo root inside a git work tree.
- Files: `git ls-files -z --cached --others --exclude-standard` entries
  ending `.md`, `.sh` or `.py`, minus `plugin-dev/`, `memory/`, `plans/`,
  `inbox/`, `docs/changelog/`, `docs/changelog.md` and `TODO.md`. Untracked,
  non-ignored files are included, so a new node is checked before `git add`,
  as rumdl checks it. NUL-delimited, since filenames can contain spaces; dash's
  `read` has no `-d`, so iterate with `git ls-files -z … | xargs -0 sh -c
  'for f do …; done' sh` (verified under dash). `xargs` may split a long list
  into several runs, so the summary counts the per-file results rather than
  a loop variable. Under the Claude Code sandbox, `--others` also lists the
  sandbox's unreadable phantom `.claude/loop.md` (observed), so `.claude/` is
  excluded too, or the gate runs unsandboxed.
- Cap by path: `skills/*/SKILL.md` 200, everything else 400.
- Postcondition: for each file over its cap, one stderr line
  `<path>: oversized-file: <n> lines > <cap>`; exit 1 if any, else exit 0
  with one stdout line naming the checks that ran and their counts (the
  quiet-gate convention), for example `size: 15 files within caps (hub 200,
  other 400)`. The selection is 14 files today (12 Markdown, the hook
  script, `check-frontmatter.py`); `check-size.sh` itself makes 15.
- Counts with `awk 'END { print NR }' < "$f"`, not `wc -l`: BSD/macOS `wc -l`
  pads its output with spaces, and `wc -l` does not count a final line that
  lacks its newline, so a 401-line file could pass. `awk` counts that last
  line and prints a bare integer on both platforms (verified: `printf 'a\nb'`
  gives 2 where `wc -l` gives 1). It never excludes code blocks or tables:
  they are part of what a reader takes in.

Missing `rumdl` fails `precommit` through the guard line above, as
`check-frontmatter.py` does for PyYAML, not skip silently.
Add `rumdl` to the dependency note in `CLAUDE.md` (Commands) in the same commit.

Sequence if approved: (1) wait for the `environments.md` edit to commit;
(2) one commit holding `.rumdl.toml`, the reflow of the in-scope files
(`rumdl fmt .`), `check-size.sh`, the `precommit` lines, the `docs/design.md`
requirement or decision entry, the dated changelog entry and the `CLAUDE.md`
dependency note; before committing, run `just check-refs` on the reflowed tree
(finding 7). Every commit that lands config or the gate then carries its
docs, per the repo convention.

That single commit cannot be the reflow-only commit that the blame-ignore
mitigation needs. If open question 6 is answered yes, the sequence becomes:
(2a) a reflow-only commit: place `.rumdl.toml` at the repo root, the layout
whose `exclude` was verified (finding 8), run `rumdl fmt .` and `just
check-refs`, then move the config out of the tree before staging, so the
commit adds no file and no config. A config passed by `--config` from
`$TMPDIR` is not used: whether its `exclude` resolves against the config's
directory or the cwd was not probed. (2b) the commit above minus the reflow. Where the reflow's changelog
entry goes, (2a) or (2b), is open question 9.

## Open questions for my human partner

1. Wire the gate at all (option D), or stop at the one-time reflow (A)?
   Default: D.
2. `reflow-mode = "normalize"` (re-fill hand-wrapped prose; every edit may need
   a formatter pass) or the default (break long lines only)? On the current
   corpus the two differ by 13 lines. Default: normalize, per `plan-contracts`.
3. Scope: exclude `plans/` and `inbox/` (soft cap, prospective, not read in one
   go once executed)? Default: exclude. If included, the reflow adds a `>`
   prefix to each continuation line in two inbox-triage plans.
4. Should the size checker also cover shell and Python sources (86 and 53 lines
   today) or only Markdown? Default: all three extensions, at 400.
5. Missing `rumdl`: hard failure (default) or skip with a notice like the
   hook's missing-shellcheck notice?
6. Add `.git-blame-ignore-revs` for the reflow commit? Default: no, since it
   adds a file and a per-clone `git config`.
7. Pin a rumdl version? Config keys and normalize behaviour were verified only
   on 0.3.2, a young tool. Default: document "0.3.2 or newer" in `CLAUDE.md`,
   no pin file.
8. If `environments.md` crosses 400 during the concurrent edit, split at the
   Claude Code seam (above) in that edit, or after? Default: after, as a
   separate commit.
9. If `.git-blame-ignore-revs` is adopted, may the reflow-only commit (2a)
   land without its own changelog entry, recorded by the gate commit's entry
   instead? This bends the "docs in the same commit" rule. The alternative,
   a dated entry inside (2a), breaks "nothing else in the reflow commit" only
   by one new file that blame never attributes paragraphs to. Default: put the
   entry in (2a), since a new file adds no line that blame-ignore would hide.
