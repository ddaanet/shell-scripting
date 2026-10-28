# 2026-10-28 — Corrected the pre-release review findings

Before the 0.5.0 release, a Codex adversarial review and a `/code-review` of
`main..dev` produced findings against the skill text. Each was checked by a
probe (bats 1.14.0, bash 5.2, dash, shellcheck) or a primary source before
anything was changed; the fixes below are the ones that held.

Two claims rest on documentation rather than a probe on this machine, which has
no bash 3.2 and no bats older than 1.14.0. That a failing `[[ ]]` or `(( ))`
does not abort a test on bash < 4.1 comes from bats-core's gotchas page, which
prescribes `|| false`. That `bats_require_minimum_version` exists only from bats
1.7.0 (command not found on 1.5-1.6) comes from the bats manual.

`skills/bats-gotchas/`: the helper-through-`run` row and section now say the
`unbound variable` failure was observed on bats 1.11.1 and does not reproduce on
1.14.0 (the same shape sees both local and exported variables), so a suite
spanning bats versions should not rely on the helper seeing them. The example
drops `--separate-stderr`, which raised `BW02` without the declaration and was
irrelevant to its point. The `bats_require_minimum_version` rows state the
1.7.0 floor for the function itself. The errexit row and section are scoped to
bash >= 4.1, add `(( ))`, and give the bash 3.2 exception with `|| false` as the
fix (`[ ]` is unaffected). The bare `! cmd` wording changes from "skipped" to
"runs, side effects included, but its inverted status is discarded", which the
probe showed. The "passes silently when last on bats < 1.5" clause is removed:
bats-core's gotchas page says a final `! cmd` propagates its status as usual,
and bats 1.14.0 fails a test ending in `! true`; only the non-final case is a
trap.

`skills/shell-gotchas/references/portability.md`: the GNU-only `stat` gate
failed a clean tree under `set -o pipefail`, because grep exits 1 on no match;
the grep is wrapped in `{ … || [ $? -eq 1 ]; }`. The text states the remaining
limits: a grep error (exit 2) prints to stderr but fails the gate only under
`pipefail`, and a filename containing a newline is split in two.

`skills/shell-gotchas/references/environments.md`: the PATH-strip loop died
under `set -e` on an entry it could not enter; it now keeps that entry
unresolved. An empty entry is treated as the cwd (`d=${d:-.}`), and the text
says only a trailing empty entry is dropped by the field split; a leading or
middle one survives as `.`. The
hook-staging excerpt moves its `disable=SC2046` directive onto its own line
above `unset`, since the trailing comment did not suppress the warning.

`skills/shell-gotchas/SKILL.md`: the recovery-arm row's fix reads "capture and
test: `if x=$(cmd)`" instead of "capture first", which left `x=$(cmd)` armed
under `set -e`.

Declined: moving the `plans/2026-10-26-inbox-triage/` reports. Their directory
is dated and [the increments entry](2026-10-27-inbox-triage-increments.md)
keeps them in `plans/`. The newline-in-filename split in the `stat` gate is
stated as a limit rather than fixed.

A further xhigh review of these collected fixes found twelve more defects in the
text; each was probed (bash 5.2, dash, bats 1.14.0, shellcheck 0.10.0) and all
held:

- `portability.md`: the "safe" `[ -r f ] || exit 2; . f` fails in POSIX mode,
  since `.` searches `PATH` for a name without a slash (dash: `.: f: not
  found`); the snippet and the bash variant now use `./f`. The `stat` gate's
  consumer is a subshell, because a brace group ending in `exit` terminates the
  caller where the last pipeline stage runs in the current shell (bash
  `lastpipe`, ksh). The limits sentence states that `stat -f` also matches GNU's
  `--file-system`, a false negative.
- `environments.md`: the leading-empty-entry claim was wrong (`P=":/a::/b:"`
  splits into `[][/a][][/b]`), now corrected as above. The loop's `cd` runs as
  `CDPATH='' cd --`, because under a set CDPATH a relative entry made `cd` print
  and the captured path doubled, so the wrapper's own directory was not stripped
  (`CDPATH=` with a space fails ShellCheck SC1007).
- `robustness.md`: the closing `pipefail` bullet gave the wrong cause; without
  `pipefail` a pipeline's status is its last stage's, so an earlier failure
  never reaches the `||`.
- `bats-gotchas`: the errexit exemption list (hub row and `run-semantics.md`)
  gains a command substitution used as an argument (`[ -z "$(false)" ]` passes
  on bats 1.14.0), and the `run-semantics.md` command list gains `(( … ))`
  (aborts on 1.14.0). The `run-semantics.md` header separates what was probed
  from the bash 4.1 boundary, which is from the bats-core docs. The
  1.5-1.6 sentence no longer contradicts itself: load bats-backports there, or
  do not declare. The "Verified against Bats 1.11.1" headers now say probed on
  1.11.1 and 1.14.0, with version floors from the docs. ShellCheck 0.10.0
  reports SC2314 as `style`, not a note, when `! cmd` is the last line.
