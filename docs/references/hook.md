# Hook design node

This node holds the argument for the `PostToolBatch` hook's decisions (D3, D4,
D5, D8, D11) and for limitations L8 and L11. `docs/design.md` concludes each
one; the FR and NFR ids cited here resolve there. Read this node before making a
claim about, or changing, the hook.

## Design Decisions

**D3 — Findings split across channels: full output to the model via
`additionalContext`, a one-line summary to the user via `systemMessage`**

Lint findings are fed to the model through the hook's
`hookSpecificOutput.additionalContext` (wrapped in a system reminder next to the
tool result, model-visible only), while the user sees only
`systemMessage: "shell lint: N findings"`; `suppressOutput` keeps the raw JSON
out of the transcript. The earlier design emitted findings via exit 2 + stderr,
but stderr is shown to *both* the model and the user's transcript — splitting
the channels keeps the verbose output where it is actionable (the model) and
spares the user a wall of text. Because the findings no longer reach the
transcript, the former 60-line cap is dropped and the model receives the
complete output. The missing-shellcheck notice keeps using `systemMessage` (with
a zero exit status), in the same message as the summary when both apply — the
user, not the model, is who can act on a missing system dependency.
(`additionalContext` and `systemMessage` carry the same way on `PostToolBatch`
as on the original `PostToolUse` event — assumed, not round-trip-observed: see
L8.)

**D4 — Interpreter allowlist for shebang sniffing**

Only sh/bash/dash/ksh/bats shebangs are linted. A generic `*sh*` match was
rejected: it would route fish or zsh files to shellcheck, which cannot parse
them and would produce noise findings.

**D5 — One-time notice keyed by session marker in `$TMPDIR`**

Visible degradation (FR7) without nagging: a marker file named with the hook
payload's `session_id` suppresses repeats within a session. A missing jq stays
silent by construction — without jq the hook cannot parse the payload, so it
cannot even tell whether the edit touched a shell file.

**D8 — Per-batch coalescing via the `PostToolBatch` event, not a debounce**

`PostToolUse` fires once per tool call, so a batch of parallel `Write`/`Edit`
calls to one file produced one shellcheck report per call — duplicated noise to
the model, plus transient findings from intermediate states. `PostToolBatch`
fires exactly once per turn,
*after the whole batch resolves and before the next model call*, carrying every
call in a `tool_calls` array; the hook filters that array to `Write`/`Edit`,
dedupes the `file_path`s, and lints each file once on its final on-disk content.
So each file yields at most one report per batch (FR8), with no timing logic.

This supersedes an earlier debounce design (each `PostToolUse` invocation
claimed a per-file `$TMPDIR` marker, slept a window, and reported only if still
the marker owner). The debounce was rejected once `PostToolBatch` was confirmed:
it added per-edit latency, wrote per-file markers (against NFR4), and was a
heuristic (independent edits inside the window got coalesced). It existed only
because a stateless `PostToolUse` hook cannot see whether a later edit to the
same file is still coming — the "is more coming?" signal lives in the future.
`PostToolBatch` removes the need to guess: the platform hands the hook the
complete batch.

