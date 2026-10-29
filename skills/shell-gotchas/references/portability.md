# GNU vs BSD/macOS Portability Catalog

ShellCheck does not catch any of these — verified empirically (shellcheck 0.10.0, including `--enable=all` and `-s sh`): it models shell grammar, not external-command flag dialects. A script can be shellcheck-clean and still break every Mac user.

Facts below were verified June 2026 against POSIX.1-2024 (Issue 8), GNU and macOS/FreeBSD man pages, and the bash NEWS file. POSIX.1-2024 standardized several former GNU-isms — noted per entry, but remember old implementations remain in the field.

## Command-by-command divergence

### paste
- GNU: `paste -sd:` reads stdin implicitly ("With no FILE, or when FILE is -, read standard input").
- BSD/macOS: errors with `usage: paste [-s] [-d delimiters] file ...` and produces nothing — downstream variables end up empty.
- **Portable:** `paste -sd: -` (explicit stdin operand; correct on both).
- Sources: [GNU paste(1)](https://man7.org/linux/man-pages/man1/paste.1.html), [FreeBSD paste(1)](https://man.freebsd.org/cgi/man.cgi?paste(1))

### sed
- `-i`: GNU takes an *optional attached* suffix (`sed -i 'x' f`, `sed -i.bak 'x' f`); BSD *requires* an argument (`sed -i '' 'x' f`) — but GNU reads that `''` as the script. POSIX.1-2024 sed still has no `-i` at all.
- **Portable:** `sed -i.bak 'x' f && rm f.bak` — or avoid in-place: `sed 'x' f > tmp && mv tmp f`.
- `-E` (ERE) is now POSIX (Issue 8) and works on both; prefer it over GNU-only `-r`.
- BSD sed has **no long options at all** — `--in-place` dies on macOS.
- Sources: [GNU sed(1)](https://man7.org/linux/man-pages/man1/sed.1.html), [FreeBSD sed(1)](https://man.freebsd.org/cgi/man.cgi?sed(1)), [POSIX sed](https://pubs.opengroup.org/onlinepubs/9799919799/utilities/sed.html)

### date
- GNU: `date -d '2 days ago'`, `date -d @1700000000`.
- BSD/macOS: `date -v-2d`, `date -r 1700000000`. (BSD's old `-d` set the DST flag and has been *removed* — same letter, different planet.)
- `date +%s.%N` — `%N` (nanoseconds) is GNU-only; macOS prints a literal `N`.
- **Portable:** none for relative dates. Branch on availability, or compute timestamps in awk/python.
- Sources: [FreeBSD date(1)](https://man.freebsd.org/cgi/man.cgi?date(1)), [GNU date(1)](https://man7.org/linux/man-pages/man1/date.1.html), [macOS strftime(3)](https://keith.github.io/xcode-man-pages/strftime.3.html)

### stat
- GNU: `stat -c %s file`. BSD/macOS: `stat -f %z file`.
- **Portable:** `wc -c < file` for size; avoid stat in portable scripts.
- **Probe the flavor once and memoize it — never per call.** The reflex form `stat -c '%Y' "$f" 2>/dev/null || stat -f '%m' "$f"` pays twice: on BSD it suppresses an expected error on every single file, and on GNU it suppresses a *real* one (missing file, permission denied) and silently falls through to the BSD branch, which then fails for a different reason. Probe at startup (`stat -c '%Y' . >/dev/null 2>&1` succeeds on GNU, fails on BSD/macOS), store the answer, and branch on it.
- Sources: [GNU stat(1)](https://man7.org/linux/man-pages/man1/stat.1.html), [macOS stat(1)](https://keith.github.io/xcode-man-pages/stat.1.html)

### readlink / realpath — updated, mostly a solved problem now
- macOS **12.3 (2022) added `readlink -f`**, and `realpath(1)` ships natively (BSD utility since FreeBSD 4.3). Both utilities are also POSIX as of Issue 8.
- The classic fallback `abs=$(cd "$(dirname "$f")" && pwd)/$(basename "$f")` is only needed when supporting macOS < 12.3 or stripped-down containers.
- Sources: [macOS realpath(1)](https://keith.github.io/xcode-man-pages/realpath.1.html), [scriptingosx on 12.3](https://scriptingosx.com/2022/03/some-cli-updates-in-macos-monterey/), [POSIX realpath](https://pubs.opengroup.org/onlinepubs/9799919799/utilities/realpath.html)

### grep
- `-P` (PCRE) is GNU-only and optional even there; `-z` is GNU-only. macOS grep does support `-o` and GNU-style long options.
- **Portable:** `grep -E`, or awk for anything fancier.
- Sources: [GNU grep(1)](https://man7.org/linux/man-pages/man1/grep.1.html), [macOS grep(1)](https://keith.github.io/xcode-man-pages/grep.1.html)

### find
- `-printf` is GNU-only — absent from macOS find. **Portable:** `-exec` with a body, or `-print0` pipelines.
- `-print0` is now POSIX (Issue 8, Defect 243). `-maxdepth` and `-delete` are on both modern implementations but still not POSIX — fine for macOS+Linux targets.
- `-regex` matches **different regex flavors**: GNU find defaults to Emacs regexes; BSD find uses BRE (ERE with `find -E`). Same expression, silently different matches — avoid `-regex`; use `-name`/`-path` globs.
- Sources: [GNU find(1)](https://man7.org/linux/man-pages/man1/find.1.html), [macOS find(1)](https://keith.github.io/xcode-man-pages/find.1.html), [POSIX find](https://pubs.opengroup.org/onlinepubs/9799919799/utilities/find.html)

### xargs
- Empty input: GNU runs the command once unless `-r`; BSD skips it. macOS xargs **accepts `-r` as a documented no-op**, and POSIX.1-2024 standardized both `-r` and `-0`.
- **Portable:** always write `xargs -r` — harmless on BSD, meaningful on GNU, now standard.
- Sources: [macOS xargs(1)](https://keith.github.io/xcode-man-pages/xargs.1.html), [POSIX xargs](https://pubs.opengroup.org/onlinepubs/9799919799/utilities/xargs.html)

### timeout — does not exist on macOS
- In GNU coreutils, FreeBSD, and now POSIX (Issue 8) — but macOS ships no `timeout(1)`. Homebrew coreutils provides `gtimeout`.
- **Portable:** `t=$(command -v timeout || command -v gtimeout) || …`, or implement with a background job plus `kill`.
- Source: [POSIX timeout](https://pubs.opengroup.org/onlinepubs/9799919799/utilities/timeout.html)

### awk
- macOS awk is the one-true-awk (BWK), not gawk: no `gensub()`, `systime()`, `strftime()`, `asort()`, `BEGINFILE`.
- **Portable:** stick to POSIX awk functions (`sub`/`gsub`/`match`/`split`/`sprintf`…).
- Source: [macOS awk(1)](https://keith.github.io/xcode-man-pages/awk.1.html)

### macOS libc and non-ASCII bytes
- Observed on macOS (not in a man page): in a UTF-8 locale libc classifies bytes 0x80-0xFF as Latin-1 printable/alnum, which glibc never does. This is the platform's libc, so Homebrew bash is affected too, and Linux tests cannot reproduce the byte classification. Two effects: `printf %q` on non-ASCII bytes depends on locale and platform (glibc keeps a valid UTF-8 character raw in a UTF-8 locale and escapes it only in the C locale or for an invalid byte; macOS also leaves lone high bytes raw, observed under bash 3.2), so a test asserting the `$'caf\303\251'` form must run `%q` under `LC_ALL=C`; and bash reads `"‘$p’"` as a variable named `p` plus the first byte of the closing quote (`unbound variable` under `set -u`; ShellCheck does not flag it). Brace any `$name` followed by a non-ASCII character (`${p}’`); run `%q` under `LC_ALL=C` using the subshell form from "bash 3.2 also misbehaves silently" below, not the prefix form.
- macOS awk aborts on an invalid UTF-8 byte in its input (`awk: towc: multibyte conversion failure`); `LC_ALL=C awk` avoids it (awk is external, so the prefix works). APFS refuses a non-UTF-8 file name (`mkdir: …: Illegal byte sequence`).

### Checksums
- GNU: `md5sum`, `sha256sum`. macOS native: `md5`, `shasum`, `sha256` — different output format (BSD `MD5 (file) = hash` vs GNU `hash  file`). Current macOS also installs GNU-mode names, older macOS does not.
- **Portable:** `shasum -a 256` (anywhere Perl is); never parse the hash line format blindly.
- Source: [macOS md5(1)](https://keith.github.io/xcode-man-pages/md5.1.html)

### tar
- macOS tar is bsdtar (libarchive), not GNU tar; GNU-specific flags differ or are absent.
- **Portable:** stick to `-c/-x/-t/-f/-z` core options.
- Source: [macOS bsdtar(1)](https://keith.github.io/xcode-man-pages/bsdtar.1.html)

### sort
- Not stable by default on either platform, and equal-key order *differs* between them — pass `-s` when ties matter. `-V` (version sort) exists on both GNU and BSD but is not POSIX.
- Sources: [GNU sort(1)](https://man7.org/linux/man-pages/man1/sort.1.html), [macOS sort(1)](https://keith.github.io/xcode-man-pages/sort.1.html)

### head / tail
- `head -c N` is now POSIX (Issue 8, Defect 407); `tail -n +N` is POSIX. Both fine everywhere.
- GNU `head -n -5` ("all but the last 5") is GNU-only — macOS head takes only positive counts. Portable: awk/sed arithmetic.
- Long options are unreliable on BSD-shared tools as a class — but check the specific tool: macOS head/grep/sort now accept GNU long options, macOS sed accepts none. When in doubt, short options only.
- Sources: [POSIX head](https://pubs.opengroup.org/onlinepubs/9799919799/utilities/head.html), [macOS head(1)](https://keith.github.io/xcode-man-pages/head.1.html)

### wc
- BSD/macOS `wc` left-pads (right-aligns) the count (`wc -l` prints `       2`; GNU prints `2`), from a pipe and from `< file` alike. Command substitution keeps the blanks. The man page does not mention it; `od -c` shows it.
- Invisible to the arithmetic form, fatal to the string form: `[ "$n" -eq 2 ]` passes everywhere, while `[ "$n" = 2 ]`, `[[ $n == 2 ]]` and `case` fail on BSD only. ShellCheck does not flag it.
- **Portable:** compare counts with `-eq`; or normalise with `n=$(( $(… | wc -l) ))` or `| tr -d '[:space:]'`. `grep -c ''` is unpadded but exits 1 on a zero count (watch `set -e`) and counts an unterminated last line that `wc -l` does not, so it is not a drop-in.

### getopt(1)
- Linux util-linux getopt parses long options; macOS getopt is the ancient BSD one — single-letter only, no `--foo`.
- **Portable:** the `getopts` shell builtin (short options only) or hand-rolled parsing. Never `getopt(1)` in portable scripts.
- Source: [macOS getopt(1)](https://keith.github.io/xcode-man-pages/getopt.1.html)

### mktemp
- GNU: template needs ≥3 trailing `X`s, `-t` deprecated. BSD: different `-t` semantics entirely (prefix, builds template from TMPDIR).
- **Portable:** `mktemp "${TMPDIR:-/tmp}/name.XXXXXX"` and `mktemp -d` — both work everywhere. Avoid `-t` on either.
- **Do not hand-roll `tmp.$$`.** `$$` is fixed at shell start and identical in every `( … ) &` subshell, so concurrent writers of one script share the name (verified bash 5.2, dash). `$BASHPID` is per process but bash ≥ 4.0 only (empty in dash). Use `mktemp`; in tests, tell concurrent writers apart by an explicit id.
- Sources: [GNU mktemp(1)](https://man7.org/linux/man-pages/man1/mktemp.1.html), [FreeBSD mktemp(1)](https://man.freebsd.org/cgi/man.cgi?mktemp(1))

### macOS $TMPDIR: reached through a symlink, ends in a slash
- macOS `$TMPDIR` is `/var/folders/<hash>/<hash>/T/`: `/var` is a symlink to `/private/var`, and the string ends in `/`. `$PWD` and a raw `mktemp -d` keep the logical path; `pwd -P` and `git rev-parse --show-toplevel` and `git worktree list` report the resolved one. Path-string comparisons then fail in bulk (observed: about 70 of 95 suite failures, each looking like its own bug), and `"$TMPDIR/name"` carries a `//` that `cd`+`pwd` canonicalises away and a raw string does not.
- Fix once, at the fixture layer: `TMP_REPO="$(cd "$(mktemp -d …)" && pwd -P)"`. A per-assertion fix loses; the assertion count only grows.
- Shipped code is hit too: `[ "$PWD" = "$(git rev-parse --show-toplevel)" ]` refuses a caller already at the root of a symlinked checkout. Compare `pwd -P` to the toplevel.
- Reproduces on Linux: run the suite with `TMPDIR="$link/"` where `$link` is a symlink to a real directory. A wrapper that strips its own directory from `PATH` hangs on this input; see environments.md, Self-location.

### echo
- POSIX: any backslash in an operand, or a first operand like `-n`/`-e`, makes the result implementation-defined. "New applications are encouraged to use printf instead of echo."
- **Portable:** `printf '%s\n' "$data"` always; `printf '%s' "$data"` for no newline. (And don't start a printf *format* with `-`.)
- Source: [POSIX echo](https://pubs.opengroup.org/onlinepubs/9799919799/utilities/echo.html)

### test / [
- POSIX.1-2024 **removed** the `-a`/`-o` binary primaries and `(`/`)`; `==` was never POSIX (bash-ism accepted by some shells).
- **Portable:** `test x && test y` instead of `test x -a y`; always `=`, never `==`.
- Source: [POSIX test](https://pubs.opengroup.org/onlinepubs/9799919799/utilities/test.html)

### Myth-kill: seq exists on macOS
- Ported to FreeBSD 9.0, present on modern macOS. Old "no seq on Mac" advice is stale (still absent from strict POSIX, though).
- Source: [macOS seq(1)](https://keith.github.io/xcode-man-pages/seq.1.html)

## Shell version traps

### macOS /bin/bash is bash 3.2 (2007) — still true in 2026
Apple never shipped GPLv3 bash; its open-source distribution is frozen at 3.2.57, through macOS Tahoe 26. Anything targeting "bash on a Mac" without Homebrew assumptions must avoid (versions from [bash NEWS](https://tiswww.case.edu/php/chet/bash/NEWS)):
- associative arrays `declare -A`, `${var,,}`/`${var^^}`, `mapfile`/`readarray`, `globstar`, `&>>` — all bash 4.0
- `lastpipe` — 4.2; nameref `declare -n` — 4.3; `wait -n` — 4.3; `inherit_errexit` — 4.4

Use `#!/usr/bin/env bash` (picks up Homebrew bash when present), and either stick to 3.2 features or document the requirement.
Sources: [apple-oss bash](https://github.com/apple-oss-distributions/bash/blob/main/bash-3.2/CHANGES), [jmmv.dev](https://jmmv.dev/2019/11/macos-bash-baggage.html)

### bash 3.2 also misbehaves silently (parses, runs, wrong result)
No feature list catches these; found by running a suite under macOS /bin/bash 3.2.57 and confirmed against a 3.2.57 build. Non-ASCII input adds more traps on macOS (see macOS libc and non-ASCII bytes above).
- **A temporary assignment before a builtin skips the locale hook.** `LC_ALL=C printf %q "$x"` (also `read`, `printf -v`) runs under the caller's locale; bash 4+ honours it, and external commands (`LC_ALL=C sed …`) are fine. Use `$(LC_ALL=C; printf %q "$x")`, or save/assign/restore (`saved=${LC_ALL-} had=${LC_ALL+x}` … `unset LC_ALL` when `had` is empty). Not `local LC_ALL=C` — 3.2.0 does not undo it on return.
- **`printf -v x '%b' ""` leaves `x` holding the previous `printf -v` result.** `%s` is fine. Initialise `x=` and skip the call when the argument is empty.
- **A failed `source` can exit the script despite a guard.** Under `set -e`, 3.2 exits on `source f || exit 2`, `if ! source f`, `{ source f; } || …` (without `set -e` the `||` works). In POSIX mode (`sh`, dash, `bash --posix`) a failed `.` exits regardless of `||` and `set -e`. Pre-check for a missing or unreadable file: `[ -r ./f ] || exit 2; . ./f` (it does not stop a syntax error in `f` exiting a POSIX shell at `. ./f`; the `./` matters, since `.` searches `PATH` for a name without a slash in POSIX mode and dash reports `.: f: not found`), or in bash `[ -r ./f ] || { set +e; source ./f; exit 2; }; source ./f` to keep bash's own diagnostic for the missing file while `f` itself still runs under `set -e`.

### macOS /bin/sh is bash-pretending-to-be-sh
macOS `/bin/sh` is bash 3.2 in sh-compatibility mode — it still accepts many bashisms. A `#!/bin/sh` script that "works on my Mac" can die on Debian's dash or Alpine's ash. **Lint sh scripts with `shellcheck -s sh`, or test under dash.**
Source: [scriptingosx](https://scriptingosx.com/2020/06/about-bash-zsh-sh-and-dash-in-macos-catalina-and-beyond/)

### /bin/sh is not bash elsewhere
- Debian/Ubuntu: dash ([Debian wiki](https://wiki.debian.org/Shell)). Alpine: ash/BusyBox ([Alpine wiki](https://wiki.alpinelinux.org/wiki/Shell_management)).
- No `[[ ]]`, arrays, `<<<` here-strings, process substitution `<(…)`, `${var//pat/rep}`, `${var:1:2}`.
- `local`: **permanently non-POSIX** — Austin Group [bug 767](https://www.austingroupbugs.net/bug_view_page.php?bug_id=767) (add `local`) was rejected in 2022 over scoping disagreements. Still supported by dash/ash/bash; acceptable in `sh` scripts by near-universal convention.
- `set -o pipefail`: **POSIX as of Issue 8** ([bug 789](https://austingroupbugs.net/view.php?id=789)) — but dash only implemented it in 0.5.12-7 (May 2024), so dash on anything older than Debian 13 / Ubuntu 24.10 still dies on it, fatally. In `sh` scripts that must run on older systems: structure pipelines so the status that matters is the last command's, or check intermediate results explicitly.

### The user's interactive shell is zsh
macOS default login shell has been zsh since Catalina. Never assume snippets pasted into "the user's shell" get bash semantics (zsh `echo` processes backslash escapes by default, word splitting differs). Ship scripts with explicit shebangs; never instruct users to `source` bash-isms into their shell.
Source: [Apple Terminal guide](https://support.apple.com/guide/terminal/change-the-default-shell-trml113/mac)

## Locking fixes in

A portability bug fixed without a test will come back. For any divergence fixed here, add a platform-simulation regression test — a PATH-shadowing wrapper placed first in PATH that enforces the *stricter* platform's behavior, then assert the script still works. Example — a BSD-strict `paste` (errors when given no file operand, exactly like macOS):

```sh
real_paste=$(command -v paste)
# unquoted EOF: $real_paste expands now (baked into the stub); \$@ stays for run time
cat > "$stubdir/paste" <<EOF
#!/bin/sh
ok=0
for a in "\$@"; do case "\$a" in -) ok=1 ;; -*) ;; *) ok=1 ;; esac; done
[ "\$ok" -eq 1 ] || { echo 'usage: paste [-s] [-d delimiters] file ...' >&2; exit 1; }
exec "$real_paste" "\$@"
EOF
chmod 755 "$stubdir/paste"
PATH="$stubdir:$PATH" run-the-script-under-test
```

Adapt the same shape for `sed -i`, `xargs`, or `date`: a wrapper that rejects the GNU-only invocation. This makes Linux CI catch macOS breakage.

A PATH stub reaches only tools the script under test execs. A GNU-only spelling written directly in a `@test` body or helper is run by the test process itself, is never shadowed, and no Linux run can fail on it (observed: `run stat -c '%a' f` survived until a Mac ran the suite). Pair stubs with a static per-file check — per file, because a memoized probe puts a bare `stat -c` on a line of its own:

```sh
{ grep -rlE -e 'stat( +-[A-Za-z]+)* +-[A-Za-z]*c([^A-Za-z]|$)' -e 'stat( +-[A-Za-z]+)* +--(format|printf)' \
    --include='*.sh' --include='*.bash' --include='*.bats' . || [ $? -eq 1 ]; } \
  | ( rc=0; while IFS= read -r f; do grep -qE 'stat( +-[A-Za-z]+)* +-[A-Za-z]*f' "$f" || { printf 'GNU-only stat: %s\n' "$f"; rc=1; }; done; exit "$rc" )
```

Exits 1 when it names a file, so it works as a gate (the consumer is a subshell, so a shell that runs the last pipeline stage in the current one, bash `lastpipe` or ksh, does not have its `exit` end the caller); `|| [ $? -eq 1 ]` keeps grep's no-match status from failing a clean tree under `set -o pipefail`. Limits: it confirms a BSD-looking spelling exists in the file, not that the probe is done once (`stat -f` is also GNU's `--file-system`, so a GNU use of it satisfies the check); a grep error (exit 2, e.g. an unreadable file) prints to stderr but fails the gate only under `pipefail`; and it reads one filename per line, so a name containing a newline is split.
