# Shell version traps split out of portability.md

Landing the macOS mktemp correction pushed `references/portability.md` to 20187
bytes, over the 20000-byte cap the toolkit's size check enforces. The
`## Shell version traps` section moved verbatim into a new
`references/shell-versions.md`.

The seam is when-needed: the moved content matters when the question is which
shell runs the script (bash 3.2, macOS and Debian `/bin/sh`, zsh), while the
rest of `portability.md` is about GNU vs BSD command divergence. Only the two
cross-references between the files were reworded, to name the other file.

Citations moved with it: the `shell-gotchas` hub gets its own bullet for the new
file and drops bash 3.2 from the portability bullet, `robustness.md` points the
`pipefail` note at `shell-versions.md`, and `docs/design.md` (NFR1) and
`CLAUDE.md` list the new file.
