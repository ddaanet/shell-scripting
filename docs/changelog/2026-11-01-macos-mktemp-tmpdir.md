# macOS mktemp with no explicit path ignores $TMPDIR

Landed from an inbox brief (a plugin-craft session, probed on macOS 26.6).
`references/portability.md` called `mktemp -d` portable. macOS `mktemp` with no
explicit path resolves `_CS_DARWIN_USER_TEMP_DIR` before `$TMPDIR` (man page,
DESCRIPTION), so under the Claude Code command sandbox, which grants `$TMPDIR`
and not `/var/folders`, it fails. The portable form is now the explicit
template only; `claude-code.md`'s `$TMPDIR` bullet points at it.

Not carried over from the brief: `-p "$TMPDIR"` as an alternative (GNU rejects
`-p` with an absolute template, BSD semantics unchecked) and the claim that BSD
randomises only a trailing run of Xs (unverified here).
