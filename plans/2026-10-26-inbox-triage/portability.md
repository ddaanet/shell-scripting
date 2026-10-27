# Triage: two inbox briefs vs current skill text

Repo untouched. Scratch work in /tmp/claude/inbox-triage/scratch.
Checked: `git log` on references/ (last content commit 3b1d0ef; both briefs were filed in 87e80d0), the current text of portability.md (136 lines), bats.md (193), environments.md (122), robustness.md (83), SKILL.md.
Neither brief has landed in any form.

Verification limits on this box (Linux, bash 5.2.37, dash, shellcheck 0.10.0, bats 1.14.0):
- No macOS and no bash 3.2 binary. A 3.2.57 build was not attempted because the tarball host is outside the sandbox allowlist, so every 3.2-specific and BSD/macOS-specific claim below is unverified here and rests on the briefs' own evidence.
- Verifiable and verified: shell semantics of the padded-count comparisons, shellcheck silence, the bats behaviour, the TMPDIR/symlink/slash mechanics, and the PATH-strip infinite loop and its fix.

Size: portability.md goes from 136 to about 185 lines if everything is accepted, bats.md from 193 to about 200, environments.md from 122 to about 132. No node nears 400. SKILL.md is already at 1270 words against a stated ~900 (design.md says ~1100); add nothing to it from either brief.

---

## Brief A: brief-bash32-behaviour-traps.md (2026-10-15)

Overall: accept with changes. Not present anywhere. Shellcheck flags none of items 1-5 (checked a script containing `LC_ALL=C printf %q`, `printf -v … '%b' ""`, `source ./missing || exit 2` and `"‘$p’"` with `--enable=all -s bash`: only unrelated SC2034/SC1091/SC2250 style hits; the `‘$p’` glue is not flagged).

Placement: the brief's decision stands. A sibling entry directly after "macOS /bin/bash is bash 3.2" in § Shell version traps for items 1-3, and the macOS ctype material (items 4-5) as its own entry under § Command-by-command divergence (after `### awk`), with a one-clause pointer from the 3.2 entry. Cost is about 12 lines for the sibling entry and 8 for the libc entry.

### Item 1: temporary `LC_ALL=C` before a builtin is ignored on 3.2
- Status: not present. Related existing text: robustness.md:52 recommends `find … -print0 | while IFS= LC_ALL=C read -r -d '' f`. By the brief's mechanism that `LC_ALL=C` prefix is a no-op on 3.2 (`read` is a builtin). It is harmless there because the overshoot bug it guards against is 5.0-5.3 only.
- Correctness: could not verify (3.2 only). Safe forms were checked on bash 5.2: `$(LC_ALL=C; printf %q "$x")` gives `$'\303\251'`, and the prefix form works on 5.2 as expected. Brief cites the 3.2.57 source (`assign_in_env`, `push_scope (VC_BLTNENV…)`) plus an empirical run; plausible and consistent with bash history (hook for special variables on temp env was added in bash 4).
- Verdict: accept. Observed failure mode (3 of 12 suite failures), not caught by shellcheck, easy to write by habit.
- Increment (portability.md, new entry after the 3.2 entry):

```
### bash 3.2 also misbehaves silently (parses, runs, wrong result)
No feature list catches these; found by running a suite under macOS /bin/bash 3.2.57 and confirmed against a 3.2.57 build.
- **A temporary assignment before a builtin skips the locale hook.** `LC_ALL=C printf %q "$x"` (also `read`, `printf -v`) runs under the caller's locale; bash 4+ honours it, and external commands (`LC_ALL=C sed …`) are fine. Use `$(LC_ALL=C; printf %q "$x")`, or save/assign/restore (`saved=${LC_ALL-} had=${LC_ALL+x}` … `unset LC_ALL` when `had` is empty). Not `local LC_ALL=C` — 3.2.0 does not undo it on return.
```
- Companion edit (robustness.md:52, append): "On bash 3.2 the `LC_ALL=C` prefix on the builtin `read` is a no-op; harmless there, since the overshoot bug is 5.x only."

