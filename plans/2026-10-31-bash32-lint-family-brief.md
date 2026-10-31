## Brief: a lint for three silent bash 3.2 / macOS traps

2026-10-31, from sandbox-lies. A request, not a decision: where the lint lives
and how it is built are this repo's call.

### Decisions

- My human partner moved this item from the sandbox-lies TODO to shell-gotchas:
  the patterns are general shell traps, not sandbox-lies ones.
- The ask is mechanical detection. The prose already exists in
  `skills/shell-gotchas/references/portability.md` ("macOS libc and non-ASCII
  bytes"; "bash 3.2 also misbehaves silently"). These traps parse, run, and give
  a wrong result on macOS `/bin/bash` 3.2.57, and shellcheck flags none of them,
  so a catalog entry only helps a reader who already suspects them.

### The three patterns

1. **`$name` directly followed by a non-ASCII byte**, e.g. `"$p’"`. bash on
   macOS reads the byte as part of the name, so `$p` expands empty (or to
   another variable). The fix is `${p}’`. Detect: an unbraced `$[A-Za-z_]\w*`
   immediately followed by a byte ≥ 0x80, inside double quotes or bare.
2. **A temporary `LC_ALL=…` (or `LANG`/`LC_CTYPE`) in front of a builtin**,
   e.g. `LC_ALL=C printf %q "$x"`, `LC_ALL=C read …`, `LC_ALL=C printf -v …`.
   bash 3.2 does not run the locale hook for a temporary assignment before a
   builtin, so the command runs under the caller's locale. Before an external
   command (`LC_ALL=C sed`) it is fine. The fixes are `$(LC_ALL=C; printf …)` or
   save/assign/restore, never `local LC_ALL=C`. Observed with `printf` and
   `read`. Which other builtins are locale-sensitive is unverified, so match
   any builtin (from `enable -a`) rather than freezing a list.
3. **`printf -v x '%b'` with an argument that can be empty.** Under 3.2 an empty
   argument leaves `x` holding the previous `printf -v` result. `%s` is
   unaffected. A lint cannot know whether the argument is empty, so it flags
   every `printf -v … '%b'` and accepts a guarded form (`[ -z "$v" ] ||
   printf -v x '%b' "$v"` after `x=`). Whether that false-positive rate is
   acceptable is open.

### Constraints

- Must not fire on the documentation that describes these patterns: the
  references quote every one of them. Scope the lint to shell files (the
  `shellcheck-on-edit.sh` hook already picks them) or exempt `references/`.
- Bash 3.2 behaviour cannot be observed on Linux without a 3.2.57 build. Any
  test of the lint is a pattern test, not a behaviour test.

### Rejected approaches

- Keeping this as a sandbox-lies-local check: every ddaanet repo with shell
  code that targets macOS has the same exposure.

### Additional context

Real sites, fixed in sandbox-lies (`/Users/david/code/sandbox-lies`) and
useful as positive cases:

- Pattern 2: `lib/probes-readonly.sh` `_probe_path_line` (now save/assign/
  restore), and `$(LC_ALL=C; printf …)` sites in `tests/helpers/probes.bash`,
  `tests/probes-lock-newline.bats`, `tests/hook-writes.bats`,
  `tests/probes-readonly-members.bats`, `tests/probes-readonly-resolve.bats`,
  `tests/verdicts-readonly-path.bats`. Run `git log -S'LC_ALL=C printf'` there
  to find the pre-fix forms.
- Pattern 3: `hooks/annotate.sh`, the cwd and command unescape (`v` held,
  `[ -z "$v" ] || printf -v … '%b' "$v"`).
- The fixed form `$(LC_ALL=C; printf …)` draws shellcheck SC2030 (info) when a
  later line reads a variable assigned in that subshell. sandbox-lies disabled
  it per site. A lint that suggests the fix should mention this.
- The bash 3.2.57 build recipe is in the ddaanet memory fact
  `bash32-macos-traps`.
