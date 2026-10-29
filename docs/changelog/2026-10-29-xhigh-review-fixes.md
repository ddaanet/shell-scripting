# 2026-10-29 — Fixed the pre-release xhigh review of dev

An xhigh review of `main..dev` before the 0.5.0 release found the defects
below. Each reviewer probe was re-run before fixing (git 2.47.3, bash 5.2,
dash, just 1.46.0); every one reproduced.

`skills/shell-gotchas/references/environments.md`: test (1) under "Testing a
hook that touches the index" exported a bogus `GIT_COMMON_DIR` and
`GIT_OBJECT_DIRECTORY` for every hook, yet the caveats above it tell a hook to
keep git's env for same-repo commands, and such a hook's `git diff --cached`
exits 129 under those values. The bogus pair is now scoped to a hook built
around a blanket unset. The pathspec-mode note said a hook-modified tracked
file shows ` M` afterwards; a probe with the doc's own restore recipe shows
`MM`, with the real index holding the pre-hook content, so a later plain commit
reverts the hook's edit unless the file is restaged. The note now says so.

`skills/shell-gotchas/references/portability.md`: the "GNU-only stat" gate
matched only a literal `stat -c` or `stat --format`, so `stat -L -c`, `stat
-Lc` and `stat --printf` passed. Both of its greps now use an ERE that allows
flags before the format option, probed on positive and negative cases under
bash and dash and shellcheck-clean. The bash remedy for a failed `source` ran
the whole of `f` with errexit off and tested only its last command's status; it
is now `[ -r ./f ] || { set +e; source ./f; exit 2; }; source ./f`, which keeps
bash's diagnostic for a missing file and still runs `f` under `set -e`
(probed on bash 5.2 only). BSD `wc` "right-pads" became "left-pads
(right-aligns)", matching the example.

`skills/shell-gotchas/references/robustness.md`: the claim that a non-final
pipeline stage keeps `-e` is now qualified: when the pipeline is itself a
condition or a non-final `&&`/`||` element, every stage runs with `-e` off.

`skills/just-gotchas/SKILL.md`: a column-0 line in a shebang recipe was said to
break the recipe parse. It ends the recipe instead, and just reads it as
top-level syntax: most such lines fail with `Unknown start of token` or
`Expected …`, but one that is valid justfile syntax (`for x in y:`, `else:`)
silently becomes a new recipe and truncates the shebang one. The body and the
diagnosis section now say so and point at `just --dump`. The `description`
still fits: `Unknown start of token` is what a `.` or a digit in the line
gives, the common case.

`docs/design.md`: D9 now lists `robustness.md` among the `shell-gotchas`
references a sibling links to, from `bats-gotchas/references/run-semantics.md`.

`TODO.md`: the release item claimed every commit since 0.4.1 had had its
review; it now records the branch's review state.

The finding on the skill frontmatter was already addressed by the gate (see
[the entry](2026-10-29-frontmatter-gate.md)).

Declined as low: the `run !` fix offering no alternative for bats < 1.5.0, since
the floor is stated where the fix is given; the bats version-floor fact being
stated in four places; the `plans/2026-10-26-inbox-triage/` file names lacking
a date; and "the user" in a triage plan.
