# 2026-10-30 — The hook's own `cd`: remaining outcome claims dropped

The medium review of the [hook-cd-claims-dropped](2026-10-30-hook-cd-claims-dropped.md)
change found two outcome claims about the hook's own `cd` still in
`environments.md`, and its probes contradicted both. One was the second
caveat's sentence on what `git add` does after `cd sub` under an inherited
`GIT_DIR`. The other was the Consequence paragraph's application of the
relative/absolute split to the hook's own `cd`.

Both are removed rather than corrected. The caveat now gives only the reason
for the anchor, worded as what can happen, and the Consequence paragraph no
longer mentions the hook's own `cd`.
