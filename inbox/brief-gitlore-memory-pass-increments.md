## Brief: four reference increments from a gitlore memory pass

2026-09-18

Arrived from the `gitlore` plugin repo. A memory-writing pass there declined to
save these as memories because `shell-gotchas` is the owner that states each at
the moment it matters. Each item names the reference section it extends and
states only the increment. This note ends gitlore's involvement; nothing is
tracked there.

### 1. `references/robustness.md`, "Off inside conditions, transitively"

Overlaps `brief-errexit-in-and-or-body.md` (2026-09-17, at this repo's root),
which establishes that errexit is live in a `{ … }` body in the final position
of an AND-OR list. Two increments on top of it:

- **The final element being a function changes nothing.** The bullet's
  "including every function called from there" holds for every element *but the
  last*: in `A || B`, errexit is suspended for everything `A` runs — a
  function's whole body included — and armed for `B`, brace group or function
  alike.
- **The ordering rule for a recovery arm.** `risky || { report; cleanup; }`
  reads as "the handler, where failures are tolerated" and is the opposite: a
  failing `report` (closed fd 2, full disk) skips `cleanup`. Put the step that
  must happen first, the fallible one last or behind its own `|| true`.

Re-measured 2026-09-18 on GNU bash 5.2.37:

```sh
bash -c 'set -e; false || { false; echo x; }'              # rc=1, prints nothing
bash -c 'set -e; f() { false; echo reached; }; f || true'  # prints "reached", rc=0
bash -c 'set -e; f() { false; echo x; }; false || f'       # rc=1, prints nothing
```

### 2. `references/environments.md`, "Claude Code specifics" — pointer from `references/bats.md`

**fd 0 under the Bash tool is neither the pipe a hook gets nor a terminal, and
`bats` inherits it.** What it *is* varies, which is the point:

- Linux, CC 2.1.276: a **socket** (`stat -L -c %F /dev/stdin` → `socket`);
  under `bats … </dev/null` a test sees a character device instead.
- Linux, CC 2.1.277, sandboxed Bash call, measured while writing this brief:
  `/proc/self/fd/0 -> /dev/null`, `character special file`.

The two measurements disagree, so treat the type as unspecified rather than
documenting "socket". What both share: a read returns EOF at once
(`cat | wc -c` gives 0). So `[ -t 0 ] || payload=$(cat)` takes its stdin branch
with an empty payload, and a test branching on fd 0's type
(`[ -p /dev/stdin ]`, `[ -c /dev/stdin ]`) sees neither the pipe a hook gets
nor reliably the `/dev/null` git gives `pre-commit`. The rule: a test gives its
subject the stdin production gives it, explicitly.

### 3. `references/portability.md`

`$$` is fixed at shell startup and identical in every `( … ) &` subshell, so a
`tmp.$$` name is shared by concurrent writers of one script. `$BASHPID` is
per-process and absent on bash 3.2, where it expands empty — so it is not the
portable fix. Use `mktemp`; distinguish test writers by an explicit id.

Note `environments.md`'s sandbox-probe example uses `.probe.$$`; that use is
single-writer and fine, but it is the spelling a reader copies.

### 4. `references/bats.md`, beside "`grep -qF \"$multiline\"` matches any ONE line"

- `grep -c` counts matching **lines**. `jq` emits `systemMessage` as one JSON
  string, so a doubled block inside it counts 1. Decode the field first:
  `jq -r .systemMessage | grep -c …`.
- `jq -r .key` prints the string `null` for an absent key, which a non-empty
  check accepts. Use `// empty`, or `jq -e 'has("key")'` in a test.

### Constraints

- The reference texts quoted above were checked against this repo's tree on
  2026-09-18; item 2's socket observation could not be reproduced and is
  reported as found.
- Wording and placement are this repo's call. A brief's recommendation is
  input, not a decision.
