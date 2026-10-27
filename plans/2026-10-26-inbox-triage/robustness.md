# Triage: three robustness inbox briefs (2026-10-26)

Repo untouched. Scratch probes in /tmp/claude/inbox-triage/scratch. Versions: GNU bash 5.2.37, dash (Debian), shellcheck 0.10.0, bats 1.14.0, jq 1.7. bash 3.2 is not available here.

Current state: none of the briefs' content has landed. `git log` on the reference files shows nothing on AND-OR bodies, substitution-in-test, `exit` in `$(...)`, fd 0, `$$`, or the jq/grep-c items. `robustness.md` is 83 lines, `bats.md` 193, `environments.md` 122, `portability.md` 136, so the 400-line cap is no constraint. SKILL.md is already ~1270 words against the "~900" in CLAUDE.md, so keep SKILL.md changes to the minimum.

## Summary table

| Item | Status | Verdict | Target |
|---|---|---|---|
| A. errexit armed in last element of AND-OR list (brief `in-and-or-body`; brief-3 item 1) | not present; robustness.md:11 over-generalises | accept (merged, with changes) | robustness.md "Exit status and `set -e`", one revised bullet + one new; one SKILL.md table row |
| B. `[ -z "$(cmd)" ]` turns failure into data (brief `blind-inside-test`) | not present | accept-with-changes (shellcheck claim is wrong) | robustness.md, new bullet after the command-substitution bullet; NO SKILL.md change |
| C. `exit` in `$( )` only ends the subshell (from `in-and-or-body` "Related") | not present | accept-with-changes (fold into B's bullet; the claim needs the "status discarded" qualifier) | robustness.md, same bullet as B |
| D. brief-3 item 2, fd 0 under the Bash tool | not present | accept-with-changes (the "read returns EOF at once" claim is wrong for the socket case) | environments.md "Claude Code specifics", one-line pointer in bats.md |
| E. brief-3 item 3, `$$` shared across `( ) &` subshells | not present (robustness.md:82 says only "use mktemp") | accept-with-changes (low priority; placement and scope) | portability.md `### mktemp` |
| F. brief-3 item 4, `grep -c` on JSON / `jq -r` prints `null` | not present | accept | bats.md, after the `grep -qF` section |

## A. errexit is armed in the last element of an AND-OR list (+ ordering of a recovery arm)

Status: not present. robustness.md:11 says "any command in `if`, `while`, `&&`/`||` chains, or after `!` runs with `-e` disabled — including every function called from there". It quotes the bash manual but cuts the clause that carves out the last element. The brief's target at line 30 is correct for what it describes (the pipeline sits left of `||` inside the substitution); the misleading text is line 11, which line 30 points to with "(see above)".

Correctness, all verified (bash and dash agree unless noted):
- Manual (man bash, `set -e` and the `ERR` trap text) says it directly: errexit is ignored for "part of any command executed in a && or || list except the command following the final && or ||", for the `if`/`elif` test, the `while`/`until` condition, non-final pipeline stages and `!`.
- `set -e; false || { echo before; false; echo NEVER; }` exits 1 after `before`. The jq example in the brief exits 2 (jq's status) with neither marker printed. `true && { false; echo NEVER; }` also exits 1.
- A function in last position behaves the same: `f(){ false; echo x; }`: `false || f` and `true && f` exit 1 with nothing printed; `f || true` and `f && echo y` run `f` to the end ("x" printed), because `f` is then a non-final element or the left of `&&`. Brief-3's three measurements reproduce exactly.
- Recovery-arm ordering: `false || { printf 'report\n' >&-; echo cleanup; }` exits 1, `cleanup` skipped. With `printf … >&- || true` before it, `cleanup` runs and rc=0.
- Limits the briefs do not state (verified, bash and dash): the whole list stays suspended when it is itself a condition or non-final element (`if false || { false; echo REACHED; }; then …`, `f(){ false || { false; echo REACHED; }; }; f || true`, `{ … } && …`), so "armed in the last element" is only true when the list is in an armed context. `if true; then false; echo REACHED; fi` exits 1 (branches are armed). `! { false; echo REACHED; }` runs to the end (negation suspends the whole group).
- Shellcheck: nothing, including `--enable=all` (a `false || { d=$(jq …); echo "$d"; }` handler produced only SC2250). SC2310/2311/2312 do not model this. Row qualifies for the "uncaught" SKILL.md table.
- Observed-failure bar: met (two incidents in claude-plugin-dev's release.sh in one cycle, three reviewers wrong before a probe).

Verdict: ACCEPT, merging the two briefs' overlap and brief-3 item 1 into one revised bullet plus one new bullet.

Increment (robustness.md, "Exit status and `set -e`"):

1. Replace the bullet at line 11 with (keep the existing manual link):

   > - **Off inside conditions, transitively:** commands in an `if`/`elif` test, a `while`/`until` condition, any element of a `&&`/`||` list *except the last*, a non-final pipeline stage, or after `!` run with `-e` disabled — *including every function called from there*. Bash manual: "none of the commands executed within the compound command or function body will be affected by the -e setting." `if`/loop bodies and the last element of an AND-OR list are not conditions (next bullet). Linter: only optional SC2310. (link)

2. Insert directly after it:

   > - **Armed in the last element of an AND-OR list, so a recovery arm is not a safe zone:** `-e` is suspended before the last `&&`/`||`, not within it, whether it is a brace group or a function call. In `check || { detail=$(lookup); printf 'hint: %s\n' "$detail" >&2; die "refusing: …"; }` a failing `lookup` exits with *its* status and neither the hint nor the `die` message prints — a decided refusal becomes a bare crash. `false || f` and `true && f` stop at `f`'s first failure; `f || true` runs `f` to the end. Guard every fallible command in a handler, and order the arm so the step that must happen comes first, the fallible one last or behind its own `|| true`: a failing `report` (closed fd 2, full disk) skips the `cleanup` after it. The whole list is still suspended when it is itself a condition or a non-final element (`if a || { …; }`, `f || true` with the list inside `f`). Verified bash 5.2, dash; no linter coverage.

3. Optional micro-edit at line 30: replace "the substitution sits in a condition (`||`), where errexit is already suspended (see above)" with "the pipeline sits left of the `||`, where errexit is suspended". Not required once line 11 is fixed.

SKILL.md (accept one row, maintainer's call on word budget; the bar is met and the row is not shellcheck-detectable): add to the table after the `v=$(cmd)` row:

> | `cmd \|\| { a; b; die … }` under `set -e` — the last element of an AND-OR list is NOT exempt: failing `a` exits with `a`'s status and `die`'s message never prints | guard each fallible command in the handler; put the fallible step last |

## B. `[ -z "$(cmd)" ]` converts a failure into "empty"

Status: not present. robustness.md:12 covers only failures inside the substitution.

Correctness: mechanism verified. Under `set -euo pipefail`, `[ -z "$(false)" ] && echo A`, `[ -n "$(false)" ] || echo B` and a bare `[ -z "$(false)" ]` all run on and the script exits 0, on bash and dash; `shopt -s inherit_errexit` does not change it. Bare `v=$(false)` aborts rc=1 on both. Also `echo "$(false)"` discards the status the same way (generalisation: only an assignment-only command propagates the substitution's status). Real-world check: `sh -c 'set -e; [ -z "$(git ls-files -- x)" ] && echo untracked'` run outside a repo prints git's fatal and then "untracked".

Brief's shellcheck claim is wrong in part: "nothing flags a substitution inside a test" holds for default shellcheck, but `--enable=all` flags `[ -z "$(git ls-files …)" ]`, `[ -n "$(command -v tool)" ]` and `echo "$(false)"` with SC2312 (info, "Consider invoking this command separately to avoid masking its return value"). SC2311 fires only for function calls, as the brief says. SC2312 does not fire on a plain `v=$(false)` or `w=$(false; echo hi)`. So the new text must cite optional SC2312, and a SKILL.md table row would falsify the table header ("verified uncaught … including --enable=all").

Verdict: ACCEPT-WITH-CHANGES. Reference only; decline the SKILL.md row (the table claim, and the SKILL.md budget; the `v=$(cmd)` row and rule 3 already point at robustness.md).

Increment (robustness.md, new bullet immediately after the "Command substitution does not inherit `set -e`" bullet):

> - **A substitution used as an argument turns failure into data:** only a bare assignment (`v=$(cmd)`) carries the substitution's status, so only it aborts under `-e`. In `[ -z "$(cmd)" ]`, `[ -n "$(cmd)" ] || …` or `echo "$(cmd)"` the status is discarded outside the substitution (`inherit_errexit` does not help), and a failed `cmd` reads as empty output: `[ -z "$(git ls-files -- "$p")" ]` takes the "untracked" branch on a git error, `[ -n "$(command -v tool)" ]` the "not installed" one, silently. Separate the two questions: `if ! out=$(cmd); then …handle failure…; fi; [ -n "$out" ] || …genuinely empty…`. Linter: only optional SC2312 (info) under `--enable=all`; default shellcheck is silent. Verified bash 5.2, dash.

## C. `exit` inside `$( )` ends only the subshell

Status: not present (robustness.md:24 covers traps in subshells, not `exit`).

Correctness: true but needs the qualifier the brief omits. `die(){ echo died >&2; exit 3; }; x=$(die); echo continued` prints `continued rc=3 x=[]` without `set -e`. Under `set -e` a bare `x=$(die)` aborts rc=3 (the message did print), so "cannot stop the run" is only true where the status is discarded: no `-e`, an argument position as in B, or a `local x=$(die)`. Shellcheck: nothing relevant (`y=$(die)` gets only SC2034 unused-variable and optional SC2311). Observed failure (mutation probes looking green) is stated in the brief.

Verdict: ACCEPT-WITH-CHANGES; two sentences appended to B's bullet, not a separate bullet.

Increment (append to B's bullet):

> The same discard neutralises a `die` helper: `exit` inside `$( )` ends only the subshell, so `x=$(die)` stops the run only through the assignment's status under `-e`; in an argument position, or without `-e`, the caller carries on with an empty capture — which is how a deliberately broken mutant can look green.

## D. brief-3 item 2: fd 0 under the Bash tool, inherited by bats

Status: not present. environments.md:41 covers hook stdin only (`/dev/null` for most git hooks).

Correctness, probed in this session:
- The type is indeed unstable. In most Bash calls here fd 0 is `/dev/null` (character special file); in a few calls the same `sh -c` showed `socket:[…]`. bats reproduces whichever it inherited: `socket` when inherited, `character special file` under `</dev/null`, `fifo` when piped. Matches the brief's "treat the type as unspecified".
- The brief's shared claim "a read returns EOF at once (`cat | wc -c` gives 0)" is false for the socket case. On the socket, `timeout 3 cat` inside a bats test returned status 124 (it blocks); only the `/dev/null` case gives an immediate EOF. So `[ -t 0 ] || payload=$(cat)` either takes the branch with an empty payload (`/dev/null`) or hangs the test (socket). The hang is the more damaging failure and the brief missed it.
- Shellcheck cannot see runtime fd types.

Verdict: ACCEPT-WITH-CHANGES. Correct the EOF claim; do not name a CC version (my probes cannot attribute the variation to a version).

Increment (environments.md "Claude Code specifics", after the `$TMPDIR` bullet):

> - **fd 0 under the Bash tool is neither a hook's pipe nor a terminal, and its type is unspecified.** Observed in one session: `/dev/null` for most calls, a socket for others (a fifo only when you pipe in). `bats` inherits whichever it got. On `/dev/null` a read gets EOF at once, so `[ -t 0 ] || payload=$(cat)` takes its stdin branch with an empty payload; on the socket the read blocks and hangs the test. A test therefore gives its subject the stdin production gives it, explicitly — `printf '%s' "$json" |` for a hook payload, `</dev/null` for a git hook such as pre-commit — and never branches on `[ -p /dev/stdin ]` or `[ -c /dev/stdin ]` of the inherited fd.

Pointer (bats.md, one sentence at the end of the intro paragraph block, before "## A bare `! cmd`"): "A test's stdin is whatever the runner inherited, which is not what production gives the subject; see environments.md, Claude Code specifics." Optional; drop if the maintainer wants bats.md untouched.

## E. brief-3 item 3: `$$` is shared by concurrent subshell writers

Status: not present beyond robustness.md:82 ("Temp files: `mktemp`").

Correctness: `$$` verified identical in the parent and in two `( … ) &` subshells on bash and dash; `$BASHPID` differs per subshell on bash 5.2 and is empty on dash. `$BASHPID` empty on bash 3.2 is NOT verified here (no 3.2 available); it is consistent with `$BASHPID` arriving in bash 4.0, which should be checked against bash NEWS before it is written down as fact. Shellcheck: nothing. No incident is cited; the brief's bar-of-evidence is weaker than the others, but the fact is cheap and the placement natural.

environments.md `.probe.$$`: leave as is (single writer, as the brief itself says). A comment would be gold-plating; the portability note is findable by anyone who greps `$$`.

Verdict: ACCEPT-WITH-CHANGES, low priority; one bullet in portability.md `### mktemp` (the brief's target), with the 3.2 clause hedged until checked.

Increment (portability.md, `### mktemp`, new bullet before the Sources line):

> - **Do not hand-roll `tmp.$$`.** `$$` is fixed at shell start and identical in every `( … ) &` subshell, so concurrent writers of one script share the name (verified bash 5.2, dash). `$BASHPID` is per process but bash ≥ 4.0 only (empty in dash). Use `mktemp`; in tests, tell concurrent writers apart by an explicit id.

## F. brief-3 item 4: `grep -c` over JSON, `jq -r` and absent keys

Status: not present (bats.md has the `grep -qF` section only).

Correctness, verified with jq 1.7: a `systemMessage` of `"BLOCK\nBLOCK\nother"` gives `grep -c BLOCK` = 1 on the raw JSON and 2 after `jq -r .systemMessage | grep -c BLOCK`. `jq -r .key` on `{"a":1}` prints the string `null` (non-empty, passes `[ -n … ]`); `jq -r '.key // empty'` prints nothing; `jq -e 'has("key")'` exits 1. Nuance the brief omits: `// empty` also empties `false` and `null`-valued keys, so use `has()` when the key can legitimately hold `false`. Shellcheck: nothing. This repo's own hook script uses `jq -r '.session_id // "global"'` and a `jq -r` file list, so the pitfall is relevant here too; no defect found (the first has a default; not audited further).

Verdict: ACCEPT. Placement bats.md beside the `grep -qF` section as requested (these are bats assertions over hook output).

Increment (bats.md, new section after "## `grep -qF "$multiline"` matches any ONE line", before "## `@test` bodies run under errexit"):

> ## Asserting on `jq` output: two silent passes
>
> `grep -c` counts matching *lines*, and `jq` emits a multi-line `systemMessage` as one JSON string (newlines as `\n`), so a block doubled inside it still counts 1. Decode before counting: `jq -r .systemMessage | grep -c …` (verified: raw 1, decoded 2). And `jq -r .key` prints the string `null` for an absent key, which a non-empty check accepts: use `jq -r '.key // empty'` (note it also empties `false`), or assert presence with `jq -e 'has("key")'`.

## Housekeeping on landing

- CLAUDE.md requires the changelog entry in the same commit: `docs/changelog/YYYY-MM-DD-slug.md` plus its pointer line in `docs/changelog.md`. `docs/design.md` needs no change unless the SKILL.md row is added and the maintainer counts that as a decision.
- Disposition of the briefs: all three are absorbed once A to F land; they can then be removed from `inbox/`.
- Sandbox-mask dotfiles in the repo root (.bashrc, .bash_profile, .claude/*) were ignored.