Two earlier rejected alternatives also fall away: content-hash dedup (an A→B→C
batch has three distinct hashes, so all three would still report) and scraping
the transcript (the JSONL writes each `tool_use` at dispatch time, interleaved
with its result — verified `tool_A`, `result_A`, `tool_B` ordering for one
shared `message.id` — so an early call's hook cannot see its later siblings).
The batch info exists only in CC's memory between "response received" and "next
model call," and `PostToolBatch` is the surface that exposes exactly that
window.

The contract was verified empirically (captured payload, 2026-06-30): top-level
keys
`session_id`/`transcript_path`/`cwd`/`permission_mode`/`prompt_id`/`effort`/`hook_event_name`/`tool_calls`;
each `tool_calls` entry has `tool_name`, `tool_input` (with `file_path` for
Write/Edit), `tool_use_id`, `tool_response`. `PostToolBatch` fires for
single-tool turns too (an `n=1` batch), so it fully replaces `PostToolUse`
rather than supplementing it. It has no matcher support, so the script
self-filters by `tool_name`; a read-only batch yields no Write/Edit paths and
exits silently.

**D11 — The bash 3.2 lint is a sibling script the hook calls, with three
line-level patterns and no suppression comment**

macOS `/bin/bash` 3.2 runs some constructs without an error and with a wrong
result (`references/shell-versions.md`, `references/portability.md`); shellcheck
cannot flag them, and no Linux test reproduces them. The hook flags three, each
with a rewrite that preserves meaning:

- an unbraced `$name` immediately followed by a byte >= 0x80 (fix: `${name}`);
- `LC_ALL`, `LANG` or `LC_CTYPE` assigned as a command prefix, among other
  prefix assignments or not, in front of a bash builtin (fix:
  `$(LC_ALL=C; cmd ...)`, which can draw SC2030, or save, assign and restore).
  The prefix before an external command, a standalone assignment and `export`
  are fine. The builtin set is bash 5's `enable -a`, frozen in the script: a
  superset of 3.2's whose extras are harmless, minus `command`, `eval` and
  `exec`; a command run through one of them is not checked. The list is of
  builtins, not of the locale-sensitive ones, which is the list that would rot;
- `printf -v` with a format holding the `b` conversion, unless the same line
  guards it with a `-z` test then `||` or a `-n` test then `&&`, in `[ ]` or
  `[[ ]]` (`[ -z "$v" ] || printf -v x '%b' "$v"`). Every other form is flagged,
  the inverted guards included; a bare `[ "$v" ] &&` is a tolerated false
  positive, since rewriting it with `-n` is harmless. `%s` formats are fine.

The lint is `hooks/scripts/bash32-lint.sh`, which the hook finds beside itself
with `$(dirname "$0")` and runs on the same file list as shellcheck. A separate
script lets the bats suite call it directly. It prints findings in shellcheck's
gcc shape with a `[bash32-N]` tag and always exits 0. It never decides whether a
file is shell; the hook already has. When awk fails on a file, the lint prints
`file:1:1: warning: bash 3.2 checks could not run on this file (awk exit N) [bash32-0]`,
so a broken pass reaches the model as a finding instead of reading as a clean
file.

No suppression comment exists: every pattern has an accepted rewrite, so a
finding is fixed rather than silenced. Matching is per line under `LC_ALL=C`,
with the high-byte test an explicit octal range, never a ctype class: macOS libc
classifies 0x80-0xFF as printable in a UTF-8 locale and glibc does not, so a
class would differ on the Mac where no Linux test sees it. The patterns are
written so the script and its tests do not match their own text.

The bash 3.2 pass runs with or without shellcheck. A missing shellcheck keeps
its one-time notice (D5) but no longer ends the run: the notice and the summary
share one `systemMessage`, and the findings go in `additionalContext`, all in
one JSON object.

## Limitations

The labels are the items' numbers in `docs/design.md`, where each concludes in a
line.

**L8.** `PostToolBatch`'s output channel (`additionalContext` → model,
`systemMessage` → user) is taken from documentation and parity with the prior
`PostToolUse` path; the input contract was captured empirically, but the
model-facing delivery of `additionalContext` on `PostToolBatch` specifically was
not round-trip-observed.

**L11.** The bash 3.2 lint matches lines, not syntax: quotes, comments and
heredoc bodies are not parsed, so a matching line inside one is flagged. A
prefix assignment whose value spans words, through quoting or a substitution
(`FOO="a b" LC_ALL=C cmd`, `FOO=$(date +%s) LC_ALL=C cmd`), ends the prefix run,
so a finding that depends on that run is missed. Behaviour on 3.2 itself is not
observable in the suite; the tests pin the patterns only.
