---
name: shell-gotchas
description: Catalogs shell pitfalls ShellCheck cannot detect — GNU vs BSD/macOS divergence, set -e blind spots, git hook environment leakage, bash 3.2 limits. This skill should be used when writing, editing, reviewing, or debugging shell scripts or snippets — .sh/.bash files, sh or bash shebang lines, git hooks, .bats tests, installers, wrapper/launcher scripts, Makefile recipes, or CI run steps — especially POSIX or portable code that must run on both macOS/BSD and Linux, handle arbitrary filenames, or run inside a git hook or Claude Code hook environment.
---

# Shell Scripting Gotchas

## Overview

Shell bugs cluster in places the eye skips over: a GNU-only flag that errors on macOS, a success message printed after a failed command, an inherited environment variable that silently redirects git. ShellCheck catches the mechanical class (quoting, word splitting, most bashisms). This skill covers what the linter cannot see — runtime divergence between platforms, environment leakage, and dishonest error paths — plus the discipline of auditing existing lines, not just new ones.

## Core Rules

Apply these in order on every shell task:

1. **Run shellcheck on everything written or edited.** Treat warnings as errors. If a shellcheck-on-edit hook is active (this plugin ships one), findings arrive automatically after each Write/Edit; fix them before moving on.

2. **Audit every line of a script being edited, not only the lines being added.** Latent bugs ride along through edit passes: a `paste -sd:` with no operand breaks every macOS user, yet survives an edit focused on a new feature. When any requirement mentions macOS, BSD, or "portable", check the *whole* script against `references/portability.md` before returning it — the diff is not the unit of review.

3. **Distrust success paths.** Never print a success message, or fall through to exit 0, unless the command it reports on actually succeeded. Exit status is silently lost inside `$(…)` assignments after `local`/`export`, behind process substitution, and in non-final pipeline stages. Make failure visible: check status explicitly, or structure so `set -e` can actually see it.

4. **Choose the dialect deliberately.** `#!/bin/sh` means POSIX — no `[[ ]]`, arrays, `<<<`, or `${var//…}` (Debian runs dash). `#!/usr/bin/env bash` on a Mac means **bash 3.2 from 2007** — no associative arrays, `${var,,}`, or `mapfile`. Decide which contract the script makes, then keep it.

5. **`printf '%s\n'` for data, never `echo`.** `echo` mangles backslashes and leading dashes depending on the shell. Reserve `echo` for fixed literal strings, if at all.

## What ShellCheck Cannot Catch

| Gotcha | Portable / correct form |
|---|---|
| `paste -sd:` — GNU reads stdin implicitly, BSD errors | `paste -sd: -` |
| `sed -i 'x' f` — BSD needs a suffix argument | `sed -i.bak 'x' f && rm f.bak` |
| `date -d`, `stat -c`, `readlink -f`, `grep -P`, `find -printf`, `xargs -r` | GNU-only; see `references/portability.md` |
| `local v=$(cmd)` — `cmd` failure masked by `local`'s status | declare first, assign on its own line |
| `grep` exits 1 on no-match — kills `set -e` scripts on a benign result | `grep … || true`, or test the result explicitly |
| success message after a fallible command | print only on confirmed success |
| `cmd \| while read` — loop runs in a subshell, variables vanish | redirect into the loop, or count inside it |
| last line without trailing newline dropped by `read` loops | `while IFS= read -r line \|\| [ -n "$line" ]` |
| git hook running `git -C elsewhere` — inherited `GIT_DIR` redirects it | `unset GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE` first |
| `git -C sub` with submodule not checked out — operates on the parent | guard with `[ -e sub/.git ]` |
| `cd` failing or echoing (CDPATH) | `cd dir \|\| exit 1`; `unset CDPATH` in scripts |
| `$((0$n))` octal surprise on zero-padded input | strip leading zeros before arithmetic |

Full catalogs with explanations:

- **`references/portability.md`** — GNU vs BSD/macOS divergence, bash 3.2 limits, the portable form for each command.
- **`references/robustness.md`** — quoting, `set -e` holes, exit-status loss, `read` discipline, filename safety.
- **`references/environments.md`** — git hook environment leakage, submodules and worktrees, Claude Code hook/sandbox specifics.

## Locking In a Portability Fix

A portability bug fixed without a test will come back. The pattern: simulate the foreign platform's strictness with a wrapper placed first in PATH, and assert the script still works. Example — a BSD-strict `paste` (errors when given no file operand, exactly like macOS):

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

## Checklist Before Returning Shell Code

- shellcheck clean (or every suppression justified inline with `# shellcheck disable=… reason`)
- every *touched* script audited whole against the portability table when cross-platform matters
- no unconditional success output; failures reach stderr and a non-zero exit
- dialect contract honored (`sh` is POSIX; Mac bash is 3.2)
- arbitrary data printed with `printf`, operands protected with `--` or `./`
- hooks: git environment unset before crossing repo boundaries; submodule presence guarded
