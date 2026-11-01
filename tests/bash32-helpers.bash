# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154 # bats sets lines, status and output; the sibling .bats files read the variables
# Tests for hooks/scripts/bash32-lint.sh and its wiring into the PostToolBatch
# hook (plans/2026-11-01-bash32-lint.md).
#
# The repo's own hook lints this file on every edit, so no line below spells a
# trigger pattern literally: the fixtures are assembled from parts in setup
# (PF, LCA, LNG, LCT, and the non-ASCII bytes as octal escapes) and written to
# files under BATS_TEST_TMPDIR.
#
# Fixture layout: line 1 is a shebang, line 2 a filler, the line under test is
# line 3 (lint_one). Every "not flagged" case runs twice (assert_clean): alone,
# expecting empty output, and followed by an unguarded format-%b sentinel on
# line 4, expecting exactly that one finding. The second run proves the lint
# read the file, so a script that prints nothing at all cannot pass.

setup() {
  HOOK_DIR="$BATS_TEST_DIRNAME/../hooks/scripts"
  LINT="$HOOK_DIR/bash32-lint.sh"
  HOOK="$HOOK_DIR/shellcheck-on-edit.sh"
  SH_BIN=$(command -v sh)
  f="$BATS_TEST_TMPDIR/t.sh"

  PF='printf'
  LCA=LC_ALL
  LNG=LANG
  LCT=LC_CTYPE
  RSQ=$(printf '\342\200\231') # U+2019 right single quotation mark
  EAC=$(printf '\303\251')     # U+00E9 e acute

  SID="bats-$BATS_TEST_NUMBER-$$"
  export TMPDIR="$BATS_TEST_TMPDIR/tmp"
  mkdir -p "$TMPDIR"
}

# --- helpers ----------------------------------------------------------------

# fixture <path> <line>...: write the lines to the file, one per line.
fixture() {
  local path=$1
  shift
  mkdir -p "$(dirname "$path")"
  printf '%s\n' "$@" >"$path"
}

# lint_one <text> [path]: file (default $f) = shebang, filler, <text> (line 3);
# run the lint on it.
lint_one() {
  local target=${2-$f}
  fixture "$target" '#!/bin/sh' ':' "$1"
  run sh "$LINT" "$target"
}

# finding_in <file> <line> <n>: some output line is a bash32-<n> finding for
# <file>:<line>, in the gcc shape file:line:col: warning: message [bash32-n].
finding_in() {
  local want_file=$1 want_line=$2 n=$3 l rest re
  re="^[0-9]+: warning: .+ \\[bash32-$n\\]\$"
  for l in "${lines[@]}"; do
    case $l in
      "$want_file:$want_line:"*)
        rest=${l#"$want_file:$want_line:"}
        if [[ $rest =~ $re ]]; then
          return 0
        fi
        ;;
    esac
  done
  return 1
}

# assert_finding <line> <n>: exit 0 and exactly one finding, for $f:<line>.
assert_finding() {
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  finding_in "$f" "$1" "$2" || {
    printf 'no bash32-%s finding at %s:%s in:\n%s\n' "$2" "$f" "$1" "$output" >&2
    false
  }
}

# assert_output_has <substring>: the combined output contains it verbatim.
assert_output_has() {
  [[ $output == *"$1"* ]] || {
    printf 'output lacks %s:\n%s\n' "$1" "$output" >&2
    false
  }
}

# assert_clean <text>: <text> alone draws nothing; with a sentinel after it the
# sentinel is the only finding.
assert_clean() {
  lint_one "$1"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  fixture "$f" '#!/bin/sh' ':' "$1" "$PF -v s '%b' \"\$sv\""
  run sh "$LINT" "$f"
  assert_finding 4 3
}
