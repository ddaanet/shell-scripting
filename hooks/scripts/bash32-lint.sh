#!/bin/sh
# Lint shell files for three silent bash 3.2 (macOS /bin/bash) traps that the
# usual linter cannot see. Usage: bash32-lint.sh FILE...
# One finding per line in shellcheck's gcc shape:
#   file:line:col: warning: message [bash32-N]
# Exit 0 whether or not anything was found; the caller decides what is a shell
# file. An awk failure on a file is reported as a bash32-0 finding on its line
# 1, so it reaches the model instead of reading as a clean file. Matching is
# line-level and ignores quotes, comments and heredocs, so a matching line
# inside one is flagged too (docs/design.md, D11).
#
#   bash32-0  the checks could not run (awk failed)
#   bash32-1  unbraced $name followed by a byte >= 0x80
#   bash32-2  locale variable assigned as a prefix of a bash builtin
#   bash32-3  printf into a variable with the b conversion, unguarded
#
# The regexes avoid the literal trigger text, because the hook lints this file
# on every edit. High bytes are spelled as an explicit octal range under
# LC_ALL=C, never a ctype class: macOS libc classifies 0x80-0xFF as printable
# in a UTF-8 locale, glibc does not.

for file in "$@"; do
  [ -r "$file" ] || continue
  # The path travels in the environment: awk -v would expand backslashes and an
  # operand like a=b.sh would be taken for an assignment.
  LC_ALL=C LINT_FILE=$file awk '
function report(col, n, msg) {
  printf "%s:%d:%d: warning: %s [bash32-%d]\n", file, FNR, col, msg, n
}

# bash32-1: $name immediately followed by a byte outside ASCII.
function scan_unbraced() {
  if (match($0, /\$[A-Za-z_][A-Za-z0-9_]*[^\001-\177]/))
    report(RSTART, 1, "unbraced $name followed by a non-ASCII byte: bash 3.2 on macOS reads the byte as part of the name; write ${name} before it")
}

# bash32-2: a run of prefix assignments that names a locale variable, ending in
# a builtin. A word ending in a control operator, or a keyword, opens the next
# command position. Each opener (a dollar-paren, a backtick, or a less-than or
# greater-than paren) opens one too, wherever it sits in a word and however
# many a word holds: the text after it in that word is the first word there.
# A bare paren at the start of a word, or of the text after an opener, does the
# same. A closing backtick opens nothing and ends command position, so the words
# after it are arguments. A shortcut applies to a word at command position that
# starts as an assignment and whose parens and backticks balance within it: it
# counts as a plain assignment and its substitutions are not walked, so the run
# that was open before the word stays open after it, unless a control operator
# ends the word. A prefix and a builtin inside such a word would need a space,
# which splits the word. Backtick state carries across the words of a line.
function scan_locale_prefix(   n, f, i, w, first, frag, tok, pos, rest, c, at_cmd, loc, lcol, bt) {
  n = split($0, f, /[ \t]+/)
  at_cmd = 1
  loc = 0
  bt = 0
  for (i = 1; i <= n; i++) {
    w = f[i]
    first = 1
    while (1) {
      while (w ~ /^"?\(/) {
        sub(/^"?\(/, "", w)
        at_cmd = 1; loc = 0
      }
      if (first && at_cmd && w ~ /^[A-Za-z_][A-Za-z0-9_]*=/ && balanced(w)) {
        if (w ~ /^(LC_ALL|LANG|LC_CTYPE|LC_NUMERIC)=/) {
          if (!loc) lcol = index($0, w)
          loc = 1
        }
        if (w ~ /[;&|]$/) loc = 0
        break
      }
      first = 0
      if (match(w, /[$<>]\(|`/)) {
        pos = RSTART
        tok = substr(w, pos, RLENGTH)
        frag = substr(w, 1, pos - 1)
        rest = substr(w, pos + RLENGTH)
      } else {
        tok = ""; frag = w; rest = ""
      }
      if (frag != "") {
        if (at_cmd && frag ~ /^[A-Za-z_][A-Za-z0-9_]*=/) {
          if (frag ~ /^(LC_ALL|LANG|LC_CTYPE|LC_NUMERIC)=/) {
            if (!loc) lcol = index($0, frag)
            loc = 1
          }
          if (frag ~ /[;&|)]$/) loc = 0
        } else {
          if (at_cmd) {
            c = frag
            sub(/[;&|)]+$/, "", c)
            if (loc && index(builtins, " " c " ")) {
              report(lcol, 2, "a temporary locale assignment before a builtin is ignored by bash 3.2: save, assign and restore, or, when only the command stdout is captured, use $(LC_ALL=C; cmd ...) (the subshell form can draw SC2030)")
              return
            }
            loc = 0
          }
          at_cmd = (frag ~ /[;&|(]$/ || index(keywords, " " frag " ") > 0)
        }
      }
      if (tok == "") break
      if (tok == "`") {
        bt = !bt
        at_cmd = bt
      } else {
        at_cmd = 1
      }
      loc = 0
      w = rest
    }
  }
}

# True when s holds as many closing parens as opening ones and an even number of
# backticks.
function balanced(s,   t, o, c, b) {
  t = s; o = gsub(/[(]/, "", t)
  t = s; c = gsub(/[)]/, "", t)
  t = s; b = gsub(/`/, "", t)
  return o == c && b % 2 == 0
}

# bash32-3: printf -v VAR FORMAT with a b conversion in FORMAT. A match counts
# as guarded only when the text before it on its line ends in a -z test then ||
# or a -n test then &&, in [ ] or [[ ]]: those skip the call when the argument
# is empty. Any other guard, a bare [ "$v" ] included, is flagged.
function scan_printf_var(   rest, off, pre, tail, cut) {
  rest = $0
  off = 0
  while (match(rest, /printf[ \t]+-v[ \t]+[^ \t]+[ \t]+/)) {
    pre = substr($0, 1, off + RSTART - 1)
    tail = substr(rest, RSTART + RLENGTH)
    cut = tail
    sub(/(&&|\|\|).*$/, "", cut)
    gsub(/%%/, "", cut)
    if (cut ~ /%[-+ #0-9.]*b/ && pre !~ /\[\[?[ \t]+-z[ \t].*\][ \t]*\|\|[ \t]*$/ && pre !~ /\[\[?[ \t]+-n[ \t].*\][ \t]*&&[ \t]*$/) {
      report(off + RSTART, 3, "printf into a variable with the b conversion keeps the previous value in bash 3.2 when the argument is empty: reset the variable and guard the call so it is skipped then, as in x=; [ -z \"$v\" ] || printf -v x %b \"$v\"")
      return
    }
    off += RSTART + RLENGTH - 1
    rest = tail
  }
}

BEGIN {
  file = ENVIRON["LINT_FILE"]
  keywords = " then do else elif if while until { ! "
  # bash 5 enable -a, a superset of the 3.2 builtins, minus command, eval and
  # exec; a command run through one of them is not checked.
  builtins = " . : [ alias bg bind break builtin caller cd compgen complete compopt continue declare dirs disown echo enable exit export false fc fg getopts hash help history jobs kill let local logout mapfile popd printf pushd pwd read readarray readonly return set shift shopt source suspend test times trap true type typeset ulimit umask unalias unset wait "
}
{
  scan_unbraced()
  scan_locale_prefix()
  scan_printf_var()
}
' <"$file" 2>/dev/null
  rc=$?
  if [ "$rc" -ne 0 ]; then
    printf '%s:1:1: warning: bash 3.2 checks could not run on this file (awk exit %s) [bash32-0]\n' "$file" "$rc"
  fi
done
exit 0
