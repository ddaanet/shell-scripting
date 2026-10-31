# Claude Code specifics split out of environments.md

`references/environments.md` had grown to 21494 bytes, over the 20000-byte cap
the toolkit's size check enforces. The `## Claude Code specifics` section moved
verbatim into a new `references/claude-code.md`.

The seam is when-needed: the moved content matters only when a script runs under
Claude Code (hooks, the Bash tool, the command sandbox), while the rest of
`environments.md` is about git hooks, submodules and worktrees. No text was
reworded.

Citations moved with it: the `shell-gotchas` hub gets its own bullet for the new
file, `bats-gotchas` links the test-stdin fact there, and `docs/design.md`
(NFR1, D6, D9) and `CLAUDE.md` name `claude-code.md`.
