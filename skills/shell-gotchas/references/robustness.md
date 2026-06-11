# Robustness Catalog: Quoting, Errors, Data Handling

ShellCheck flags many of these statically — run it first. This file explains the ones it misses or that need judgment.

## Exit status and `set -e`

`set -e` is a backstop, not error handling. Its blind spots:

- **Off inside conditions:** any command in `if`, `while`, `&&`/`||` chains, or `!` runs with `-e` disabled — including every function called from there, transitively.
- **`local v=$(cmd)` / `export v=$(cmd)`:** the line's status is `local`'s (always 0); `cmd`'s failure is silently discarded. Declare and assign on separate lines:
  ```sh
  local v
  v=$(cmd) || return 1
  ```
- **Process substitution:** `while read … done < <(find …)` — `find`'s failure is invisible. If the producer's status matters, use a temp file or check a sentinel.
- **Pipelines:** status is the last command's. `set -o pipefail` helps in bash; in POSIX sh, restructure.
- **`grep` benign no-match:** exits 1, indistinguishable from failure under `set -e`. Write `grep pat file || true` when no-match is fine, or capture and test.
- **`cmd && a || b` is not if/else:** `b` also runs when `a` fails. Use a real `if`.

## Honest reporting

- Print success messages only after confirming success. A `printf 'done\n'` after `sed … > tmp && mv tmp f` reports success even when the `&&` chain failed — the script must instead exit non-zero with a message on stderr.
- Failures go to stderr (`>&2`) with context (what was attempted, on which file); successes may be quiet.
- A trailing `exit 0` hides earlier failures; let the real status propagate.

## Quoting and word splitting

- Quote every expansion: `"$var"`, `"$@"`, `"$(cmd)"`. Deliberate unquoted splitting deserves a comment.
- `"$@"` forwards arguments intact; `$@` and `"$*"` do not.
- Globbing is live even when IFS-splitting on another character: a PATH segment containing `*` glob-expands in `for seg in $PATH`. Use `set -f` around such loops, or pipe through `tr ':' '\n'` and read lines.
- A glob matching nothing stays literal (bash default): `for f in *.log` iterates once over the string `*.log`. Guard with `[ -e "$f" ] || continue`, or `shopt -s nullglob` in bash.

## Filename safety

- Filenames may contain spaces, newlines, leading dashes, and glob characters.
- Recursive iteration: `find … -print0 | while IFS= read -r -d '' f` (bash), or `find … -exec cmd {} +`.
- Leading dashes: pass `--` before operands (`rm -- "$f"`) or prefix `./`.
- Never parse `ls` output.
- Print filenames with `printf '%s\n'`, never `echo`.

## read discipline

- Always `IFS= read -r`: without `-r` backslashes are mangled; without `IFS=` whitespace is trimmed.
- Last line without trailing newline is dropped by plain `while read` loops:
  ```sh
  while IFS= read -r line || [ -n "$line" ]; do … done < file
  ```
- `cmd | while read` runs the loop in a subshell (bash): counters and variables set inside vanish. Redirect into the loop or use `< <(cmd)` in bash — remembering the producer-status blind spot above.
- CRLF input silently breaks string comparisons; strip `\r` or detect early.

## Arithmetic and misc

- `$((…))` treats leading-zero numbers as octal: `$((08))` is an error, `$((010))` is 8. Strip zeros from user input (dates!) first.
- `$(…)` strips all trailing newlines. Round-trip file content with a sentinel: `x=$(cat f; echo x); x=${x%x}`.
- `[ -n $var ]` with an empty/unset var is *true* (one-argument test). Quote inside `[ ]`, always.
- `[ -e path ]` is false for dangling symlinks; use `-L` when symlinks matter.
- Heredocs: `<<'EOF'` prevents expansion, `<<EOF` performs it. When emitting a script that must contain literal `$`, quote the delimiter or escape each `\$` — and re-read the emitted output to verify which one happened.
- Temp files: `mktemp`, cleanup via `trap '…' EXIT`, respect `$TMPDIR`.
- `command -v`, never `which` (non-standard output and status).
