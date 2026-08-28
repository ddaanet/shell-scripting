# 2026-06-30 — Hook moved from `PostToolUse` to `PostToolBatch` (v0.3.0)

`PostToolUse` fires once per tool call, so a batch of parallel `Write`/`Edit` calls
to one file produced one shellcheck report per call — duplicated noise to the model,
plus transient findings from intermediate states.

The hook now binds `PostToolBatch`, which fires exactly once per turn after the whole
batch resolves and before the next model call, carrying every call in a `tool_calls`
array. The script filters that array to `Write`/`Edit`, dedupes the `file_path`s, and
shellchecks each shell file once on its final on-disk content; `-f gcc` output across
files self-identifies by path. Each file therefore yields at most one report per
batch, with no timing logic.

A `PostToolUse` debounce was briefly staged and abandoned before landing: each
invocation claimed a per-file `$TMPDIR` marker, slept a window, and reported only if
it was still the marker owner. It added per-edit latency, wrote per-file markers
against the minimal-footprint requirement, and was a heuristic — independent edits
inside the window got coalesced. It existed only because a stateless `PostToolUse`
hook cannot see whether a later edit to the same file is still coming; that signal
lives in the future. `PostToolBatch` removes the need to guess.

Two other alternatives fall away with it. Content-hash dedup does not help: an
A→B→C batch has three distinct hashes, so all three would still report. Scraping the
transcript does not either: the JSONL writes each `tool_use` at dispatch time,
interleaved with its result — `tool_A`, `result_A`, `tool_B` ordering was verified
for one shared `message.id` — so an early call's hook cannot see its later siblings.
The batch information exists only in Claude Code's memory between "response received"
and "next model call", and `PostToolBatch` is the surface that exposes exactly that
window.

The contract was verified by capturing a real payload: top-level keys `session_id`,
`transcript_path`, `cwd`, `permission_mode`, `prompt_id`, `effort`, `hook_event_name`,
`tool_calls`; each `tool_calls` entry carries `tool_name`, `tool_input` (with
`file_path` for Write/Edit), `tool_use_id`, `tool_response`. It fires for single-tool
turns too (an `n=1` batch), so it fully replaces `PostToolUse` rather than
supplementing it. It has no matcher support, so the script self-filters by
`tool_name`; a read-only batch yields no paths and exits silently.

The output channel (`additionalContext` → model, `systemMessage` → user) carries the
same way on `PostToolBatch` as it did on `PostToolUse`, but that is taken from
documentation and parity, not round-trip observation — recorded as a standing
limitation.

Re-linted clean (SC2015 caught and fixed in the file-collection loop). Exercised:
same-file 3× batch (1 report), multi-file batch (per-path findings), read-only and
non-shell batches (silent), singleton (reports).
