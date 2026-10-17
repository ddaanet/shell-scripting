## Brief: what a first full macOS suite run found that the catalog does not carry

2026-09-25

Proposed increments to `skills/shell-gotchas/references/portability.md`
(§"Command-by-command divergence") and `references/bats.md`. Arrived from the
gitlore repo, from the first run of its full unit suite on macOS: 95 failures
out of 677 cases, and then a hang that ended the run at case 677 of 1016.

Four items, in descending order of how much they cost to find. §4 is the
expensive one — it accounts for the hang and for about seventy of the
failures — and is last because it is the least like a catalog entry.

### 1. `wc` has no section, and its output is padded on BSD

The catalog has sections for `paste`, `sed`, `date`, `stat`, `grep`, `find`,
`xargs`, `timeout`, `awk`, `tar`, `sort`, `head`/`tail`, `getopt`, `mktemp`,
`echo`, `test` and checksums. `wc` appears once, in §stat, as the *remedy* for
something else — "**Portable:** `wc -c < file` for size; avoid stat in portable
scripts" — and its own divergence is not stated anywhere.

BSD/macOS `wc` right-aligns its count in an eight-character field, so `wc -l`
emits `       2` where GNU emits `2`. Command substitution strips trailing
newlines and nothing else, so the leading blanks survive into the comparison.
The man page documents none of this — it describes the counts, never their
format — so `man wc` neither warns nor confirms, and `od -c` is the check.

What makes this worth a section is that it is **invisible to the arithmetic
form and fatal to the string form**:

```sh
n=$(find . -type f | wc -l)
[ "$n" -eq 2 ]   # fine everywhere: [ ] strips blanks for -eq
[ "$n" = 2 ]     # true on GNU, false on BSD/macOS
```

Same for `[[ "$n" == 2 ]]` and for a `case`. So a codebase can use `wc -l`
freely for years, have every arithmetic comparison keep working, and break only
at the one site that happens to compare with `=`. In gitlore this was a helper
returning a count that three assertions compared with `=`; the other `wc -l`
call sites in the same tree all used `-eq` and were fine.

Remedies, in the order they seem worth offering:

- `grep -c ''` instead of `| wc -l` — no padding on either platform. Caveat
  worth stating: it exits 1 on a zero count, which matters under `set -e` or
  when the status is consumed.
- `| tr -d '[:space:]'` after `wc`.
- Prefer `-eq` over `=` whenever the operand is a count. This is the cheap
  general rule and probably the headline.

Note `wc -l < file` and `wc -l` on a pipe are both padded on BSD; the
redirect-vs-argument distinction (which suppresses the *filename*) is a
different thing and does not help here.

### 2. §stat is right, and the codebase followed the anti-pattern anyway

Existing text, which this brief is not disputing:

> **Probe the flavor once and memoize it — never per call.** The reflex form
> `stat -c '%Y' "$f" 2>/dev/null || stat -f '%m' "$f"` pays twice: on BSD it
> suppresses an expected error on every single file, and on GNU it suppresses a
> *real* one (missing file, permission denied) and silently falls through to
> the BSD branch, which then fails for a different reason.

Accurate, and gitlore has exactly that reflex form in two test helpers. The
observation worth adding is not a correction — it is about **where the
GNU-only spelling survives**, which is a detection problem the section does not
currently address.

gitlore catches GNU-isms with PATH-shadowing stubs: a `sed`/`grep`/`mktemp`
stand-in that enforces the BSD contract and fails on the GNU invocation, so a
Linux run goes red instead of the next Mac user. That mechanism reaches only
tools a script under test **execs**. A `stat -c '%a'` written directly in a
`@test` body is called by the test process itself, is never shadowed, and no
Linux run can fail on it. It sat there until a Mac ran the suite.

Suggested addition to §stat, or to `bats.md`: when a portability guard is a
PATH stub, say what it cannot see, and pair it with a static check for the
spellings that live outside script bodies. A per-*file* rule is enough and has
no false positives from the probe itself:

```sh
# every file reaching for GNU stat also carries the BSD spelling
grep -rl -e 'stat -c' -e 'stat --format' --include='*.sh' --include='*.bats' . \
  | while IFS= read -r f; do grep -q 'stat -f' "$f" || echo "GNU-only stat: $f"; done
```

Per file rather than per line, because the memoized probe the section
recommends writes a bare `stat -c '%Y' .` on a line of its own.

### 3. `bats.md` — the version declaration's fallback is not stable

Severable from the rest of this brief. Flagged, as is §4, because this skill is
now the only place either is written down: the originating repo held both as
memory facts and dropped them on the grounds that a skill whose remit is
GNU/BSD divergence and bats gotchas owns them. A decision not to take them here
loses them.

`bats.md` line 33 mentions `bats_require_minimum_version 1.5.0` as a
parenthetical on `run !`. What it does not say is that **the fallback when the
declaration is missing is not stable across bats versions**. bats 1.11 emits
warning `BW02` and populates `$stderr` from `run --separate-stderr` anyway;
bats 1.14 emits `BW02` and leaves it unset, so the suite dies on
`stderr: unbound variable` under `set -u`.

The consequence is that a suite is green on one machine and red on another with
no change to the code under test, and the usual first sighting is a run on a
second platform, where it gets blamed on the platform. That is what happened
here — two failures initially filed under "macOS", actually Homebrew's bats
1.14 against the Linux box's 1.11.

