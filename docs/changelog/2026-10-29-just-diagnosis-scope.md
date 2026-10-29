# 2026-10-29 — Scoped the just diagnosis advice to the indentation trap

A medium review of the column-0 mechanism entry (see
[the entry](2026-10-29-just-column0-mechanism.md)) found three places where
`just-gotchas` sent the reader the wrong way. "Whatever the message, look for
a column-0 line" also covered the comment-interpolation trap, whose error
points at the comment itself; it is now scoped to indentation errors. `just
--dump` was offered for a recipe that fails to parse, but on a parse error it
prints only the error; the text now says it shows where the recipe ends when
nothing errors. And the header-shaped-line sentence read as if the truncated
recipe still ran after an error; it now says nothing runs on any error
(probed, just 1.46.0). An unwrapped line in the diagnosis section is reflowed.

Declined as low severity: a column-0 header named like a later real recipe,
whose redefinition error points at the real recipe; the exact recipe-level
error messages no longer appearing in the skill; and this entry's
predecessor's 81-column title line.