### Item 2: `printf -v x '%b' ""` keeps the previous `printf -v` buffer
- Status: not present. Verified here only that bash 5.2 sets `b=` (empty) correctly, i.e. the trap is 3.2-specific as claimed. Shellcheck silent.
- Verdict: accept. Narrow but cheap (one bullet) and silent-wrong-result.
- Increment (same entry, second bullet): "**`printf -v x '%b' \"\"` leaves `x` holding the previous `printf -v` result.** `%s` is fine. Initialise `x=` and skip the call when the argument is empty."

### Item 3: failed `source` exits under `set -e` even when guarded
- Status: not present.
- Correctness: 3.2 behaviour unverified. Verified here, and relevant to the wording: in POSIX mode (`bash --posix`, dash, therefore also macOS /bin/sh, which is bash 3.2 in sh mode) a failed `.` exits the shell regardless of `||`, `if`, or `set -e` (bash 5.2 `--posix`: rc 1, "after" never printed; dash: rc 2). So the brief's "exits under set -e" may partly be, or be indistinguishable from, the POSIX-mode special-builtin rule when the suite ran under `sh`-mode bash. Its safe form (`set +e; source f; rc=$?; set -e; …`) is verified to work on 5.2, but would not help in POSIX mode.
- Verdict: accept with changes. Ask nothing of the originating repo; just scope the claim and add the POSIX-mode sentence, which I verified.
- Increment (same entry, third bullet): "**A failed `source` can exit the script despite a guard.** Under `set -e`, 3.2 exits on `source f || exit 2`, `if ! source f`, `{ source f; } || …` (without `set -e` the `||` works). In POSIX mode (`sh`, dash, `bash --posix`) a failed `.` exits regardless of `||` and `set -e`. Safe: `[ -r f ] || exit 2; . f` (a pre-check works everywhere), or in bash `set +e; source f; rc=$?; set -e; [ \"$rc\" -eq 0 ] || exit 2` to keep bash's own diagnostic."

### Item 4: macOS libc classifies 0x80-0xFF as Latin-1 in a UTF-8 locale
- Status: not present.
- Correctness: unverified (macOS-only; the brief says observed, not documented, and Linux tests cannot reproduce it). Verified: shellcheck does not flag `"‘$p’"`. The mechanism is credible (name-character test uses isalnum on the byte). The claim that it bites under Homebrew bash is the brief's, unverified.
- Verdict: accept, worded as "observed on macOS" rather than as documented fact. Belongs in the command-by-command part, not the 3.2 entry, as the brief says.
- Increment (portability.md, new `### macOS libc and non-ASCII bytes` after `### awk`):

```
### macOS libc and non-ASCII bytes
- Observed on macOS (not in a man page): in a UTF-8 locale libc classifies bytes 0x80-0xFF as Latin-1 printable/alnum, which glibc never does. This is the platform's libc, so Homebrew bash is affected too, and Linux tests cannot reproduce it. Two effects: `printf %q café` leaves `é` raw instead of `$'caf\303\251'`, and bash reads `"‘$p’"` as a variable named `p` plus the first byte of the closing quote (`unbound variable` under `set -u`; ShellCheck does not flag it). Brace any `$name` followed by a non-ASCII character (`${p}’`); run `%q` under `LC_ALL=C` using the subshell form from the 3.2 entry, not the prefix form.
- macOS awk aborts on an invalid UTF-8 byte in its input (`awk: towc: multibyte conversion failure`); `LC_ALL=C awk` avoids it (awk is external, so the prefix works). APFS refuses a non-UTF-8 file name (`mkdir: …: Illegal byte sequence`).
```
- One-clause pointer to add in the 3.2 entry: "(see also macOS libc and non-ASCII bytes)".

### Item 5: awk aborts on invalid UTF-8; APFS refuses non-UTF-8 names
- Status: not present. Unverified (macOS-only). Folded into the item 4 entry above, since the avoidance (`LC_ALL=C`) is the same family. Accept.

### Brief A's "additional context" (building 3.2 on Linux, running bats under a chosen bash)
- Decline for the skill: this is tooling/how-to for the originating repo (`scripts/run-bats-under.sh`), not a failure mode of shell code; it would also need a long build recipe in a catalog node. It stays in sandbox-lies. The memory-retirement note is for that repo (read-only here, no action).

---

