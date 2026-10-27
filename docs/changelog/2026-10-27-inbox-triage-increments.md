# 2026-10-27 — Landed the 2026-10-26 inbox triage increments

Seven briefs had accumulated in `inbox/`. Three read-only triage passes
(`plans/2026-10-26-inbox-triage/`) probed each claim and recorded a verdict
and exact wording; this entry records what landed from them. Several claims did
not survive probing and were corrected before landing, so the text differs from
the briefs where the reports said so. The briefs are deleted; the reports stay
in `plans/`.

`references/robustness.md` § Exit status and `set -e`: the "off inside
conditions" bullet no longer over-generalises. `-e` is suspended for every
element of an AND-OR list except the last, so a recovery arm
(`check || { a; b; die …; }`) is armed: a failing `a` exits with its own status
and the refusal message never prints. A substitution used as an argument
(`[ -z "$(cmd)" ]`, `echo "$(cmd)"`) turns a failed `cmd` into empty data, and
`exit` inside `$( )` ends only the subshell. The brief's claim that no linter
sees the second one was wrong: optional SC2312 flags it under `--enable=all`,
so it got a reference bullet and no `SKILL.md` row. The first got a `SKILL.md`
row. The `read -d ''` bullet notes that its `LC_ALL=C` prefix is a no-op on
bash 3.2.

`references/portability.md`: new `### wc` (BSD padding, fatal to string
comparison and invisible to `-eq`; `grep -c ''` is not a drop-in because it
counts an unterminated last line), `### macOS libc and non-ASCII bytes`,
`### macOS $TMPDIR` (symlinked, slash-terminated), a `tmp.$$` bullet under
`### mktemp`, and a sibling entry after the bash 3.2 entry for three silent
3.2 misbehaviours. The 3.2 and macOS-libc claims rest on the briefs' own
evidence; this box had no macOS and no bash 3.2. The `source` claim is scoped
with the POSIX-mode rule, which was verified. "Locking fixes in" gains the
limit of PATH stubs and a per-file static check for GNU-only `stat`.

`references/environments.md`: the staging recipe for a hook that unsets the
repo-local environment and still has to `git add` (restore `GIT_INDEX_FILE`,
tolerate it being unset), with its pathspec-mode aftermath and a test shape.
The brief's "targets the wrong index" clause is dropped, per the 2026-09-02
correction: the failure is loud and only in the two lock modes. New bullets on
fd 0 under the Bash tool (the brief's "a read returns EOF at once" is false for
the socket case, where it blocks) and on `pwd -P` plus the PATH-strip wrapper
loop that hangs on a `//` entry.

`references/bats.md`: `BW02` as a to-fix (only the behaviour that reproduced on
bats 1.14.0 is stated, not the 1.11 versus 1.14 `$stderr` difference the brief
claimed), a section on `grep -c` over JSON and `jq -r` printing `null`, and a
pointer to the fd 0 note.

Declined: the https submodule-urls brief. The published artifact is the `dist`
branch, whose allowlist carries no submodule, so keyless `/plugin install`
already works; the edit would also write into the memory submodule. The bash
3.2 build and run recipes are tooling for the originating repo, not a failure
mode of shell code.
