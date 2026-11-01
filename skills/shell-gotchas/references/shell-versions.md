# Shell Version Traps

Which shell runs a script varies more than which commands exist: macOS ships
bash 3.2, `/bin/sh` is dash or ash on most Linux systems, and the interactive
shell is zsh. ShellCheck does not catch these either, except where you tell it
the target shell (`-s sh`). The GNU vs BSD/macOS command divergences are in
`portability.md`.

### macOS /bin/bash is bash 3.2 (2007) — still true in 2026
Apple never shipped GPLv3 bash; its open-source distribution is frozen at
3.2.57, through macOS Tahoe 26. Anything targeting "bash on a Mac" without
Homebrew assumptions must avoid (versions from
[bash NEWS](https://tiswww.case.edu/php/chet/bash/NEWS)):
- associative arrays `declare -A`, `${var,,}`/`${var^^}`, `mapfile`/`readarray`,
  `globstar`, `&>>` — all bash 4.0
- `lastpipe` — 4.2; nameref `declare -n` — 4.3; `wait -n` — 4.3;
  `inherit_errexit` — 4.4

Use `#!/usr/bin/env bash` (picks up Homebrew bash when present), and either
stick to 3.2 features or document the requirement. Sources:
[apple-oss bash](https://github.com/apple-oss-distributions/bash/blob/main/bash-3.2/CHANGES),
[jmmv.dev](https://jmmv.dev/2019/11/macos-bash-baggage.html)

### bash 3.2 also misbehaves silently (parses, runs, wrong result)
No feature list catches these; found by running a suite under macOS /bin/bash
3.2.57 and confirmed against a 3.2.57 build. Non-ASCII input adds more traps on
macOS (see macOS libc and non-ASCII bytes in `portability.md`).
- **A temporary assignment before a builtin skips the locale hook.**
  `LC_ALL=C printf %q "$x"` (also `read`, `printf -v`) runs under the caller's
  locale; bash 4+ honours it, and external commands (`LC_ALL=C sed …`) are fine.
  Use `$(LC_ALL=C; printf %q "$x")`, or save/assign/restore
  (`saved=${LC_ALL-} had=${LC_ALL+x}` … `unset LC_ALL` when `had` is empty). Not
  `local LC_ALL=C` — 3.2.0 does not undo it on return.
- **`printf -v x '%b' ""` leaves `x` holding the previous `printf -v` result.**
  `%s` is fine. Initialise `x=` and skip the call when the argument is empty.
  This plugin's hook flags this form, the prefix form above, and the non-ASCII
  `$name` form in `portability.md`. This form passes only when the same line
  guards it with `[ -z "$v" ] ||` or `[ -n "$v" ] &&` (or the `[[ ]]` forms).
- **A failed `source` can exit the script despite a guard.** Under `set -e`, 3.2
  exits on `source f || exit 2`, `if ! source f`, `{ source f; } || …` (without
  `set -e` the `||` works). In POSIX mode (`sh`, dash, `bash --posix`) a failed
  `.` exits regardless of `||` and `set -e`. Pre-check for a missing or
  unreadable file: `[ -r ./f ] || exit 2; . ./f` (it does not stop a syntax
  error in `f` exiting a POSIX shell at `. ./f`; the `./` matters, since `.`
  searches `PATH` for a name without a slash in POSIX mode and dash reports
  `.: f: not found`), or in bash
  `[ -r ./f ] || { set +e; source ./f; exit 2; }; source ./f` to keep bash's own
  diagnostic for the missing file while `f` itself still runs under `set -e` (a
  failure inside `f` exits with that command's status, not 2; verified bash
  3.2.57 and 5.2).

### macOS /bin/sh is bash-pretending-to-be-sh
macOS `/bin/sh` is bash 3.2 in sh-compatibility mode — it still accepts many
bashisms. A `#!/bin/sh` script that "works on my Mac" can die on Debian's dash
or Alpine's ash.
**Lint sh scripts with `shellcheck -s sh`, or test under dash.** Source:
[scriptingosx](https://scriptingosx.com/2020/06/about-bash-zsh-sh-and-dash-in-macos-catalina-and-beyond/)

### /bin/sh is not bash elsewhere
- Debian/Ubuntu: dash ([Debian wiki](https://wiki.debian.org/Shell)). Alpine:
  ash/BusyBox
  ([Alpine wiki](https://wiki.alpinelinux.org/wiki/Shell_management)).
- No `[[ ]]`, arrays, `<<<` here-strings, process substitution `<(…)`,
  `${var//pat/rep}`, `${var:1:2}`.
- `local`: **permanently non-POSIX** — Austin Group
  [bug 767](https://www.austingroupbugs.net/bug_view_page.php?bug_id=767) (add
  `local`) was rejected in 2022 over scoping disagreements. Still supported by
  dash/ash/bash; acceptable in `sh` scripts by near-universal convention.
- `set -o pipefail`: **POSIX as of Issue 8**
  ([bug 789](https://austingroupbugs.net/view.php?id=789)) — but dash only
  implemented it in 0.5.12-7 (May 2024), so dash on anything older than Debian
  13 / Ubuntu 24.10 still dies on it, fatally. In `sh` scripts that must run on
  older systems: structure pipelines so the status that matters is the last
  command's, or check intermediate results explicitly.

### The user's interactive shell is zsh
macOS default login shell has been zsh since Catalina. Never assume snippets
pasted into "the user's shell" get bash semantics (zsh `echo` processes
backslash escapes by default, word splitting differs). Ship scripts with
explicit shebangs; never instruct users to `source` bash-isms into their shell.
Source:
[Apple Terminal guide](https://support.apple.com/guide/terminal/change-the-default-shell-trml113/mac)