## Brief B: brief-macos-suite-run-catalog-gaps.md (2026-09-25)

Overall: accept all four with changes; item 3 trimmed because two of its mechanism claims did not reproduce.

### B1: `wc` output is padded on BSD/macOS
- Status: not present (`wc` appears only as the remedy in § stat).
- Correctness:
  - BSD padding itself: could not verify (no macOS); the brief includes a first-hand `od -c` probe (7 spaces + `2`).
  - Verified on bash 5.2 and dash with `n="       2"`: `[ "$n" -eq 2 ]` true, `[ "$n" = 2 ]` false, `case` does not match. So "invisible to arithmetic, fatal to string" holds.
  - Shellcheck does not flag `[ "$n" = 2 ]` or `case $n` on a `wc -l` result (`--enable=all`: only style/info noise).
  - Brief's remedy 1 has an omission. `grep -c ''` is not a drop-in for `wc -l`: it exits 1 on a zero count (brief says so) AND counts an unterminated last line that `wc -l` does not (`printf 'a\nb' | wc -l` gives 1, `grep -c ''` gives 2). Verified. This must be stated.
  - Extra remedy verified on bash and dash: `n=$(( $(… | wc -l) ))` normalises padded output to a plain integer.
- Verdict: accept with changes. Observed failure, undetectable by shellcheck, and the "one `=` site breaks otherwise healthy code" shape is what a catalog is for.
- Increment (portability.md, new section after `### head / tail`):

```
### wc
- BSD/macOS `wc` right-pads the count (`wc -l` prints `       2`; GNU prints `2`), from a pipe and from `< file` alike. Command substitution keeps the blanks. The man page does not mention it; `od -c` shows it.
- Invisible to the arithmetic form, fatal to the string form: `[ "$n" -eq 2 ]` passes everywhere, while `[ "$n" = 2 ]`, `[[ $n == 2 ]]` and `case` fail on BSD only. ShellCheck does not flag it.
- **Portable:** compare counts with `-eq`; or normalise with `n=$(( $(… | wc -l) ))` or `| tr -d '[:space:]'`. `grep -c ''` is unpadded but exits 1 on a zero count (watch `set -e`) and counts an unterminated last line that `wc -l` does not, so it is not a drop-in.
```

### B2: GNU-only `stat` survives where PATH stubs cannot see it
- Status: partly absorbed. § stat already carries the memoize-the-probe rule (commit fb31450); the brief does not dispute it. The detection point (PATH stubs reach only tools a script under test execs) is not present anywhere; SKILL.md "Locking In a Portability Fix" presents the stub technique with no stated limit.
- Correctness: the limit is true by construction. I ran the brief's per-file grep on synthetic files: it flags a file with a bare `stat -c` (`b.sh`) and a probe-only file (`c.sh`), and passes a file carrying both spellings. Caveats found: (a) the reflex anti-pattern `stat -c … || stat -f …` itself passes, so the check enforces "a BSD spelling exists", not "probe once"; (b) GNU `stat -f` means filesystem status, so a file mixing `stat -f -c %T` and `stat -c` is a false negative; (c) `--include` misses `.bash` helpers, hook files without extension, justfiles.
- Verdict: accept with changes. It earns a place because it is an observed failure and states a limit of the skill's own recommended technique. Put it in the "Locking fixes in" cross-reference at the bottom of portability.md, not § stat (keeps § stat per-command) and not bats.md (not bats-specific). Keep the snippet short with its caveats in one line.
- Increment (portability.md, append to "Locking fixes in"):

```
A PATH stub reaches only tools the script under test execs. A GNU-only spelling written directly in a `@test` body or helper is run by the test process itself, is never shadowed, and no Linux run can fail on it (observed: `run stat -c '%a' f` survived until a Mac ran the suite). Pair stubs with a static per-file check — per file, because a memoized probe puts a bare `stat -c` on a line of its own:

grep -rl -e 'stat -c' -e 'stat --format' --include='*.sh' --include='*.bash' --include='*.bats' . \
  | while IFS= read -r f; do grep -q 'stat -f' "$f" || printf 'GNU-only stat: %s\n' "$f"; done

It confirms a BSD spelling exists in the file; it does not check that the probe is done once.
```
(The brief's `echo` is replaced with `printf` to match the skill's own rule.)

