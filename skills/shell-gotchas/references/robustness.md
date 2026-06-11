# Robustness Catalog: Exit Status, Quoting, Data Handling

Run shellcheck first — including the optional checks (`shellcheck --enable=all` adds SC2310/SC2311/SC2312 for `set -e` blind spots, among others). This file explains what survives the linter, what the linter only partially sees, and the judgment calls. Where a shellcheck code covers an entry, it is named — the code tells *what*, this file tells *why*.

Claims verified June 2026 against the bash manual, POSIX.1-2024, [BashPitfalls](https://mywiki.wooledge.org/BashPitfalls) (pitfall numbers cited as BP#n), and empirical shellcheck 0.10.0 runs.

## Exit status and `set -e`

`set -e` is a backstop, not error handling. Its blind spots:

- **Off inside conditions, transitively:** any command in `if`, `while`, `&&`/`||` chains, or after `!` runs with `-e` disabled — *including every function called from there*. Bash manual: "none of the commands executed within the compound command or function body will be affected by the -e setting." Linter: only optional SC2310. ([bash set builtin](https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html))
- **Command substitution does not inherit `set -e` (bash):** in `var=$(f)`, `f` runs with errexit *off* unless `shopt -s inherit_errexit` (bash ≥ 4.4) or POSIX mode. A failing pipeline inside `$(…)` sails through. Fix: `shopt -s inherit_errexit` near the top of bash ≥ 4.4 scripts, or check the assignment status explicitly. Linter: only optional SC2311, and only when the substitution calls a *function* — `v=$(false; echo hi)` gets nothing even under `--enable=all` (verified). ([bash shopt](https://www.gnu.org/software/bash/manual/html_node/The-Shopt-Builtin.html), [BashFAQ/105](https://mywiki.wooledge.org/BashFAQ/105))
- **`local v=$(cmd)` / `export v=$(cmd)`:** the line's status is `local`'s (always 0). Shellcheck catches this (SC2155, warning) — fix it the way SC2155 says:
  ```sh
  local v
  v=$(cmd) || return 1
  ```
- **Process substitution:** `while read … done < <(find …)` — `find`'s failure is invisible. Bash ≥ 4.4 can retrieve it with `wait "$!"` right after; portably, use a temp file. Linter: only optional SC2312. ([wooledge ProcessSubstitution](https://mywiki.wooledge.org/ProcessSubstitution))
- **Pipelines:** status is the last command's. `set -o pipefail` is POSIX as of 2024 but absent from older `sh` implementations in the field (see portability.md).
- **`pipefail` + early-exiting consumers = spurious failures:** `producer | grep -q x` makes `grep` exit at first match; the producer dies of SIGPIPE (status 141) and pipefail reports the *pipeline* failed. Same with `| head`. Either don't combine pipefail with early-exit consumers, or tolerate status 141 explicitly. (BP#60)
- **`grep` benign no-match:** exits 1, indistinguishable from failure under `set -e`. Write `grep pat file || true` when no-match is fine, or capture and test. ([POSIX grep exit status](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/grep.html))
- **`cmd && a || b` is not if/else:** `b` also runs when `a` fails. Use a real `if`. Shellcheck's SC2015 flags *some* shapes but stays silent when the `||` branch is an `echo`/`printf` — i.e. exactly the most common form. (BP#22)
- **Bare `wait` always exits 0:** with no operands, `wait` ignores all background-job failures. Collect PIDs and `wait "$pid"` individually (bash ≥ 4.3: `wait -n`). ([POSIX wait](https://man7.org/linux/man-pages/man1/wait.1p.html))
- **Traps reset in subshells:** an EXIT cleanup trap does not fire for `( … )` or `$(…)` — POSIX: on subshell entry, non-ignored traps are reset to defaults. Also, a bare `exit` inside a trap action uses the status of the command *before* the trap fired. ([POSIX trap](https://pubs.opengroup.org/onlinepubs/009695399/utilities/trap.html))

## Honest reporting

- Print success messages only after confirming success. A `printf 'done\n'` after `sed … > tmp && mv tmp f` reports success even when the `&&` chain failed — the script must instead exit non-zero with a message on stderr. (No linter coverage — verified.)
- Failures go to stderr (`>&2`) with context (what was attempted, on which file); successes may be quiet.
- A trailing `exit 0` hides earlier failures; let the real status propagate.

## Quoting and word splitting

- Quote every expansion: `"$var"`, `"$@"`, `"$(cmd)"`. Deliberate unquoted splitting deserves a comment.
- `"$@"` forwards arguments intact; `$@` and `"$*"` do not. (BP#2, BP#24)
- Globbing is live even when IFS-splitting on another character: a PATH segment containing `*` glob-expands in `for seg in $PATH` (shellcheck deliberately does not flag `for … in $var`). Use `set -f` around such loops, or pipe through `tr ':' '\n'` and read lines.
- A glob matching nothing stays literal — that is the POSIX-mandated default in *all* shells, not a bashism: `for f in *.log` iterates once over the string `*.log`. Guard with `[ -e "$f" ] || continue`, or `shopt -s nullglob` in bash. ([POSIX 2.13.3](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html))
- Don't store commands in scalar variables — quoting dies in the round-trip. Functions hold code; arrays hold argument lists (bash). Never `eval` assembled strings. ([BashFAQ/050](https://mywiki.wooledge.org/BashFAQ/050))

## Filename safety

- Filenames may contain spaces, newlines, leading dashes, and glob characters.
- Recursive iteration (bash): `find … -print0 | while IFS= LC_ALL=C read -r -d '' f` — the `LC_ALL=C` matters: bash 5.0–5.3 has a multibyte bug where `read -d ''` can overshoot the NUL (BP#65). Portable alternative: `find … -exec cmd {} +`.
- `find -exec sh -c '…' …` must pass filenames as *arguments*, never splice `{}` into the command string: `find … -exec sh -c 'cmd "$1"' x {} \;`. (BP#52)
- Leading dashes: pass `--` before operands (`rm -- "$f"`) or prefix `./`.
- Never parse `ls` output.
- Print filenames with `printf '%s\n'`, never `echo`.

## read discipline

- Always `IFS= read -r`: without `-r` backslashes are mangled (shellcheck SC2162 catches the missing `-r`; the missing `IFS=` it does *not* catch — whitespace gets trimmed silently).
- Last line without trailing newline is dropped by plain `while read` loops:
  ```sh
  while IFS= read -r line || [ -n "$line" ]; do … done < file
  ```
  ([BashFAQ/001](https://mywiki.wooledge.org/BashFAQ/001))
- `cmd | while read` runs the loop in a subshell in bash — counters and variables set inside vanish. (ksh and zsh run the last pipeline stage in the current shell; bash ≥ 4.2 `shopt -s lastpipe` does too, but only with job control off. POSIX permits either.) Shellcheck flags the broken case (SC2030/SC2031, info-level) when the variable is used after the loop. Redirect into the loop or use `< <(cmd)` in bash — remembering the producer-status blind spot above. ([BashFAQ/024](https://mywiki.wooledge.org/BashFAQ/024))
- Splitting on a custom IFS drops trailing empty fields (IFS is a field *terminator* in POSIX): `IFS=, read -ra f <<< "a,,"` yields 2 fields, not 3. Append one separator to the input when trailing empties matter. (BP#47)
- Saving and restoring IFS via `OIFS=$IFS … IFS=$OIFS` cannot restore an *unset* IFS (it restores empty, which splits differently). Prefer one-off prefix assignment (`IFS=, read …`) or `local IFS=…` in a function. (BP#49)
- `done <<< "$(cmd)"` strips trailing newlines and buffers everything in memory; `< <(cmd)` does neither. (BP#63)
- CRLF input silently breaks string comparisons; strip `\r` (`tr -d '\r'`) or detect early (`sed -n l`). ([BashFAQ/052](https://mywiki.wooledge.org/BashFAQ/052))

## Arithmetic and misc

- `$((…))` treats leading-zero numbers as octal: `$((010))` is 8, `$((08))` is an error. Shellcheck flags literals (SC2080) but **not** the variable form `$((0$n))` — strip zeros from user input (dates!) first.
- **Arithmetic contexts evaluate variable *contents* as expressions — injection vector (bash):** `$((x))`, `((x++))`, and array subscripts recursively evaluate what's inside `x`; attacker-controlled input like `a[$(reboot)]` executes. Validate input is all digits *before* any arithmetic use. No shellcheck coverage. ([bash arithmetic](https://www.gnu.org/software/bash/manual/html_node/Shell-Arithmetic.html), BP#46/#61/#62)
- `$(…)` strips all trailing newlines. Round-trip file content with a sentinel: `x=$(cat f; printf x); x=${x%x}`. (BP#41)
- `[ -n $var ]` with an empty/unset var is *true* (one-argument test) — shellcheck catches the instance (SC2070); the reason to know the rule is reading other people's code. Quote inside `[ ]`, always.
- `[ -e path ]` is false for dangling symlinks; test `[ -e path ] || [ -L path ]` when symlinks matter. (BP#37)
- Heredocs: `<<'EOF'` prevents expansion, `<<EOF` performs it. When emitting a script that must contain literal `$`, quote the delimiter or escape each `\$` — and re-read the emitted output to verify which one happened.
- Two `date` calls can straddle midnight: `month=$(date +%m); day=$(date +%d)` — capture once: `eval "$(date +'month=%m day=%d')"`. (BP#58)
- `unset name` without a flag is ambiguous when a function shares the name (bash then unsets the function). Always `unset -v` or `unset -f`. ([POSIX unset](https://man7.org/linux/man-pages/man1/unset.1p.html))
- Temp files: `mktemp`, cleanup via `trap '…' EXIT` *in the main shell* (traps don't survive into subshells), respect `$TMPDIR`.
- `command -v`, never `which` (non-standard output and status; shellcheck only flags it under optional `deprecate-which`). ([BashFAQ/081](https://mywiki.wooledge.org/BashFAQ/081))