Worth stating: `BW02` in the warnings block is a failure in waiting, not noise,
and the sweep is for the whole class, since the tolerated ones are silent.

```sh
for f in tests/*.bats tests/helpers/*.bash; do
  grep -qE '(^|[[:space:]])run (!|-)' "$f" \
    && ! grep -q bats_require_minimum_version "$f" && echo "$f"
done
```

A helper `.bash` calling `run` with a flag needs the declaration in every suite
that loads it, not in the helper.

### 4. macOS `$TMPDIR` has two shapes at once, and one of them hangs a wrapper

No section covers this. `$TMPDIR` appears twice — `environments.md` says "use
`$TMPDIR`, not `/tmp`", `portability.md` §mktemp gives the portable template —
and neither mentions the shape of the string macOS puts in it:
`/var/folders/<hash>/<hash>/T/`. Two properties, causing failures that look
unrelated.

**Reached through a symlink.** `/var` is a symlink to `/private/var`. Git
reports worktree paths with symlinks resolved and so does `pwd -P`, while
`$PWD` and a raw `mktemp -d` keep the logical form, so anything comparing the
two sees one directory spelled twice. The symptom is a wall of assertion
failures that each look like a separate bug — `[[ "$output" == *"$TMP_REPO"/…*
]]`, `[ "$out" = "$TMP_REPO/.claude/x" ]`, `git worktree list` missing a path
that is plainly there. About seventy of the ninety-five.

The fix belongs at the fixture layer, once, not per assertion:
`TMP_REPO="$(cd "$(mktemp -d …)" && pwd -P)"`. Per-assertion fixes lose,
because the assertion count only grows.

It reaches shipped code too, which is why this is not purely a test concern. A
repo-root check written `[ "$PWD" = "$(git rev-parse --show-toplevel)" ]`
refuses a caller standing at the root of a symlinked checkout, telling them to
go where they already are. `environments.md` already discusses
`--show-toplevel` under inherited `GIT_DIR`; this is a second way that command's
answer surprises, and may belong beside it.

**Ends in a slash.** So every path built as `"$TMPDIR/name"` carries a `//`.
Cosmetic until something compares path strings, because `cd`+`pwd`
canonicalizes a `//` away while a raw string keeps it.

The expensive case is a wrapper that strips its own directory from `PATH` and
`exec`s the next match — a `claude`/`git`/`docker` shim, the shape where
`command -v` after a self-strip is the whole mechanism. `self` from `cd`+`pwd`
is canonical, the `PATH` entry built from `$TMPDIR` is not, the strip misses,
`command -v` finds the wrapper again, and the `exec` re-enters it. That is an
**infinite loop, not a failure**: no test reports it, the suite simply stops,
and a whole run dies to a SIGINT with no indication of where. Resolve each
entry rather than matching spellings:

```sh
newpath=; oldifs=$IFS; IFS=:
for d in $PATH; do
  if [ -d "$d" ]; then n=$(cd "$d" && pwd -P); else n=$d; fi
  [ "$n" = "$self" ] || newpath="${newpath:+$newpath:}$d"
done
IFS=$oldifs
```

with `self=$(cd "$(dirname "$0")" && pwd -P)`. That covers the trailing slash,
the `//`, a `..` and a symlinked duplicate in one pass. A second physical
*copy* of the wrapper elsewhere on `PATH` stays uncovered — no sentinel
separates that re-entry from an ordinary nested invocation — so the bound is
worth stating rather than half-enforcing.

**Both reproduce on Linux**, which is the part most worth carrying: neither
needs a Mac to find, or to verify a fix against. Run the suite with
`TMPDIR="$link/"` where `$link` is a symlink to a real directory — the trailing
slash exercises the second property at the same time. For the loop, put the
wrapper's directory on `PATH` with a doubled slash and invoke it under
`timeout`; a hang exits 124. Both were found this way after the fact, on Linux,
from the macOS failure list.

### Evidence

The `wc` and `stat` failures are observed, from a real macOS run: Darwin
25.6.0, `/bin/bash` 3.2.57, bats 1.14.0 under Homebrew's bash 5.3.15, `PATH`
narrowed to `/usr/bin:/bin:/usr/sbin:/sbin`. The failing assertions were
`[ "$(states)" = 1 ]` / `= 0` against a `find … | wc -l` helper, and
`run stat -c '%a' f` expecting `640`.

The padding was then probed directly on that Mac, because the failures alone
did not distinguish "the count is formatted differently" from "the count is
different" — and the second would have meant a real behavioural difference in
the code under test, which the `tr -d` remedy would have masked rather than
fixed:

```console
$ printf 'a\nb\n' | wc -l | od -c        # macOS 26.6
0000000                                2  \n
0000011
```

Nine bytes: seven spaces, `2`, newline. GNU coreutils emits an unpadded `2`
both from a pipe and from `< file`.

### Not proposed

- No change to §stat's memoize-the-probe advice. It is correct and the
  detection point above is additive.
- No new `timeout` content, though it came up: macOS has no `timeout`, which
  §timeout already says. Bounding a hang-prone call in a bats test needs a
  watchdog subshell instead, and that may belong in `bats.md` — but it is a
  separate brief, not this one.
