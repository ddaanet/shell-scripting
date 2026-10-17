## Brief: bash 3.2 behaviour traps and the macOS ctype quirk

2026-10-15

Proposed increments to `skills/shell-gotchas/references/portability.md`,
§"Shell version traps". Arrived from the sandbox-lies repo, from the first
run of its bats suite under the Mac's `/bin/bash` (3.2.57(1)-release): 12
failures out of 451 cases. Its suite already passed on the same Mac under
the default bash. All were fixed there, and each mechanism was confirmed
against a bash 3.2.57 built on Linux.

### Decisions

- The §"macOS /bin/bash is bash 3.2" entry lists only *features* 3.2 lacks.
  Every item below is a *behaviour* difference: the code parses and runs on
  3.2 and gives a wrong result, so no feature list catches it. Add them as a
  sibling entry ("bash 3.2 behaves differently, silently"), not as more rows
  in the feature list.
- The macOS ctype item is about the platform's libc, not about bash's
  version, and it bites under Homebrew bash too. It belongs in the
  command-by-command or environment part, with a pointer from the 3.2 entry.
- Each item states the safe form and was verified to work on both 3.2.57
  and 5.2.

### The items

1. **A temporary `LC_ALL=C` in front of a builtin is ignored.** In 3.2,
   `LC_ALL=C printf %q "$x"` (also `read`, `printf -v`) runs under the
   caller's locale. Source: `variables.c` `assign_in_env` never calls the
   locale hook (`stupidly_hack_special_variables`); bash 4 does. External
   commands (`LC_ALL=C sed …`) are unaffected. Safe forms: a plain
   assignment in a subshell, `$(LC_ALL=C; printf %q "$x")`, or
   save/assign/restore (`saved=${LC_ALL-} had=${LC_ALL+x}`; `LC_ALL=C`; …;
   restore, or `unset LC_ALL` if `had` is empty). Not `local LC_ALL=C`:
   3.2.0 does not undo it on return.
2. **`printf -v x '%b' ""` leaves `x` holding the previous `printf -v`
   buffer.** With `a` already set to `/tmp/scratch` by `printf -v a '%b' …`,
   `printf -v b '%b' ""` sets `b=/tmp/scratch`. `%s` with an empty argument
   is fine. Safe form: skip the call when the argument is empty (initialise
   the variable to empty first).
3. **A failed `source` exits the script under `set -e`, even when guarded.**
   `source missing || exit 2`, `if ! source missing; then …`, and
   `{ source missing; } || …` all exit with status 1 on 3.2; without
   `set -e`, `||` works. Safe form: `set +e; source f; rc=$?; set -e;
   [ "$rc" -eq 0 ] || exit 2`. It keeps bash's own diagnostic.
4. **macOS libc classifies bytes 0x80–0xFF as Latin-1 in a UTF-8 locale.**
   `isprint`/`isalnum` say yes to `0xC3`, `0xE2`, `0xFF`, which glibc never
   does. Two visible effects: `printf %q café` leaves `é` raw instead of
   `$'caf\303\251'`, and bash reads `"‘$p’"` as a variable named `p` plus
   the closing quote's first byte (`…: unbound variable` under `set -u`).
   Safe forms: brace any `$name` followed by a non-ASCII byte, `${p}’`, and
   run `%q` under `LC_ALL=C` with the item-1 form. Linux tests cannot
   reproduce either effect.
5. **macOS awk aborts on an invalid UTF-8 byte in its input**: `awk: towc:
   multibyte conversion failure on: …`. Running it as `LC_ALL=C awk` avoids
   that, since awk is external. **APFS refuses a non-UTF-8 file name**:
   `mkdir: …: Illegal byte sequence`.

### Constraints

- Sources for item 1 are the bash 3.2.57 tarball (`variables.c`,
  `execute_cmd.c` at `push_scope (VC_BLTNENV, temporary_env)`). Items 2–3
  are empirical against 3.2.57; item 4 is observed on macOS, not
  documented in a man page found so far.

### Additional context

- **Reproducing 3.2 on Linux (Debian 13, gcc 14):** the tarball's
  `y.tab.c` is stale against its patched `parse.y`, so delete `y.tab.[ch]`
  and regenerate it with byacc (needs only a C compiler; bison needs m4).
  Then `./configure --without-bash-malloc --disable-nls` and
  `make YACC="<byacc>/yacc -d" CC="gcc -std=gnu89 -fpermissive -w"
  CC_FOR_BUILD="gcc -std=gnu89 -fpermissive -w"`.
- **Running a bats suite under a chosen bash:** put a `bash` symlink first on
  `PATH`. bats, its libexec helpers and every `#!/usr/bin/env bash` script
  follow it. sandbox-lies ships this as `scripts/run-bats-under.sh`
  (`just test-system-bash`). A shell-script wrapper standing in for bash
  broke bats (`bats-format-cat: command not found`); a symlink works.
- The sandbox-lies memory `ddaanet/bash32-macos-traps` holds the same facts
  until this skill carries them; once it does, that memory can be retired.
