# Size gate: the memory submodule is not checked

The earlier entry for the toolkit's `check-size` said it now counts `memory/`,
and D10 said the same. It does not. `memory/` is a submodule, so
`git ls-files` lists it as one gitlink and no file below it, and `check-size`
reads only regular files, so it skips the gitlink without a word. The check
passes even though `memory/MEMORY.md` is over 20000 bytes.

NFR6 now states the rule (only regular files are read, so a submodule such as
`memory/` is not checked), and D10's list of what the size check reads drops
`memory/`.