### B3: bats `bats_require_minimum_version` fallback "is not stable"
- Status: partly absorbed. bats.md:33 mentions `bats_require_minimum_version 1.5.0` only for `run !`.
- Correctness, tested on bats 1.14.0 with bash 5.2.37 (the version the brief blames):
  - Reproduced: BW02 is emitted for every flagged `run` form without a declaration (`run !`, `run -N`, `--separate-stderr`, `--keep-empty-lines`).
  - NOT reproduced: "bats 1.14 leaves `$stderr` unset". With no declaration, `run --separate-stderr` populated `$stderr` and `$stderr_lines`, under `set -u`, directly in the test, via a `load`ed helper, and with `-1`/`--keep-empty-lines`. Only a warning appears.
  - NOT reproduced: "a helper needs the declaration in every suite that loads it, not in the helper". A declaration inside a helper `.bash` silences BW02 both when `load`ed at file top level and when `load`ed from `setup()`.
  - Found instead (source and run): in 1.14.0 a plain `run` after `run --separate-stderr` executes `unset stderr stderr_lines`, so reading `$stderr` after a later plain `run` dies under `set -u`. A candidate explanation for gitlore's symptom, but unconfirmed that 1.11.1 differs, and I cannot see their failing test.
  - The brief's sweep one-liner runs; it flags both undeclared files and a helper without a declaration (a false positive when every loading suite declares).
- Verdict: accept with changes. Carry only what reproduced; do not state the 1.11-vs-1.14 `$stderr` difference or the helper rule as fact. If the maintainer wants the version-difference claim, ask gitlore for the failing test and 1.11.1 output first.
- Increment (bats.md, extend the sentence at line 33, about 5 lines):

```
Any flag on `run` (`!`, `-N`, `--separate-stderr`, `--keep-empty-lines`) needs `bats_require_minimum_version 1.5.0`; without it bats prints warning `BW02` and carries on. Treat `BW02` in the warnings block as a to-fix, not noise: which behaviours the fallback keeps is a bats-version matter, so a suite can be green on one machine and red on another with no change to the code under test. A declaration in a `load`ed helper counts (verified, bats 1.14.0). A plain `run` after `run --separate-stderr` unsets `$stderr` (1.14.0), so read `$stderr` before the next `run`.
```
Also refresh the bats.md header version note ("Verified against Bats 1.11.1") only if the maintainer re-verifies the older facts on 1.14.0; the new sentence should name its own version.

### B4: macOS `$TMPDIR` is symlinked and slash-terminated; the wrapper PATH-strip loop
- Status: not present. environments.md:110 only says "use `$TMPDIR`, not `/tmp`"; portability.md § mktemp gives `mktemp "${TMPDIR:-/tmp}/name.XXXXXX"` (which, with a slash-terminated TMPDIR, produces a `//` path); environments.md:36 and :120 contain the `--show-toplevel` and `self=$(cd … && pwd)` material this relates to.
- Correctness. Verified on Linux with `link -> real` and `TMPDIR="$link/"`:
  - `$PWD` stays logical (`…/link/repo`) while `git rev-parse --show-toplevel` and `pwd -P` give the resolved path, so `[ "$PWD" = "$(git rev-parse --show-toplevel)" ]` is false at the root of a symlinked checkout; `git worktree list` shows the resolved path only.
  - `mktemp "$TMPDIR/x.XXXXXX"` with a slash-terminated TMPDIR yields `link//x.…`. (`mktemp -d` with no template does not double the slash on GNU; it is the concatenation that does.)
  - The wrapper loop: a wrapper that computes `self` with `pwd -P`, strips its dir from `PATH` by string comparison, and `exec`s the next `command -v` match loops forever when `PATH` carries `…/wr//`. Reproduced: `timeout 3` returned 124 after 605 re-execs. The brief's resolve-each-entry loop (`pwd -P` per entry) fixed it for both the `//` entry and a symlinked entry (1 exec, correct tool). It is shellcheck-clean.
  - Not verifiable here: that macOS actually yields `/var/folders/<hash>/<hash>/T/` with `/var -> /private/var` (well known, not run), and the "about seventy of ninety-five failures" count.
  - The brief's own bound (a second physical copy of the wrapper stays uncovered) is true by construction.
  - Minor weakness in the loop: it expands `$PATH` unquoted with `IFS=:`, so a PATH entry containing glob characters would glob; ignorable, or add `set -f` around it. An empty PATH entry (meaning cwd) is kept as-is, which is correct.
