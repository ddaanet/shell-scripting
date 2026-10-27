# 2026-10-27 — Corrected the review findings on the inbox triage increments

A review of the 2026-10-27 inbox triage landing (see
[the increments entry](2026-10-27-inbox-triage-increments.md)) found one wrong
claim and several smaller defects. This entry records the corrections; the
earlier entry stands as written.

`references/robustness.md`: the "off inside conditions" bullet listed a
non-final pipeline stage as a context where `-e` is disabled. It is not: the
stage's subshell keeps `-e` and stops at its first failure (bash 5.2 and dash
agree), and the parent discards that status unless `pipefail` is set. The
bullet now says so: the stage is silently cut short, and only `pipefail`
surfaces it. The recovery-arm remedy "put the fallible step last" cannot apply
to an arm ending in `die`, so it is now scoped to cleanup arms and the arm
ending in `die` gets the guard (`|| true`, or capture and test); the
`SKILL.md` row carries the guard alone. The `command -v` example in the
substitution-as-argument bullet is dropped: its only failure is "not found", so
it showed no failure mode; the `git ls-files` example stays.

`references/portability.md`: the `printf %q` effect in the macOS libc entry is
rescoped. glibc in a UTF-8 locale also leaves a valid multibyte character raw,
so the difference is confined to lone high bytes and bash 3.2; a test asserting
the `$'…'` form must run `%q` under `LC_ALL=C`. The pointer to "the bash 3.2
entry below" names the entry. The static `stat` check now exits 1 when it names
a file, so it works as a gate.

`references/bats.md`: the intro counts six vacuous passes, naming the two `jq`
ones, and the additions are wrapped at 80 columns like the rest of the file.

`docs/design.md`: the `SKILL.md` size claim is updated to the current word
count.

Not changed: the `CLAUDE.md` figure for `SKILL.md` ("~900 words") is still out
of date. The review declined three rare-state findings (trailing empty `PATH`
entry, non-searchable `PATH` directory, newline in a file name in the `stat`
check).
