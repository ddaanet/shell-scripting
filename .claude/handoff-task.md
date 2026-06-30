## Current task

The shell-gotchas lint hook was migrated from PostToolUse to PostToolBatch (reads the `tool_calls` array, dedupes Write/Edit `file_path`s, lints each shell file once on its final state); implementation, synthetic-payload tests, and DESIGN.md are done and being committed.

## Open decisions

- On next session restart — when the new `hooks.json` PostToolBatch binding actually loads — confirm shellcheck findings still reach the model via `hookSpecificOutput.additionalContext`. The input contract was captured empirically, but the model-facing output delivery on PostToolBatch specifically was not round-trip-observed (DESIGN limitation 8).