- Verdict: accept with changes, split by trigger surface so no single node grows lopsided. This is the highest-value item of the four (hang, not failure), and its Linux reproduction recipe is the part most worth carrying.
- Increment 1 (portability.md, new section after `### mktemp`, about 8 lines):

```
### macOS $TMPDIR: reached through a symlink, ends in a slash
- macOS `$TMPDIR` is `/var/folders/<hash>/<hash>/T/`: `/var` is a symlink to `/private/var`, and the string ends in `/`. `$PWD` and a raw `mktemp -d` keep the logical path; `pwd -P` and `git rev-parse --show-toplevel` and `git worktree list` report the resolved one. Path-string comparisons then fail in bulk (observed: about 70 of 95 suite failures, each looking like its own bug), and `"$TMPDIR/name"` carries a `//` that `cd`+`pwd` canonicalises away and a raw string does not.
- Fix once, at the fixture layer: `TMP_REPO="$(cd "$(mktemp -d …)" && pwd -P)"`. A per-assertion fix loses; the assertion count only grows.
- Shipped code is hit too: `[ "$PWD" = "$(git rev-parse --show-toplevel)" ]` refuses a caller already at the root of a symlinked checkout. Compare `pwd -P` to the toplevel.
- Reproduces on Linux: run the suite with `TMPDIR="$link/"` where `$link` is a symlink to a real directory.
```
- Increment 2 (environments.md, "Self-location and cwd discipline", about 8 lines): extend the `self=$(cd "$(dirname "$0")" && pwd)` bullet — "use `pwd -P` when `self` is compared against anything else (a PATH entry, `--show-toplevel`)" — and add the wrapper bullet: a wrapper that strips its own directory from `PATH` and `exec`s the next match must resolve each entry, never match spellings, or `PATH` entries built from `$TMPDIR` (`…//`, symlinked) miss the strip and the `exec` re-enters the wrapper: an infinite loop, not a failure (a whole suite stops with no output). Include the brief's loop (verified, shellcheck-clean) with `self=$(cd "$(dirname "$0")" && pwd -P)`, the stated bound (a second physical copy on PATH is not covered), and the Linux repro: put the wrapper dir on `PATH` with a doubled slash and run under `timeout`; a hang exits 124. Add in the same bullet that `--show-toplevel` is a second place the resolved-path answer surprises (next to the existing GIT_DIR note at line 36).
- Do not duplicate into bats.md; the fixture rule lives in portability.md and the bats-specific shape is one clause: point from bats.md? Not needed.

### Brief B "Not proposed" section
- The watchdog-subshell-for-timeout-in-bats idea is correctly left out; if wanted it is a separate brief, a candidate for bats.md. Nothing to do now.

---

## Combined recommendation

| Item | Verdict | Target | Approx. lines |
|---|---|---|---|
| A1-A3 | accept with changes | portability.md, new entry after 3.2 entry; robustness.md:52 one-line caveat | +12, +1 |
| A4-A5 | accept with changes | portability.md, new section after `### awk` | +8 |
| A extra (build/run recipes) | decline | stays in sandbox-lies | 0 |
| B1 wc | accept with changes (grep -c caveat added) | portability.md, after `### head / tail` | +9 |
| B2 stat detection | accept with changes | portability.md "Locking fixes in" | +8 |
| B3 BW02 | accept with changes (drop the two non-reproducing claims) | bats.md near line 33 | +5 |
| B4 TMPDIR | accept with changes | portability.md after `### mktemp` (+8); environments.md self-location (+10) | +18 |

Doc obligations when landing (CLAUDE.md): a dated entry under docs/changelog/ plus its pointer line in docs/changelog.md; design.md only if the node list or limitations change (they do not). SKILL.md gets nothing new; optionally its line 52 description "bash 3.2 limits" already covers A.
