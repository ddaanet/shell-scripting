# GNU vs BSD/macOS Portability Catalog

ShellCheck does not catch any of these: they are runtime behavior differences between GNU coreutils (Linux) and BSD userland (macOS), not syntax issues. A script can be shellcheck-clean and still break every Mac user.

## Command-by-command divergence

### paste
- GNU: `paste -sd:` reads stdin implicitly.
- BSD: errors with `usage: paste [-s] [-d delimiters] file ...` and produces nothing — downstream variables end up empty.
- **Portable:** `paste -sd: -` (explicit stdin operand; POSIX-correct on both).

### sed -i
- GNU: `-i` takes an *optional attached* suffix: `sed -i 'x' f` or `sed -i.bak 'x' f`.
- BSD: `-i` *requires* an argument: `sed -i '' 'x' f`. But GNU reads that `''` as the script.
- **Portable:** `sed -i.bak 'x' f && rm f.bak` — or avoid in-place entirely: `sed 'x' f > tmp && mv tmp f`.

### date
- GNU: `date -d '2 days ago'`, `date -d @1700000000`.
- BSD: `date -v-2d`, `date -r 1700000000`.
- **Portable:** none. Branch on availability, or compute timestamps in awk/python.

### stat
- GNU: `stat -c %s file`. BSD: `stat -f %z file`.
- **Portable:** `wc -c < file` for size; avoid stat in portable scripts.

### readlink / realpath
- `readlink -f` and `realpath` are missing or limited on older macOS.
- **Portable:** `abs=$(cd "$(dirname "$f")" && pwd)/$(basename "$f")` for files known to exist.

### grep
- `grep -P` (PCRE) is GNU-only, and optional even there. **Portable:** `grep -E`, or awk for anything fancier.

### find
- `-printf` is GNU-only. **Portable:** `-exec` with a body, or `-print0` pipelines.
- `-delete`, `-maxdepth`, `-print0` are common to both modern implementations but not strict POSIX — fine for macOS+Linux targets.

### xargs
- Empty input: GNU runs the command once unless `-r`; BSD skips it (and may not accept `-r`).
- **Portable:** guard the producer so empty input cannot reach xargs, or use `find -exec … +`.

### mktemp
- Template semantics differ between implementations.
- **Portable:** `mktemp "${TMPDIR:-/tmp}/name.XXXXXX"` and `mktemp -d` — both work everywhere.

### head/tail
- `head -c N` and `tail -n +N` are fine on both. `head --lines` long options are GNU-only — never use long options on BSD-shared tools.

### echo
- Flag and backslash handling varies by shell and platform (`echo -n`, `echo -e`).
- **Portable:** `printf '%s\n' "$data"` always; `printf '%s' "$data"` for no newline.

## Shell version traps

### macOS /bin/bash is bash 3.2 (2007)
Apple never shipped GPLv3 bash. Anything targeting "bash on a Mac" without Homebrew assumptions must avoid:
- associative arrays (`declare -A`) — bash 4
- `${var,,}` / `${var^^}` case conversion — bash 4
- `mapfile` / `readarray` — bash 4
- `&>>`, `globstar` (bash 4), `lastpipe` (bash 4.2), nameref `declare -n` (bash 4.3)

Use `#!/usr/bin/env bash` (picks up Homebrew bash when present), and either stick to 3.2 features or document the requirement.

### /bin/sh is not bash
- Debian/Ubuntu: dash. Alpine: ash (busybox).
- No `[[ ]]`, arrays, `<<<` here-strings, process substitution `<(…)`, `${var//pat/rep}`, `${var:1:2}`.
- `local` is not POSIX but is supported by dash/ash/bash — acceptable in `sh` scripts by near-universal convention.
- `set -o pipefail` was only recently standardized; older dash rejects it. In `sh`, structure pipelines so the status that matters is the last command's, or check intermediate results explicitly.

## Locking fixes in (cross-reference)

For any divergence fixed here, add a platform-simulation regression test — a PATH-shadowing wrapper that enforces the *stricter* platform's behavior. See "Locking In a Portability Fix" in SKILL.md for the template.
